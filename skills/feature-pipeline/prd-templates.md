# PRD templates — Feature Pipeline

Triage writes **one** artifact: `fix-prd.md` (historical filename — content may be Fix PRD or Feature PRD).

The architect treats `fix-prd.md` as the immutable product spec. The plan (`plan.md`) is the approved implementation blueprint (CP2).

## Bug — Fix PRD

Follow **paperclip-triage-issue** Phase 3 structure verbatim (`# Fix PRD — …`, sections 1–8).

Verdict `invalidated` when the bug cannot occur, is already fixed, or the claim is wrong.

## Feature — Feature PRD

When intake is a capability, user story, or enhancement (not a bug claim), investigate the codebase then produce:

```markdown
# Feature PRD — [Titre court et descriptif]

## 1. Contexte et problème

### Besoin utilisateur
[2–3 phrases — qui a besoin de quoi et pourquoi maintenant.]

### Situation actuelle
[Comportement ou gap observable dans le produit / codebase aujourd'hui.]

### Investigation codebase
[Résumé factuel : patterns analogues, routes/API existantes, contraintes découvertes — avec chemins `path:Lx`.]

## 2. Objectif

[Comportement cible en termes de résultat observable, pas d'implémentation.]

## 3. Acteurs et périmètre

### Acteurs
- [Rôle 1] — [ce qu'il gagne]
- [Rôle 2] — …

### Dans le scope
- [Capacité incluse]

### Hors scope
- [Explicitement exclu — ticket séparé si besoin]

## 4. Exigences fonctionnelles

Chaque FR est testable et implémentation-agnostique :

- FR1: [Acteur] peut [capacité] [contexte]
- FR2: …

## 5. Contraintes et effets de bord

### Ne pas casser
- [Fonctionnalité existante — spécifique]

### Contraintes techniques
- [Multi-tenant, permissions, offline, i18n, etc. si pertinent]

## 6. Contexte technique pour l'architecte

### Patterns à réutiliser
| Fichier / zone | Rôle |
|----------------|------|
| `path/to/file.ts` | [Pattern analogue] |

### Points d'attention
- [Décision produit laissée ouverte — l'architecte tranche dans le plan]

## 7. Critères d'acceptation

- [ ] [Assertion binaire testable]
- [ ] [Edge case]
- [ ] [Régression : X continue de fonctionner]

## 8. Références

| Fichier | Lignes | Pertinence |
|---------|--------|------------|
| `path/file.ts` | L12-45 | … |
```

Verdict `invalidated` when: capability already exists, request is duplicate, technically infeasible without scope change, or clearly out of product scope.

## Shared rules

- French for PRD body.
- Every section filled — write « Aucune » / « N/A » when not applicable.
- FR pattern: `[Acteur] peut [capacité]` — no implementation detail in FRs.
- AC are binary pass/fail assertions.
