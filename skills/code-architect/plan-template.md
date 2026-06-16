# Plan template — Code Architect

Copy this structure exactly. Replace bracketed placeholders. Remove sections marked *(optional)* when N/A — write **Aucune**, never leave blank.

```markdown
# Plan d'implémentation — [Titre court]

## Métadonnées

| Champ | Valeur |
|-------|--------|
| Source | [Fix PRD / Feature brief / Description] |
| Type | [Bugfix / Feature / Refacto] |
| Complexité estimée | [S / M / L] |
| Migration DB | [Oui — décrire / Non] |

## 1. Résumé exécutif

[2–4 phrases : quoi on livre, pour qui, résultat observable.]

## 2. Contexte et périmètre

### Comportement attendu

[Résultat observable après implémentation — reprendre Fix PRD §3 si applicable.]

### Hors scope

- [Explicitement exclu]
- [Ticket séparé si pertinent]

### Hypothèses *(optional — description-only input)*

- [Hypothèse 1 et impact si fausse]

## 3. Contraintes repo

Contraintes applicables à **tous** les changements :

- [Ex: `instanceScopedProcedure` — jamais de query cross-instance]
- [Ex: formulaires — FormProvider + champs contexte, pas de prop-drill register]
- [Ex: tests Vitest colocalisés sous `src/**/__tests__/`]

## 4. Décisions d'architecture

| # | Décision | Rationale | Alternative écartée |
|---|----------|-----------|---------------------|
| D1 | [Choix] | [Pourquoi] | [Option non retenue] |

## 5. Cartographie des fichiers

| Fichier | Action | Rôle |
|---------|--------|------|
| `path/to/file.ts` | Modifier / Créer | [Rôle dans le changement] |

### Fichiers de référence (patterns à copier)

| Fichier | Lignes | Pattern |
|---------|--------|---------|
| `path/reference.ts` | L42–68 | [Ex: mutation tRPC avec permission check] |

## 6. Modèle de données *(optional)*

### Schéma Prisma

```prisma
// Champs / modèles impactés — extrait ou delta
```

### Migration

[Commande `pnpm db:migrate:dev --name …` + notes seed/backfill]

## 7. Contrats API / validation

### tRPC / server

| Procedure | Type | Permission | Input (Zod) | Output |
|-----------|------|------------|-------------|--------|
| `router.procedure` | mutation/query | `perm.code` | [champs] | [shape] |

### Validators partagés

- `src/lib/validators/...` — [changement schema]

## 8. UI / routes *(optional)*

| Route | Composant | Notes |
|-------|-----------|-------|
| `/[locale]/...` | `ComponentName` | [SSR/client, i18n namespace] |

### i18n

| Clé | Namespace | FR | EN *(si requis)* |
|-----|-----------|----|----|
| `key.name` | `Admin` | … | … |

## 9. Plan de tâches (ordre d'exécution)

### Tâche 1 — [Titre]

**Objectif:** [Une phrase]

**Fichiers:** `path/a.ts`, `path/b.tsx`

**Étapes:**
1. [Action concrète]
2. [Action concrète]

**Vérifier:**
- [ ] `pnpm test -- pattern`
- [ ] [Assertion manuelle ou typecheck]

**Référence:** copier le pattern de `path/reference.ts:L42`

---

### Tâche 2 — [Titre]

[Même structure — répéter pour chaque slice]

## 10. Gestion des erreurs et edge cases

| Cas | Comportement attendu | Où implémenter |
|-----|---------------------|----------------|
| [Ex: session expirée offline] | [Toast + redirect] | `path/file.ts` |

## 11. Tests

| Niveau | Fichier | Couvre |
|--------|---------|--------|
| Unit | `src/.../__tests__/....test.ts` | [FR / critère] |
| E2E *(optional)* | `e2e/...` | [Parcours utilisateur] |

**Commandes:**
```bash
pnpm test -- [pattern]
pnpm check
```

## 12. Critères d'acceptation

*(Reprendre Fix PRD §7 verbatim si Fix PRD — ajouter critères techniques si needed)*

- [ ] [Assertion binaire]
- [ ] [Régression : X continue de fonctionner]

## 13. Risques et rollback

| Risque | Mitigation | Rollback |
|--------|------------|----------|
| [Migration irreversible] | [Backup / feature flag] | [Revert migration strategy] |

## 14. Références

| Fichier | Lignes | Pertinence |
|---------|--------|------------|
| `path/file.ts` | L12–45 | [Pourquoi cité] |
```
