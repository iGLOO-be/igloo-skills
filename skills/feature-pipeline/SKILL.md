---
name: feature-pipeline
description: >-
  Orchestrates end-to-end feature or bug development: mandatory triage (PRD) →
  architect plan → junior implementation → code + spec review against the PRD
  or approved plan, with manual checkpoints at each gate. Local artifacts only
  (.planning/pipeline/). Supports resume via --from= or state.json. Use for
  "feature pipeline", "dev pipeline", "feature end to end", "e2e dev", or
  "from bug to PR".
disable-model-invocation: true
---

# Feature Pipeline (orchestrator)

Thin orchestrator — **no inline reimplementation** of triage, architect, junior-dev, or review logic. Parent manages state, checkpoints, and artifact I/O; heavy work goes to Task subagents.

Communicate in French. Code and commits in English.

## Skill root

Directory containing this `SKILL.md` — **`skills/feature-pipeline/`** in this repo; install to `.agents/skills/feature-pipeline/` in target projects.

## Related skills (read paths, delegate execution)

| Phase | Skill | Artifact |
|-------|-------|----------|
| Triage | [paperclip-triage-issue](../paperclip-triage-issue/SKILL.md) + [prd-templates.md](prd-templates.md) | `fix-prd.md` (PRD) |
| Plan | [code-architect](../code-architect/SKILL.md) | `plan.md` |
| Impl | [junior-dev](../junior-dev/SKILL.md) | code + `delivery.md` |
| Review | [pr-review](../pr-review/SKILL.md) pattern (code + spec) | `review.md` |

**Paperclip API: never.** Triage Phase 4 is always skipped. All specs live under `.planning/pipeline/{slug}/`.

## Install (target project)

Copy or symlink from this repo into the consuming project:

| Skill | Target path |
|-------|-------------|
| `feature-pipeline`, `code-architect`, `junior-dev`, `paperclip-triage-issue` | `.agents/skills/{name}/` |
| `pr-review`, `spec-check` | `.cursor/skills/{name}/` |

Dependencies `paperclip-triage-issue`, `pr-review`, and `spec-check` are already in this repo under `skills/`.

## Invocation

```
feature-pipeline [description or path]
feature-pipeline --slug=my-feature [description]
feature-pipeline --from=triage|architect|implement|review [--slug=...]
feature-pipeline resume [slug]
```

| Flag / form | Effect |
|-------------|--------|
| `--slug=` | Pipeline directory name (kebab-case). Auto-derived from title if omitted. |
| `--from=` | Force start phase (overrides artifact detection). |
| `resume {slug}` | Load `state.json`, show recap, continue from next pending phase. |
| Path to `.md` | Use as intake; detect type (Fix PRD / plan / brief). |

## Step 0 — Resolve entry

1. Parse args and user text → `slug`, optional `--from`, optional file path.
2. **Resume path:** if `resume` or existing `.planning/pipeline/{slug}/state.json`:
   - Read [state-schema.md](state-schema.md).
   - Present recap (phase, checkpoints, artifact paths, open blockers).
   - Run **CP0-resume** from [checkpoints.md](checkpoints.md). **STOP until answered.**
3. **New pipeline:** derive `slug` (kebab-case, max 48 chars), create directory:

   ```
   .planning/pipeline/{slug}/
   ├── state.json
   └── intake.md
   ```

4. **Classify start phase** (first match wins):

   | Condition | `startPhase` |
   |-----------|--------------|
   | `--from=` set | flag value |
   | Input path is an approved `plan.md` | `implement` |
   | Input path is a PRD / `fix-prd.md` | `architect` |
   | Resume: `fix-prd.md` exists, no `plan.md`, CP1 approved | `architect` |
   | Resume: `plan.md` exists, CP2 not approved | `architect` (CP2 pending) |
   | Resume: `plan.md` exists, CP2 approved | `implement` |
   | **New description** (any bug, feature, or free text) | **`triage`** |
   | Ambiguous | ask one question, then default **`triage`** |

   **Rule:** a fresh user description **always** starts at triage — features no longer skip to architect. Triage produces the PRD (`fix-prd.md`) handed to the architect at CP1.

5. Write initial `state.json` (see state-schema.md).
6. **CP0** — confirm slug, type, start phase, out-of-scope. **STOP until approved.**

Record `checkpoints.cp0` on approval.

## Step 1 — Triage (mandatory for new descriptions)

**Run when:** `startPhase` is `triage`, or resume needs CP1.

1. Classify intake as `bug` or `feature` (record in `state.inputType`).
2. Spawn subagent — prompt from [subagent-prompts.md](subagent-prompts.md) § Triage.
3. Parse return JSON. Write `fix-prd.md` (PRD body) if `verdict: validated`.
4. Update `state.phase = triage_done`.

**CP1** — see checkpoints.md. **STOP until answered.**

| Outcome | Next |
|---------|------|
| Approuver | Step 2 |
| Itérer | Relaunch triage with user notes → CP1 |
| Rejeter / invalidé | Set `state.phase = done`, `outcome = invalidated`. **STOP.** |

