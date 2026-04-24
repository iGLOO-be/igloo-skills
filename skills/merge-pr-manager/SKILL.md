---
name: merge-pr-manager
description: >
  Triage open GitHub PRs for a Paperclip merge agent: detect agent PRs
  (Co-Authored-By, branch prefix, label), extract the Paperclip issue ref,
  compute CI / review / conflict / approval status, and recommend an action
  (merge, handoff_coder, wait_ci, wait_approval, skip). Use when triaging PRs,
  checking merge readiness, or running a merge-agent heartbeat. Requires gh
  and jq. Skill lives under skills/merge-pr-manager in the repository.
---

# Merge PR Manager

## Objectif

Fournir un **CLI deterministe** que l'agent merge execute a chaque heartbeat pour obtenir une vue complete de toutes les PR ouvertes : detection agent, lien Paperclip, CI, conflits, reviews, label d'approbation, et action recommandee.

## Emplacement

Racine du skill : **`skills/merge-pr-manager/`** (portable, pas de couplage `~/.cursor`).

## Prerequis

- `gh` authentifie (`gh auth login`)
- `jq` installe

## CLI — `list-pr-status.sh`

### Usage

```bash
# Depuis la racine du depot
bash skills/merge-pr-manager/scripts/list-pr-status.sh OWNER REPO
bash skills/merge-pr-manager/scripts/list-pr-status.sh https://github.com/OWNER/REPO

# Options
#   --prefix PREFIX   Prefixe Paperclip (defaut: FOL)
#   --agent-only      Filtrer uniquement les PR agent
#   --json            Sortie JSON brute (defaut: Markdown)
```

### Exemples concrets

```bash
# Tableau Markdown de toutes les PR ouvertes
bash skills/merge-pr-manager/scripts/list-pr-status.sh Foldio foldio-app

# JSON des PR agent uniquement, prefixe PAP
bash skills/merge-pr-manager/scripts/list-pr-status.sh --prefix PAP --agent-only --json Foldio foldio-app

# Depuis une URL
bash skills/merge-pr-manager/scripts/list-pr-status.sh --agent-only https://github.com/Foldio/foldio-app
```

### Champs calcules

| Champ | Description |
|-------|-------------|
| `is_agent_pr` | `true` si au moins un signal agent detecte |
| `agent_signals` | Criteres satisfaits : `co-authored-by`, `branch-prefix`, `label` |
| `paperclip_ref` | Identifiant Paperclip (`FOL-42`) extrait de branche > titre > body |
| `mergeable` | `MERGEABLE`, `CONFLICTING`, ou `UNKNOWN` |
| `ci_status` | `pass`, `fail`, `pending`, ou `none` (Vercel exclu automatiquement) |
| `ci_failures` | Noms des checks en echec (hors Vercel) |
| `review_decision` | `APPROVED`, `CHANGES_REQUESTED`, `REVIEW_REQUIRED`, ou `null` |
| `unresolved_threads` | Nombre total de review threads non resolus |
| `unresolved_bot_threads` | Nombre de threads non resolus par des bots (CodeRabbit, Bugbot) |
| `unresolved_thread_details` | Details des threads bot : source, fichier, ligne |
| `has_approve_label` | `true` si le label `paperclip:approve` est present |
| `action` | Action recommandee (voir ci-dessous) |
| `action_reason` | Explication textuelle de l'action |

### Detection agent (3 criteres, OR)

1. **Co-Authored-By** : un des 5 derniers commits contient `Co-Authored-By: ... Paperclip`
2. **Prefixe de branche** : `paperclip/...` ou `agent/...`
3. **Label GitHub** : `paperclip:agent`

### Extraction de la ref Paperclip

Regex `{PREFIX}-\d+` appliquee avec priorite : nom de branche > titre PR > body PR.
Le prefixe est configurable via `--prefix` (defaut `FOL`).

### Actions recommandees

| Action | Signification | Quand |
|--------|--------------|-------|
| `merge` | PR prete a merger | Agent PR + CI pass + pas de changes requested + 0 bot threads + label `paperclip:approve` |
| `handoff_coder` | Deleguer au Coder | Conflit git, CI rouge, changes requested, ou threads bot non resolus |
| `wait_ci` | Attendre | CI encore en cours |
| `wait_approval` | Attendre label humain | Tout est OK mais pas de `paperclip:approve` |
| `skip` | Ignorer | Pas une PR agent |

## Workflow agent (heartbeat)

1. **Executer le CLI** :
   ```bash
   bash skills/merge-pr-manager/scripts/list-pr-status.sh --prefix FOL --agent-only --json OWNER REPO
   ```

2. **Iterer sur le JSON** et traiter chaque PR selon `action` :

   - **`merge`** : executer `gh pr merge NUMBER --squash --delete-branch`
   - **`handoff_coder`** : retrouver l'issue Paperclip via `paperclip_ref`, poster un commentaire avec `action_reason`, reassigner au Coder
   - **`wait_ci`** : ne rien faire, reessayer au prochain heartbeat
   - **`wait_approval`** : si l'issue Paperclip est en `in_review`, laisser en l'etat ; sinon poster un commentaire mentionnant que le label est attendu

3. **Retrouver l'issue Paperclip** a partir de `paperclip_ref` :
   ```bash
   curl -sS "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/issues?q=FOL-42" \
     -H "Authorization: Bearer $PAPERCLIP_API_KEY"
   ```

## Reference

Pour l'instruction complete de l'agent merge, voir [references/agent-instructions.md](references/agent-instructions.md).
