# Exemples — verify-spec

Exemples fictifs. Chemins illustratifs — adapter au projet courant.

**Rappel routing** : PR ouverte → **pr-review**. **verify-spec** = audit produit / post-merge.

---

## Exemple 1 — Redirection vers pr-review

**Utilisateur :**

```
@verify-spec ClickUp TASK-1842, Paperclip IGLAA-91 — vérifie la PR #187
```

**Agent :**

> PR #187 encore ouverte — pour un gate merge (spec + code + commentaires GitHub), utilisez **pr-review** avec les mêmes refs ClickUp/Paperclip. **verify-spec** sert à un audit sans posting GH ou post-merge. Continuer en audit-only ?

Si l'utilisateur confirme audit-only → Phase 1–4 sans posting.

---

## Exemple 2 — Audit post-merge (cas nominal verify-spec)

**Utilisateur :**

```
@verify-spec IGLAA-91 — la feature est mergée (#187), audit conformité
```

**Agent :** spec-baseline → diff `main` sur fichiers concernés → rapport NON CONFORME → STOP → user confirme triage.

---

## Exemple 3 — Rapport complet (extrait)

```markdown
# Rapport de conformité — Export CSV admin

## Sources
- ClickUp: [TASK-1842](https://app.clickup.com/t/…/TASK-1842)
- Paperclip: [IGLAA-91](https://paperclip.example/IGLAA/issues/IGLAA-91)
- Implémentation: main @ abc1234 (mergé via PR #187)

## Synthèse
**Verdict : NON CONFORME**

| ID | Exigence | Statut | Evidence |
|----|----------|--------|----------|
| AC-2 | Max 10 000 lignes + message | ❌ | `export-csv.ts:L55-72` |
| FR-5 | Nom fichier `{slug}-items-{date}.csv` | ❌ | `export-csv.ts:L34` → `export.csv` |
```

**Message agent :**

> Feature mergée avec 2 drifts haute sévérité. Corrections sur une nouvelle PR ou handoff triage → Paperclip ?

---

## Exemple 4 — Claim handoff triage (post-merge uniquement)

```markdown
## Claim (from verify-spec — post-merge)

**Symptom** : Export CSV sans limite 10k lignes ni feedback.
**Where** : `items.exportCsv`, `export-csv.ts`
**When** : Dataset > 10k rows
**Spec reference** : AC-2
**Evidence** : `src/server/jobs/export-csv.ts:L55-72`
**Context** : mergé PR #187 le 2026-05-20, fix nécessite nouvelle branche
```

Puis triage Phase 2–3 → Fix PRD → approbation → Paperclip.

---

## Exemple 5 — Conflit ClickUp vs Paperclip

Voir spec-baseline **Spec conflict protocol** — STOP avant matrice, demander source autoritaire.

---

## Exemple 6 — pr-review gate mode (référence croisée)

Pour PR #187 ouverte, **pr-review** délègue à verify-spec gate mode ; le même AC-2 apparaît comme finding :

```markdown
#### 1. export-csv.ts:55 — [AC-2] Export row limit missing [NEW]
**Dimension**: spec
**Confidence**: high
**Problem**: Spec requires max 10 000 rows with user message; loop has no cap.
**Suggested fix**: …
```

Verdict merge : `REQUEST_CHANGES`, pas de triage.
