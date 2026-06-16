# Example — Bug fix end to end

## User invocation

```
feature-pipeline Sur la page login, quand OAuth échoue, le message brut
state=access_denied s'affiche au lieu du texte traduit dans OAuthErrorAlert.
```

## Step 0 — Intake

Orchestrator derives slug `oauth-error-alert`, type `bug`, `startPhase: triage`.

**CP0:** User selects *Approuver — lancer triage*.

Creates:

```
.planning/pipeline/oauth-error-alert/
├── state.json
└── intake.md
```

## Step 1 — Triage subagent

Reads `paperclip-triage-issue`, investigates `OAuthErrorAlert`, login flow.

Returns `verdict: validated` + Fix PRD.

**CP1:** User reads summary, opens `fix-prd.md`, selects *Approuver — architecte*.

## Step 2 — Architect subagent

Reads Fix PRD, maps to `LoginForm`, i18n keys, auth guards.

Writes `plan.md` — 6 tasks, no migration.

**CP2:** User approves plan.

## Step 3 — Junior-dev subagent

Implements task-by-task. Runs `pnpm check`. Writes `delivery.md`.

**CP3:** User approves → review.

## Step 4 — Review (code + spec)

Parallel subagents on `git diff main...HEAD`:

- **Review-code:** 0 critical code findings.
- **Review-spec:** baseline `fix-prd.md` §7 AC — CONFORME.

**CP4:** User selects *Create PR* → orchestrator follows PR creation rules separately.

Final `state.json`:

```json
{
  "phase": "done",
  "outcome": "complete",
  "checkpoints": {
    "cp0": { "status": "approved" },
    "cp1": { "status": "approved" },
    "cp2": { "status": "approved" },
    "cp3": { "status": "approved" },
    "cp4": { "status": "approved", "notes": "pr" }
  }
}
```

## Resume example

Session interrupted after plan written, before CP2:

```
feature-pipeline resume oauth-error-alert
```

Orchestrator shows `phase: plan_done`, CP2 pending → runs **CP2** only, then continues from Step 3 on approval.
