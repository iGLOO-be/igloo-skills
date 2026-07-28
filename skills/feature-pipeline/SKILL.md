---
name: feature-pipeline
description: >-
  Orchestrates end-to-end feature or bug development: mandatory triage (PRD) →
  architect plan → junior implementation → code + spec review against the PRD
  or approved plan, with manual checkpoints at each gate. Supports --lite for
  lower token use. Local artifacts only (.planning/pipeline/). Resume via
  --from= or state.json. Use for "feature pipeline", "dev pipeline",
  "feature end to end", "e2e dev", or "from bug to PR".
disable-model-invocation: true
---

# Feature Pipeline (orchestrator)

Thin orchestrator — **no inline reimplementation** of triage, architect, junior-dev, or review logic. Parent manages state, checkpoints, and thin JSON merges; heavy work goes to Task subagents that **write artifacts to disk**.

Communicate in French. Code and commits in English.

## Skill root

Directory containing this `SKILL.md` — **`skills/feature-pipeline/`** in this repo; install to `.agents/skills/feature-pipeline/` in target projects.

## Related skills (briefs first, full skills fallback)

| Phase | Read (prefer) | Artifact writer |
|-------|---------------|-----------------|
| Triage | [briefs/triage.md](briefs/triage.md) + [prd-templates.md](prd-templates.md) | Subagent → `fix-prd.md` |
| Plan | [briefs/architect.md](briefs/architect.md) + [code-architect](../code-architect/SKILL.md) template/checklist | Subagent → `plan.md` |
| Impl | [briefs/junior.md](briefs/junior.md) | Subagent → code + `delivery.md` (final batch) |
| Review | [pr-review](../pr-review/SKILL.md) rubric + [spec-check](../spec-check/SKILL.md) gate (full mode) | Parent merges → `review.md` |

