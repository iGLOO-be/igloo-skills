# State schema — Feature Pipeline

Runtime state lives at `.planning/pipeline/{slug}/state.json`.

The orchestrator parent is the **only** writer of `state.json`. Subagents return JSON in chat; parent merges into state.

## File layout

```
.planning/pipeline/{slug}/
├── state.json       # machine state (required for resume)
├── intake.md        # original user request
├── fix-prd.md       # triage output (optional)
├── plan.md          # architect output (optional)
├── delivery.md      # junior-dev output (optional)
└── review.md        # review output (optional)
```

`.planning/` is excluded from Biome — safe for pipeline artifacts.

## state.json template

```json
{
  "slug": "oauth-error-alert",
  "createdAt": "2026-06-10T14:00:00.000Z",
  "updatedAt": "2026-06-10T15:30:00.000Z",
  "inputType": "bug",
  "startPhase": "triage",
  "phase": "plan_done",
  "outcome": null,
  "repoRoot": "/absolute/path/to/streetfundraising",
  "artifacts": {
    "intake": ".planning/pipeline/oauth-error-alert/intake.md",
    "fixPrd": ".planning/pipeline/oauth-error-alert/fix-prd.md",
    "plan": ".planning/pipeline/oauth-error-alert/plan.md",
    "delivery": null,
    "review": null
  },
  "checkpoints": {
    "cp0": { "status": "approved", "at": "2026-06-10T14:05:00.000Z" },
    "cp1": { "status": "approved", "at": "2026-06-10T14:20:00.000Z" },
    "cp2": null,
    "cp2bis": null,
    "cp3": null,
    "cp4": null
  },
  "meta": {
    "taskCount": 8,
    "migration": false,
    "escalations": 0,
    "branch": "fix/oauth-error-alert"
  }
}
```

## Field reference

| Field | Values | Notes |
|-------|--------|-------|
| `inputType` | `bug`, `feature`, `fix-prd`, `plan`, `resume` | Set at intake |
| `startPhase` | `triage`, `architect`, `implement`, `review` | Frozen at creation |
| `phase` | See phase enum below | Updated after each step |
| `outcome` | `null`, `complete`, `invalidated`, `abandoned`, `wip` | Set at terminal states |

### Phase enum

| `phase` | Meaning | Next step |
|---------|---------|-----------|
| `intake` | CP0 pending | Step matching `startPhase` |
| `triage_done` | fix-prd written | CP1 → architect |
| `plan_done` | plan written | CP2 → implement |
| `implement_done` | delivery written | CP3 → review |
| `review_done` | review written | CP4 → done/fix |
| `wip` | Stopped mid-flight | resume |
| `done` | Terminal | — |

## Start phase resolution

Priority (first match):

1. CLI `--from=triage|architect|implement|review`
2. Resume: compute from `phase` + missing checkpoints (see `nextPhase`)
3. Input path is existing `plan.md` → `implement` (CP2 still required if not approved)
4. Input path is existing PRD / `fix-prd.md` → `architect`
5. Artifact detection in pipeline dir (resume):
   - `fix-prd.md` without `plan.md` → `architect` (after CP1 if pending)
   - `plan.md` without CP2 approved → `architect` (CP2 gate)
6. **New description** (no resume, no PRD/plan path) → **`triage`** always

`inputType` (`bug` | `feature`) is set at triage classification — it does **not** skip triage for features.

**Important:** `--from=implement` with existing `plan.md` still requires **CP2 approved** in `checkpoints.cp2`. If missing, run CP2 before Step 3.

**Important:** `--from=architect` with only `intake.md` is invalid for new work — run triage first unless user supplies an existing PRD file.

## Resume logic

```
function nextPhase(state):
  if state.phase == 'done': return null
  if state.outcome in ('invalidated', 'abandoned', 'complete'): return null

  if not checkpoints.cp0: return 'intake'
  if startPhase == 'triage' and not checkpoints.cp1: return 'triage' # CP1 pending
  if not artifacts.plan and needsArchitect(state): return 'architect'
  if not checkpoints.cp2: return 'architect' # CP2 pending on plan
  if not artifacts.delivery and needsImplement(state): return 'implement'
  if not checkpoints.cp3: return 'implement' # CP3 pending
  if not artifacts.review: return 'review'
  if not checkpoints.cp4: return 'review' # CP4 pending
  return 'done'
```

## Slug derivation

If user omits `--slug`:

1. Take first line of description (max 48 chars).
2. Lowercase, replace spaces with `-`, strip non `[a-z0-9-]`.
3. Collapse repeated hyphens.
4. If collision with existing dir → append `-2`, `-3`, …

## Branch hint

Optional: record `meta.branch` when implementation starts (`git branch --show-current`). Useful for review diff scope.
