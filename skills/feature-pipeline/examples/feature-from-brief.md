# Example — Feature from brief (triage mandatory)

## User invocation

```
feature-pipeline --slug=export-csv-campaigns
Les admins doivent pouvoir exporter la liste des campagnes en CSV depuis
/admin/campaigns. Colonnes: nom, statut, dates, organisation. Permission
campaigns.read existante. Pas d'export PDF dans ce ticket.
```

## Step 0 — Intake

Type `feature`, `startPhase: triage` (all new descriptions start at triage).

**CP0:** User confirms slug and scope exclusion (PDF).

Creates:

```
.planning/pipeline/export-csv-campaigns/
├── state.json
└── intake.md
```

## Step 1 — Triage subagent

Classifies `feature`. Investigates `/admin/campaigns`, analogous exports, `campaigns.read` permission.

Returns `verdict: validated` + **Feature PRD** in `fix-prd.md` (FR1–FR3, AC checklist, hors scope PDF).

**CP1:** User reads PRD summary, selects *Approuver — architecte*.

## Step 2 — Architect subagent

Input: `fix-prd.md` (not raw intake). Produces plan with tRPC query + streaming CSV pattern from codebase analog.

**CP2:** User requests amend — add column `recruiterCount`. Architect-amendment → **CP2-bis** → approve.

## Step 3 — Implement

Junior-dev follows plan. Runs `pnpm check`. Writes `delivery.md`.

**CP3:** Approve.

## Step 4 — Review (code + spec)

Parallel subagents:

- **Review-code:** Vitest gap on CSV header row (Warning).
- **Review-spec:** AC-2 partial — missing organisation column in export (Critical).

Merged `review.md` → spec NON CONFORME.

**CP4:** User selects *Appliquer fixes* (spec Critical blocks *done*).

## Second pass — scoped implement

Step 3 relaunched with notes: "Fix spec AC-2 + review finding #1 only."

**CP3** → **Step 4** (re-review) → spec CONFORME, 0 Critical → **CP4** *Done*.

## Entry with existing PRD (skip triage)

If user already has a validated PRD file:

```
feature-pipeline --from=architect --slug=export-csv path/to/feature-prd.md
```

Orchestrator copies input to `fix-prd.md`, sets `inputType: fix-prd`, starts at Step 2 (CP1 treated as approved unless user asks to re-triage).
