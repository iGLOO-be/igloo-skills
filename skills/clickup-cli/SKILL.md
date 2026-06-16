---
name: clickup-cli
description: >-
  ClickUp via clickup-cli (CLI prioritaire, MCP en repli). Détection du CLI,
  commandes token-efficient, conventions Foldio, et mapping CLI ↔ MCP.
  Utiliser pour toute interaction ClickUp quand le CLI est installé, ou comme
  fallback quand le MCP officiel est utilisé.
---

# ClickUp CLI (prioritaire) + MCP (repli)

Le CLI `clickup-cli` (alias `clkup`) est **optionnel** : certains collègues n'utilisent que le MCP officiel. Toujours tenter le CLI en premier ; basculer sur le MCP seulement si le CLI est absent, non configuré, ou si une commande échoue de façon irrécupérable.

## Détection (à faire une fois par workflow)

```bash
# 1. Binaire présent ?
which clickup-cli || which clkup

# 2. Auth OK ? (exit 0 = prêt, exit 2 = token/workspace manquant)
clickup-cli auth check
```

| Résultat | Mode |
|---|---|
| CLI installé + `auth check` OK | **CLI** |
| CLI absent ou `auth check` échoue, MCP accessible | **MCP** |
| Ni CLI utilisable ni MCP | **STOP** — voir message ci-dessous |

Message si les deux sont indisponibles :

> ClickUp inaccessible. Soit installer et configurer le CLI (`brew install clickup-cli` puis `clickup-cli setup --token pk_xxx`), soit activer le MCP `clickup` dans les paramètres Cursor.

## Setup (optionnel, par développeur)

```bash
brew tap nicholasbester/clickup-cli
brew install clickup-cli
clickup-cli setup --token pk_xxx          # interactif
# ou non-interactif :
clickup-cli setup --token pk_xxx --workspace <workspace_id>
```

Config : `~/.config/clickup-cli/config.toml` (global, recommandé) ou `.clickup.toml` (projet — **ne pas committer de token**).

Variables d'env : `CLICKUP_TOKEN`, `CLICKUP_WORKSPACE`.

Référence complète des commandes (générée par la version installée) :

```bash
clickup-cli agent-config show
```

## Conventions de sortie (agents)

- **Défaut** : table compacte (~98 % moins de tokens que le JSON API brut)
- **Parsing** : `--output json-compact` quand il faut extraire des champs
- **IDs seuls** : `-q`
- **Description multiligne** : heredoc shell

```bash
clickup-cli task create --list ID --name "Titre" --description "$(cat <<'EOF'
## Contexte
...
EOF
)"
```

## Branches Foldio → task ID

Branches : `v<Version>/<Type>/CU-<ClickUp-ID>/<description>` (ex. `v4.36/fix/CU-86c7hyk9t/fix-Something`).

Sur une branche git, les commandes task-scoped sans ID explicite résolvent l'ID automatiquement :

```bash
clickup-cli task get
clickup-cli comment list
```

Désactiver ponctuellement : `CLICKUP_GIT_DETECT=0 clickup-cli task get <id>`.

## Mapping CLI ↔ MCP

| Action | CLI (prioritaire) | MCP (repli) |
|---|---|---|
| Lire une tâche | `task get [ID]` | `clickup_get_task` |
| Créer une tâche | `task create --list ID --name N ...` | `clickup_create_task` |
| Mettre à jour | `task update [ID] --status S --add-assignee ID` | `clickup_update_task` |
| Dépendance (A attend B) | `task add-dep A --depends-on B` | `clickup_add_task_dependency` |
| Membres assignables (CLI) | `member list --list <list_id>` après résolution liste | `clickup_get_workspace_members` / `clickup_find_member_by_name` |
| Utilisateur courant | `auth whoami --output json-compact` | assignee `["me"]` dans create/update |
| Liste par nom partiel | hiérarchie space → folder → list (voir ci-dessous) | `clickup_get_list` |
| Hiérarchie complète | `space list` → `folder list` → `list list` | `clickup_get_workspace_hierarchy` |

### Priorités

| MCP (texte) | CLI (`--priority`) |
|---|---|
| urgent | 1 |
| high | 2 |
| normal | 3 |
| low | 4 |

## Résolution de liste (CLI)

Le MCP offre un matching flou via `clickup_get_list`. En CLI, parcourir la hiérarchie et filtrer côté agent.

**Listes sprint** (convention `v4.XX - N (MM/DD - MM/DD)`) :

```bash
clickup-cli space list --output json-compact
# → id de "Foldio Development"

clickup-cli folder list --space <space_id> --output json-compact
# → id du dossier "Sprints"

clickup-cli list list --folder <folder_id> --output json-compact
# → choisir la liste dont le name contient le fragment utilisateur (ex. "v4.42")
```

**Autres listes** (ex. `Pending reviews`) : même principe — identifier le dossier parent, puis `list list --folder <id>` et filtrer par nom.

Si la résolution CLI échoue → repli `clickup_get_list` (MCP).

## Résolution d'assigné (CLI)

Le CLI **n'expose pas** de commande « tous les membres du workspace ». `member list` sans argument échoue ; il faut `--list` ou `--task`.

### Sémantique API (v0.13.0)

| Commande | Endpoint | Périmètre |
|---|---|---|
| `member list --list <id>` | `GET /v2/list/{id}/member` | Membres avec accès **explicite** à cette liste |
| `member list --task <id>` | `GET /v2/task/{id}/member` | Membres avec accès **direct** à cette tâche (sous-ensemble) |

**Ne jamais** utiliser `--task` pour résoudre un assigné lors d'une **création** de tâche.

### Workflow CLI

1. **Résoudre la liste cible d'abord** (obligatoire avant `member list --list`)
2. **Mode `self`** : `auth whoami --output json-compact` → `--assignee <id>` (peut être en parallèle avec la résolution liste)
3. **Mode `other`** : après `list_id` connu :

```bash
clickup-cli member list --list <list_id> --output json-compact
```

Matcher nom/email côté agent (préférer l'email si fourni). En cas d'ambiguïté : liste courte (nom + email + id) et demander confirmation.

### Foldio (constat empirique)

Sur les listes **Foldio Development** et **Corporate** testées (Sprints, Pending reviews, Features request, CSM), `member list --list` retourne les **8 membres** de l'équipe dev — identique au périmètre workspace pour l'usage courant.

Sur une liste à ACL restreinte (ex. espace privé), le résultat peut être un **sous-ensemble** (ex. 1 seul membre). Si la personne cherchée est absente : essayer une autre liste du même space où l'équipe a accès, ou demander l'email/ID à l'utilisateur.

### Ce qui ne fonctionne pas en CLI

- `member list` sans `--list` / `--task`
- `user get <id>` sur notre plan (403 Enterprise)
- `group list` comme source d'assignés (groupes incomplets)

**Ne jamais** passer un nom dans `--assignee` — toujours un ID numérique.

## Pattern repli

Pour chaque étape d'un workflow ClickUp :

1. Tenter la commande CLI
2. Si exit code ≠ 0 ou résultat vide/inutilisable → même action via MCP
3. Si les deux échouent → informer l'utilisateur avec l'erreur concrète

Ne pas annoncer le mode utilisé sauf si utile au debug (ex. « via MCP, CLI non installé »).
