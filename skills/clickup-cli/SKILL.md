---
name: clickup-cli
description: >-
  ClickUp via clickup-cli (CLI prioritaire, MCP en repli). Détection du CLI,
  commandes token-efficient, conventions projet optionnelles (AGENTS.md,
  .clickup.toml), et mapping CLI ↔ MCP. Utiliser pour toute interaction
  ClickUp quand le CLI est installé, ou comme fallback quand le MCP officiel
  est utilisé.
---

# ClickUp CLI (prioritaire) + MCP (repli)

Le CLI `clickup-cli` (alias `clkup`) est **optionnel** : certains environnements n'ont que le MCP officiel. Toujours tenter le CLI en premier ; basculer sur le MCP seulement si le CLI est absent, non configuré, ou si une commande échoue de façon irrécupérable.

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

## Conventions projet (optionnel)

Avant de résoudre une liste, un assigné ou un ID depuis git, lire les conventions du repo si elles existent :

1. `.clickup.toml` à la racine (IDs workspace/list par défaut — sans token)
2. `AGENTS.md` / `CONTRIBUTING.md`
3. `.cursor/rules/` ou skill projet `.cursor/skills/clickup-cli/`

Si rien n'existe : s'appuyer sur les entrées utilisateur et la hiérarchie CLI/MCP. **Ne pas** supposer de structure d'espace, de dossier ou de format de branche.

## Task ID depuis git

`clickup-cli` peut inférer l'ID tâche depuis la branche git courante (si le repo documente ou configure un format reconnu par le CLI).

Sur une branche git, les commandes task-scoped sans ID explicite résolvent l'ID automatiquement :

```bash
clickup-cli task get
clickup-cli comment list
```

Désactiver ponctuellement : `CLICKUP_GIT_DETECT=0 clickup-cli task get <id>`.

Si le projet ne documente pas de convention de branche → ne pas inventer de regex ; demander l'ID à l'utilisateur.

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

Si le projet documente un space ou folder par défaut (`.clickup.toml`, `AGENTS.md`), l'utiliser **avant** de parcourir toute la hiérarchie.

```bash
clickup-cli space list --output json-compact
# → choisir le space (nom ou id documenté dans le projet)

clickup-cli folder list --space <space_id> --output json-compact
# → choisir le folder parent

clickup-cli list list --folder <folder_id> --output json-compact
# → choisir la liste dont le name contient le fragment utilisateur (ex. "backlog", "sprint 42")
```

Filtrer sur un **fragment fourni par l'utilisateur** (nom partiel de liste, sprint, backlog, etc.).

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

### Listes à ACL restreinte

Sur une liste à accès limité (ex. espace privé), `member list --list` peut retourner un **sous-ensemble** des membres du workspace. Si la personne cherchée est absente : essayer une autre liste du même space où l'équipe a accès, ou demander l'email/ID à l'utilisateur.

### Ce qui ne fonctionne pas en CLI

- `member list` sans `--list` / `--task`
- `user get <id>` indisponible sur certains plans ClickUp (403)
- `group list` comme source d'assignés (groupes incomplets)

**Ne jamais** passer un nom dans `--assignee` — toujours un ID numérique.

## Pattern repli

Pour chaque étape d'un workflow ClickUp :

1. Tenter la commande CLI
2. Si exit code ≠ 0 ou résultat vide/inutilisable → même action via MCP
3. Si les deux échouent → informer l'utilisateur avec l'erreur concrète

Ne pas annoncer le mode utilisé sauf si utile au debug (ex. « via MCP, CLI non installé »).
