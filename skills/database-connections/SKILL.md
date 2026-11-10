---
name: database-connections
description: >-
  Pointe vers le repo database-connections pour interroger des bases via
  connections.yaml (.env local). Use when the user explicitly says
  "database-connections", "utilise database-connections", "projet
  database-connections", or attaches this skill to query foldio, gitlab,
  igloo-cluster, etc.
disable-model-invocation: true
---

# Database Connections (référence projet)

Racine du skill : **`skills/database-connections/`** (ce dépôt). Symlink Cursor : **`.cursor/skills/database-connections`**.

Repo outillage : `~/Projects/database-connections` (clone local attendu)

- Catalogue : `connections.yaml`
- Secrets : `.env` (jamais commité ; copier depuis `.env.example` si absent)

## Procédure

1. **Lire** `~/Projects/database-connections/.cursor/skills/db-connections/SKILL.md` — règles `critical`, `readonly`, confirmation mutante, perf agents, etc.
2. **Résoudre** l'id de connexion (`grep 'id:' ~/Projects/database-connections/connections.yaml` ou demander précision à l'utilisateur)
3. **Exécuter** depuis n'importe quel workspace (pas besoin de `move_agent_to_root`) :

```bash
~/Projects/database-connections/scripts/db-query.sh <connection-id> "<sql>"
```

## Performance (agents)

- Exploration prod : **`foldio-production-1-ro`** uniquement.
- Plusieurs requêtes : `export DB_MYSQL_CLIENT=pool` ou `~/Projects/database-connections/scripts/db-query-fast.sh` ; batch : `db-query-batch.sh`.
- Regrouper les `SELECT` / `EXPLAIN` plutôt que N appels shell.
- Proxy GCP : démarré par `db-query` via `cloud_sql_instance` ; shell avec accès réseau complet.

## Alias courants

| Tu dis… | Id recommandé |
|---------|----------------|
| foldio staging | `foldio-staging-1-ro` (exploration) ou `foldio-staging-1` (mutation) |
| foldio production | `foldio-production-1-ro` (exploration) |
| gitlab | `gitlab-production` |
| igloo cluster | `igloo-project-igloo-cluster-ro` |

## Rappels

- Dump SQL → skill projet `~/Projects/database-connections/.cursor/skills/db-dump/SKILL.md`, script `db-dump.sh`
- Ne jamais afficher ni committer de mots de passe
- Rester dans le workspace courant pour croiser code app + résultats SQL
- **Ne jamais recopier tel quel** les lignes SQL (noms, emails, adresses, IBAN, identifiants client ou instance) dans le code, tests ou fixtures **commités** dans un repo produit — pseudonymiser (`@example.test`, faker, seeders). Les résultats SQL servent au **diagnostic** (chat, notes locales), pas au source git. Appliquer aussi les règles agent du repo app courant si présentes (ex. `sensitive-data-in-source` sur foldio-app).
