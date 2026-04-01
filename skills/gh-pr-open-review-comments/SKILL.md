---
name: gh-pr-open-review-comments
description: Lists unresolved GitHub pull request inline review threads in a Markdown table, classifying CodeRabbit, Bugbot (Cursor), or human authors. Use when analyzing PR reviews, summarizing open bot or reviewer feedback, or triaging comments before merge. Requires gh and jq; uses GraphQL through gh api only. Skill and script live under skills/gh-pr-open-review-comments in the repository (portable path, no home-directory coupling).
---

# Commentaires de review PR (GitHub) — fils non résolus

## Objectif

Aider l’agent à **lister uniquement les commentaires de review inline encore ouverts** (fils non marqués comme résolus sur GitHub), avec une **source** lisible : CodeRabbit, Bugbot ou humain.

## Emplacement (portable)

Racine du skill : **`skills/gh-pr-open-review-comments/`** (dans ce dépôt ou tout clone du bundle de skills). Aucun chemin vers `~/.cursor` : le même dossier peut être copié sur d’autres machines.

## Pourquoi GraphQL (via `gh`)

- L’API REST `GET /repos/{owner}/{repo}/pulls/{pull_number}/comments` **ne fournit pas** l’état « résolu » d’un fil.
- Le champ **`isResolved`** existe sur les **review threads** en **GraphQL** (`pullRequest.reviewThreads`).
- `gh api graphql` fait partie du **GitHub CLI** : respect de la contrainte « GH CLI uniquement » (pas de token manuel, pas d’autre client HTTP).

## Exécutable prévisible

**Depuis la racine du dépôt** (où se trouve le dossier `skills/`) :

```bash
bash skills/gh-pr-open-review-comments/scripts/list-open-review-threads.sh OWNER REPO PR_NUMBER
```

Ou avec l’URL de la PR :

```bash
bash skills/gh-pr-open-review-comments/scripts/list-open-review-threads.sh 'https://github.com/OWNER/REPO/pull/123'
```

**Depuis le dossier du skill** (`skills/gh-pr-open-review-comments/`) :

```bash
bash scripts/list-open-review-threads.sh OWNER REPO PR_NUMBER
```

**Chemin canonique** (à utiliser quand le workspace est la racine du dépôt qui contient `skills/`) :

`skills/gh-pr-open-review-comments/scripts/list-open-review-threads.sh`

**Prérequis :** `gh` authentifié (`gh auth login`), **`jq`** installé.

**Sortie :** tableau Markdown (Source, Auteur, fichier, ligne, résumé une ligne, lien direct `#discussion_r…`).

## Règles de classification (colonne Source)

| Source     | Règle (login GraphQL de l’auteur du premier commentaire du fil) |
|-----------|------------------------------------------------------------------|
| CodeRabbit | login contient `coderabbit` (ex. `coderabbitai`)                  |
| Bugbot     | login contient `bugbot`, ou login `cursor` **et** `__typename == "Bot"` |
| Humain     | tout le reste                                                    |

Si un compte humain utilisait le login `cursor`, il serait classé Humain (pas Bot). Pour d’autres apps, ajuster le script `classify` dans `scripts/list-open-review-threads.sh`.

## Workflow agent

1. Quand l’utilisateur donne une PR, **exécuter le script** via un chemin **relatif au workspace** : `skills/gh-pr-open-review-comments/scripts/list-open-review-threads.sh` (préfixer par la racine du repo si besoin).
2. **Ne pas** se fier seulement à `gh pr view` / commentaires généraux : les outils « conversation » ne remplacent pas les **fils inline** avec `isResolved`.
3. **Ignorer** les fils résolus : déjà filtrés par le script (`isResolved == false`).
4. Utiliser les **liens** de la dernière colonne pour ouvrir la discussion exacte sur GitHub.

## Écart possible avec l’UI GitHub

Le nombre de lignes du tableau peut différer du « nombre de commentaires » affiché dans l’interface (filtres, regroupements, commentaires hors fil inline, cache). La source de vérité ici est **`reviewThreads` non résolus**.

## Exemple

PR publique d’exemple : `https://github.com/Foldio/foldio-app/pull/722` — le script doit lister **uniquement** les fils encore ouverts ; le décompte peut varier selon l’état au moment de l’appel.