## Step 2 — Architect

**Run when:** `startPhase` ≤ `architect` and CP1 passed (or triage skipped).

1. Input: `fix-prd.md` if present, else `intake.md`.
2. Spawn subagent — prompt § Architect.
3. Write `plan.md`. Update `state.phase = plan_done`.

**CP2** — see checkpoints.md. **STOP until answered.**

| Outcome | Next |
|---------|------|
| Approuver | Step 3 |
| Amendement | Relaunch architect with notes → CP2 |
| Revoir Fix PRD | Step 1 (bugs only) |
| Abandonner | `state.phase = done`, `outcome = abandoned`. **STOP.** |

## Step 3 — Implement

**Run when:** `startPhase` ≤ `implement` and CP2 passed.

1. Spawn subagent — prompt § Junior-dev (`readonly: false`).
2. On `{ "escalation": true }`:
   - Present escalation to user.
   - Spawn § Architect-amendment with escalation body.
   - **CP2-bis** — approve plan amendment. **STOP until answered.**
   - Relaunch junior-dev from blocked task.
3. Write `delivery.md`. Update `state.phase = implement_done`.

**CP3** — see checkpoints.md. **STOP until answered.**

| Outcome | Next |
|---------|------|
| Approuver review | Step 4 |
| Retour impl | Step 3 with user notes |
| Abandonner | `state.phase = wip`, **STOP** (artefacts preserved) |

## Step 4 — Review (code + spec)

**Run when:** CP3 passed.

1. Determine diff scope:
   - If open PR exists for current branch → may delegate full [pr-review](../pr-review/SKILL.md) **only if** user explicitly asks; otherwise use branch diff below.
   - Else: `git diff main...HEAD` (or `origin/main...HEAD`; fallback staged + unstaged).
2. Resolve **spec baseline** (precedence):
   - **Primary:** `fix-prd.md` (PRD from triage — immutable product spec).
   - **Fallback:** `plan.md` approved at CP2 (when no PRD file, e.g. `--from=architect` with external plan).
   - If both exist: gate FR/AC against PRD §4/§7; cross-check plan §12 / technical scope against implementation.
3. Spawn **in parallel** (pr-review Step 1 pattern):
   - **A — Code review:** subagent § Review-code.
   - **B — Spec gate:** subagent § Review-spec (always — not conditional on Paperclip/ClickUp).
4. Parent merges findings: map spec drifts to `dimension: spec`; dedupe same path/line; Critical spec ❌ blocks CP4 *done* recommendation.
5. Write `review.md` (code + spec sections). Update `state.phase = review_done`.

Present findings recap: **Spec verdict** + Critical / Warning / Note (code and spec).

**CP4** — see checkpoints.md. **STOP until answered.**

| Outcome | Next |
|---------|------|
| Appliquer fixes | Step 3 (scoped to findings) |
| Commit | Only if user explicitly selects — follow commit rules |
| Create PR | Only if user explicitly selects — follow PR creation rules |
| Done | `state.phase = done`, `outcome = complete`. **STOP.** |

## Orchestrator rules

- **Never** implement application code in orchestrator mode — delegate to junior-dev subagent.
- **Never** skip **triage** on a new user description — architect receives `fix-prd.md` only after CP1.
- **Never** skip **CP2** before Step 3.
- **Never** skip **spec review** at Step 4 — always parallel with code review.
- **Never** commit, push, or open PR without explicit CP4 choice.
- **Never** call Paperclip API.
- Subagents return JSON + markdown bodies; **parent writes all artifacts**.
- After code edits anywhere in pipeline: run `pnpm check` before CP3/CP4 claims.
- Invalidated triage ends at CP1 — do not call architect.
- Idempotent resume: always read `state.json` + latest artifacts before continuing.

## Subagent spawning

Use `Task` tool. Prompts: [subagent-prompts.md](subagent-prompts.md).

| Phase | subagent_type | readonly |
|-------|---------------|----------|
| Triage | `generalPurpose` | `true` |
| Architect | `generalPurpose` | `true` |
| Architect-amendment | `generalPurpose` | `true` |
| Junior-dev | `generalPurpose` | `false` |
| Review-code | `code-reviewer` | `true` |
| Review-spec | `explore` | `true` |

Pass absolute repo path and pipeline artifact paths in every prompt.

## Resources

| File | Role |
|------|------|
| [checkpoints.md](checkpoints.md) | AskQuestion templates per gate |
| [state-schema.md](state-schema.md) | `state.json` format and resume logic |
| [subagent-prompts.md](subagent-prompts.md) | Task() prompt templates |
| [prd-templates.md](prd-templates.md) | Fix PRD + Feature PRD structures for triage |
| [examples/bug-fix-end-to-end.md](examples/bug-fix-end-to-end.md) | Walkthrough |
| [examples/feature-from-brief.md](examples/feature-from-brief.md) | Walkthrough |