**Paperclip API: never.** Triage Phase 4 is always skipped. All specs live under `.planning/pipeline/{slug}/`. Prefer **briefs/** so subagents do not reload full sibling SKILL.md.

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
feature-pipeline --lite [description]
feature-pipeline --from=triage|architect|implement|review [--slug=...]
feature-pipeline resume [slug]
```

| Flag / form | Effect |
|-------------|--------|
| `--slug=` | Pipeline directory name (kebab-case). Auto-derived from title if omitted. |
| `--lite` | Token-saving mode: skip triage (architect from intake), single-shot junior, code review only (no spec gate). Record `meta.lite: true`. |
| `--from=` | Force start phase (overrides artifact detection). |
| `resume {slug}` | Load `state.json`, show recap, continue from next pending phase. |
| Path to `.md` | Use as intake; detect type (Fix PRD / plan / brief). |

## Token budget (orchestrator)

- Subagents **write** `fix-prd.md` / `plan.md` / `delivery.md` / `escalation.md`; parent writes **only** `state.json`, `intake.md`, and merged `review.md`.
- Subagent replies = **thin JSON only** — never paste full artifacts into chat.
- Parent reads [subagent-prompts.md](subagent-prompts.md) **section for the current phase only** (not the whole file when avoidable).
- Parent presents CP recaps from JSON `summary` + artifact **paths**; open files on demand, do not dump full PRD/plan into the parent thread.
- Junior: batch when `taskCount > 4` and not lite — see subagent-prompts § Junior-dev.

## Step 0 — Resolve entry

1. Parse args and user text → `slug`, optional `--from`, optional `--lite`, optional file path.
2. **Resume path:** if `resume` or existing `.planning/pipeline/{slug}/state.json`:
   - Read [state-schema.md](state-schema.md).
   - Present recap (phase, checkpoints, artifact paths, open blockers, `lite` if set).
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
   | `--lite` on new description | `architect` (skip triage; CP1 auto-skipped) |
   | Input path is an approved `plan.md` | `implement` |
   | Input path is a PRD / `fix-prd.md` | `architect` |
   | Resume: `fix-prd.md` exists, no `plan.md`, CP1 approved | `architect` |
   | Resume: `plan.md` exists, CP2 not approved | `architect` (CP2 pending) |
   | Resume: `plan.md` exists, CP2 approved | `implement` |
   | **New description** (no `--lite`) | **`triage`** |
   | Ambiguous | ask one question, then default **`triage`** (or `architect` if `--lite`) |

   **Rule:** without `--lite`, a fresh user description **always** starts at triage. With `--lite`, intake is the architect input (`feature-brief` / free description); set `checkpoints.cp1` to `{ status: "skipped", at, notes: "lite" }`.

5. Write initial `state.json` (see state-schema.md). Set `meta.lite` from flag.
6. **CP0** — confirm slug, type, start phase, lite, out-of-scope. **STOP until approved.**

Record `checkpoints.cp0` on approval.

## Step 1 — Triage (mandatory for new descriptions unless `--lite`)

**Skip when:** `meta.lite` or `startPhase` is already `architect|implement|review` with existing PRD/plan.

**Run when:** `startPhase` is `triage`, or resume needs CP1.

1. Classify intake as `bug` or `feature` (record in `state.inputType`).
2. Spawn subagent — prompt from [subagent-prompts.md](subagent-prompts.md) § Triage (`artifactPath` = abs path to `fix-prd.md`).
3. Parse thin JSON. Verify `fix-prd.md` exists on disk if `verdict: validated`.
4. Update `state.phase = triage_done`.

**CP1** — see checkpoints.md. **STOP until answered.**

| Outcome | Next |
|---------|------|
| Approuver | Step 2 |
| Itérer | Relaunch triage with user notes → CP1 |
| Rejeter / invalidé | Set `state.phase = done`, `outcome = invalidated`. **STOP.** |

## Step 2 — Architect

**Run when:** `startPhase` ≤ `architect` and (CP1 passed **or** lite / triage skipped).

1. Input: `fix-prd.md` if present, else `intake.md`.
2. Spawn subagent — prompt § Architect (`artifactPath` = abs path to `plan.md`).
3. Verify `plan.md` on disk. Update `state.phase = plan_done`; store `meta.taskCount` from JSON.

**CP2** — see checkpoints.md. **STOP until answered.**

| Outcome | Next |
|---------|------|
| Approuver | Step 3 |
| Amendement | Relaunch architect with notes → CP2 |
| Revoir Fix PRD | Step 1 (bugs only; not in lite without PRD) |
| Abandonner | `state.phase = done`, `outcome = abandoned`. **STOP.** |

## Step 3 — Implement (batched)

**Run when:** `startPhase` ≤ `implement` and CP2 passed.

1. Count §9 tasks in `plan.md`. Apply batching rules in subagent-prompts § Junior-dev.
2. For each batch (sequential):
   - Spawn § Junior-dev with `taskIds`, `batchIndex`, `isFinalBatch`.
   - On `{ "escalation": true }`:
     - Present escalation (read `escalationPath` if set).
     - Spawn § Architect-amendment.
     - **CP2-bis** — approve plan amendment. **STOP until answered.**
     - Resume junior from `blockedTaskId` (rebuild remaining batches).
   - Merge `tasksCompleted` / `filesTouched` into `state.meta`.
3. Final batch must produce `delivery.md`. Update `state.phase = implement_done`.

**CP3** — see checkpoints.md. **STOP until answered.**

| Outcome | Next |
|---------|------|
| Approuver review | Step 4 |
| Retour impl | Step 3 with user notes (scoped; prefer single-shot for fix-up) |
| Abandonner | `state.phase = wip`, **STOP** (artefacts preserved) |

## Step 4 — Review (code [+ spec])

**Run when:** CP3 passed.

1. Determine diff scope:
   - If open PR exists for current branch → may delegate full [pr-review](../pr-review/SKILL.md) **only if** user explicitly asks; otherwise use branch diff below.
   - Else: `git diff main...HEAD` (or `origin/main...HEAD`; fallback staged + unstaged).
2. Resolve **spec baseline** (full mode only):
   - **Primary:** `fix-prd.md`
   - **Fallback:** `plan.md` approved at CP2
   - If both exist: gate FR/AC against PRD; cross-check plan §12 against implementation.
3. Spawn:
   - **Always:** **A — Code review** (§ Review-code).
   - **Full mode only:** **B — Spec gate** (§ Review-spec) in parallel.
   - **Lite:** skip B; record spec verdict `skipped-lite` in `review.md`.
4. Parent merges findings; Critical spec ❌ blocks CP4 *done* (full mode).
5. Parent writes `review.md`. Update `state.phase = review_done`.

Present findings recap: **Spec verdict** (or skipped-lite) + Critical / Warning / Note.

**CP4** — see checkpoints.md. **STOP until answered.**

| Outcome | Next |
|---------|------|
| Appliquer fixes | Step 3 (scoped to findings; single-shot junior) |
| Commit | Only if user explicitly selects — follow commit rules |
| Create PR | Only if user explicitly selects — follow PR creation rules |
| Done | `state.phase = done`, `outcome = complete`. **STOP.** |

## Orchestrator rules

- **Never** implement application code in orchestrator mode — delegate to junior-dev subagent.
- **Never** skip **triage** on a new user description **unless** `--lite` or `--from=` / existing PRD.
- **Never** skip **CP2** before Step 3.
- **Never** skip **spec review** at Step 4 **unless** `meta.lite` (or user explicitly waives).
- **Never** commit, push, or open PR without explicit CP4 choice.
- **Never** call Paperclip API.
- **Never** paste full PRD/plan/delivery into parent chat — paths + thin JSON only.
- Subagents write phase artifacts; **parent writes** `state.json`, `intake.md`, `review.md`.
- After code edits anywhere in pipeline: run `pnpm check` before CP3/CP4 claims (final junior batch should already have).
- Invalidated triage ends at CP1 — do not call architect.
- Idempotent resume: always read `state.json` + latest artifacts before continuing.

## Subagent spawning

Use `Task` tool. Prompts: [subagent-prompts.md](subagent-prompts.md).

| Phase | subagent_type | writes disk |
|-------|---------------|-------------|
| Triage | `generalPurpose` | `fix-prd.md` |
| Architect | `generalPurpose` | `plan.md` |
| Architect-amendment | `generalPurpose` | `plan.md` |
| Junior-dev (per batch) | `generalPurpose` | code + `delivery.md` if final |
| Review-code | `code-reviewer` | — (JSON) |
| Review-spec | `explore` | — (JSON; skip if lite) |

Pass absolute `repoRoot` and absolute artifact paths in every prompt.

## Resources

| File | Role |
|------|------|
| [checkpoints.md](checkpoints.md) | AskQuestion templates per gate |
| [state-schema.md](state-schema.md) | `state.json` format and resume logic |
| [subagent-prompts.md](subagent-prompts.md) | Task() prompt templates |
| [briefs/](briefs/) | Thin phase instructions for subagents |
| [prd-templates.md](prd-templates.md) | Fix PRD + Feature PRD structures for triage |
| [examples/bug-fix-end-to-end.md](examples/bug-fix-end-to-end.md) | Walkthrough |
| [examples/feature-from-brief.md](examples/feature-from-brief.md) | Walkthrough |
