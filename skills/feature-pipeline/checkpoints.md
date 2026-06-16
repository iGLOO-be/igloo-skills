# Checkpoints — Feature Pipeline

Every checkpoint **must** use `AskQuestion` (not free-text "ok?"). Record approval in `state.json` → `checkpoints.{id}`.

After each approval:

```json
"cpN": { "status": "approved", "at": "<ISO8601>", "notes": "<optional user feedback>" }
```

On reject/abandon:

```json
"cpN": { "status": "rejected|abandoned|iterated", "at": "<ISO8601>", "notes": "..." }
```

---

## CP0 — Intake (new pipeline)

**When:** Step 0, before any subagent.

**Prompt:** `Confirmer le démarrage du pipeline ?`

| Option id | Label |
|-----------|-------|
| `approve` | Approuver — lancer la phase `{startPhase}` (Recommended) |
| `edit-slug` | Changer le slug (demander le nouveau slug en follow-up) |
| `edit-scope` | Ajuster le périmètre (demander précisions, mettre à jour intake.md) |
| `abort` | Abandonner — ne pas créer de pipeline |

**Present before asking:**

- Slug: `{slug}`
- Type: `{bug | feature | fix-prd | plan-resume}` — nouvelle description → **`triage`**
- Phase de départ: `{startPhase}`
- Répertoire: `.planning/pipeline/{slug}/`

---

## CP0-resume — Reprise session

**When:** `resume` or existing `state.json`.

**Prompt:** `Reprendre le pipeline « {slug} » ?`

| Option id | Label |
|-----------|-------|
| `continue` | Continuer depuis `{nextPhase}` (Recommended) |
| `restart-phase` | Relancer une phase (demander laquelle: triage / architect / implement / review) |
| `abort` | Abandonner — conserver les artefacts, stop |

**Present before asking:**

- Phase actuelle: `{state.phase}`
- Checkpoints passés: `{list}`
- Artefacts: fix-prd / plan / delivery / review (present/missing)
- Blockers: `{escalation or review critical count}`

---

## CP1 — PRD (post-triage)

**When:** Step 1 complete, verdict `validated`.

**Prompt:** `Le PRD est prêt. Que faire ?`

| Option id | Label |
|-----------|-------|
| `approve` | Approuver — passer à l'architecte (Recommended) |
| `iterate` | Demander des modifications au triage |
| `reject` | Rejeter — invalidé ou hors scope |

**Present:**

- Type: `{Fix PRD | Feature PRD}`
- Résumé 3 lignes (symptôme/objectif, cause racine ou gap, sévérité/priorité)
- Path: `fix-prd.md`

If subagent returned `invalidated` → skip AskQuestion; explain and **STOP**.

---

## CP2 — Plan (pre-code gate)

**When:** Step 2 complete. **Mandatory before any implementation.**

**Prompt:** `Le plan d'implémentation est prêt. Aucun code ne sera écrit sans votre accord.`

| Option id | Label |
|-----------|-------|
| `approve` | Approuver — lancer l'implémentation (Recommended) |
| `amend` | Demander des modifications à l'architecte |
| `back-triage` | Revoir le Fix PRD (bugs uniquement) |
| `abort` | Abandonner — conserver plan.md, stop |

**Present:**

- Tâches §9: `{count}`
- Migration DB: `{yes/no}`
- Risques top-3 from plan
- Path: `plan.md`

---

## CP2-bis — Amendement plan (post-escalade)

**When:** Junior-dev returned escalation; architect-amendment subagent finished.

**Prompt:** `L'architecte propose un amendement au plan. Valider avant reprise de l'implémentation ?`

| Option id | Label |
|-----------|-------|
| `approve` | Approuver l'amendement — reprendre l'implémentation (Recommended) |
| `amend` | Autre modification |
| `abort` | Stop — état WIP |

**Present:** diff summary (sections changed, scope impact).

---

## CP3 — Livraison (pre-review gate)

**When:** Step 3 complete, `pnpm check` result known.

**Prompt:** `L'implémentation est terminée. Passer à la review ?`

| Option id | Label |
|-----------|-------|
| `approve` | Approuver — lancer la review (Recommended) |
| `back-impl` | Retour implémentation (préciser quoi corriger) |
| `abort` | Stop — WIP preserved |

**Present:** delivery summary — tasks X/Y, `pnpm check`, acceptance criteria checklist from `delivery.md`.

---

## CP4 — Review (merge gate)

**When:** Step 4 complete.

**Prompt:** `Review terminée. Prochaine action ?`

| Option id | Label |
|-----------|-------|
| `fix` | Appliquer les corrections (retour impl, scope = findings) |
| `commit` | Créer un commit (uniquement si l'utilisateur le choisit explicitement) |
| `pr` | Créer une PR (uniquement si l'utilisateur le choisit explicitement) |
| `done` | Terminer sans commit/PR (Recommended si review OK et pas prêt à merger) |

**Present:** Spec verdict (CONFORME / PARTIELLEMENT / NON CONFORME) + Critical / Warning / Note counts (code + spec) + link to `review.md`.

**Block *done* recommendation** when any Critical spec ❌ or Critical code finding remains unresolved.

**Never** auto-select `commit` or `pr` — user must pick explicitly.
