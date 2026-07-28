# Subagent prompts — Feature Pipeline

Parent fills `{placeholders}` and spawns via `Task`. Every prompt must include `{repoRoot}` (absolute path).

**Token rules (mandatory):**

1. Subagents **write** phase artifacts to disk at the given absolute paths.
2. Return **thin JSON only** — never embed full PRD/plan/delivery markdown in the JSON or as a second copy in the reply.
3. Prefer pipeline **briefs** over full sibling `SKILL.md` files (unless brief is missing).

---

## Triage

```
subagent_type: generalPurpose
readonly: false
description: Pipeline triage {slug}
```

`readonly: false` so the subagent can write `fix-prd.md` only (no app source).

```markdown
## Objective

Produce a **PRD** for pipeline `{slug}` — mandatory gate before architect (unless `--lite`).

## Read first

- `{repoRoot}/.agents/skills/feature-pipeline/briefs/triage.md`
- `{repoRoot}/.agents/skills/feature-pipeline/prd-templates.md` (Feature structure; Fix PRD = triage brief)

Do **not** load full `paperclip-triage-issue/SKILL.md` unless the brief is insufficient for a bug Fix PRD section layout.

## Input type

`{bug | feature}`

## Input

Path: `{intakePath}` — read this file (do not expect intake pasted below).

## Artifact

If validated, write the full PRD markdown to:

`{artifactPath}`

If invalidated, do not create/overwrite that file.

## Rules

- No Paperclip API.
- French for PRD content.
- PRD must be self-sufficient for architect — no open investigation left.
- Reply with **JSON only** (one fenced block). No PRD body in the reply.

## Return (JSON only)

```json
{
  "verdict": "validated",
  "inputType": "bug|feature",
  "prdType": "fix|feature",
  "artifactPath": "{artifactPath}",
  "summary": {
    "title": "...",
    "severity": "Critique|Haute|Moyenne|Basse",
    "rootCauseOneLine": "... bug only, else null ...",
    "objectiveOneLine": "... feature one-liner ..."
  }
}
```
```

---

## Architect

```
subagent_type: generalPurpose
readonly: false
description: Pipeline architect {slug}
```

```markdown
## Objective

Produce implementation plan for pipeline `{slug}`.

## Read first

- `{repoRoot}/.agents/skills/feature-pipeline/briefs/architect.md`
- `{repoRoot}/.agents/skills/code-architect/plan-template.md`
- `{repoRoot}/.agents/skills/code-architect/checklist.md`

Do **not** load full `code-architect/SKILL.md` unless the brief is insufficient.

## Input

Type: {fix-prd | feature-brief | intake-lite}
Path: `{inputPath}` — read from disk.

## Artifact

Write the full plan markdown to:

`{artifactPath}`

## Rules

- Do NOT modify application source files.
- Do NOT call Paperclip API.
- Self-check checklist before return.
- French for plan content.
- Reply with **JSON only**. No plan body in the reply.

## Return (JSON only)

```json
{
  "artifactPath": "{artifactPath}",
  "taskCount": 8,
  "migration": false,
  "complexity": "S|M|L",
  "risks": ["...", "..."],
  "filesTouched": 12
}
```
```

---

## Architect-amendment

Same as Architect (brief + template + checklist), plus:

```markdown
## Escalation context

Read from disk if path given, else use block below:

{escalationPath or escalation markdown}

## Task

Amend plan at `{planPath}` minimally. Overwrite `{artifactPath}` (usually same as planPath).

Return JSON only:

```json
{
  "artifactPath": "{artifactPath}",
  "amendment": true,
  "sectionsChanged": ["§9 Tâche 3", "..."],
  "taskCount": 8,
  "migration": false,
  "complexity": "S|M|L",
  "risks": ["..."],
  "filesTouched": 12
}
```
```

---

## Junior-dev (batched)

```
subagent_type: generalPurpose
readonly: false
description: Pipeline implement {slug} batch {batchIndex}/{batchTotal}
```

### Parent batching rules

Before spawning:

1. Read `plan.md`, count §9 tasks → `taskCount`.
2. **Single shot** when `taskCount <= 4` **or** `lite: true` **or** user notes force single pass:
   - `taskIds` = all tasks; `isFinalBatch: true`.
3. **Batched** when `taskCount > 4` and not lite:
   - Chunk size **3** (last chunk may be smaller).
   - Spawn batches **sequentially** (later batches need earlier code).
   - Intermediate: `isFinalBatch: false` — no `delivery.md`.
   - Final batch: `isFinalBatch: true` — write `delivery.md`, run `pnpm check`.
4. On escalation: stop batches; run Architect-amendment → CP2-bis → resume from blocked task id.
5. Track in `state.meta`: `implementBatches`, `tasksCompleted`, `currentBatch`.

```markdown
## Objective

Implement plan batch for pipeline `{slug}` per junior brief.

## Read first

- `{repoRoot}/.agents/skills/feature-pipeline/briefs/junior.md`
- Plan: `{planPath}` — focus §2, §3, §5, §12, and **only** §9 tasks `{taskIds}`
- Prior delivery notes (if any): `{priorNotes or "none"}`

Do **not** load full `junior-dev/SKILL.md` unless the brief is insufficient.

## Batch

- batchIndex: `{batchIndex}` / `{batchTotal}`
- taskIds: `{taskIds}` (e.g. [1,2,3])
- isFinalBatch: `{true|false}`
- deliveryPath: `{deliveryPath}` (write only if isFinalBatch)

## Scope notes from user (if any)

{cp3-back-impl notes or empty}

## Rules

- Implement **only** listed taskIds; do not start later tasks.
- On blocking ambiguity: STOP and return escalation — do not guess.
- If isFinalBatch: run `pnpm check` (+ plan §11 tests); write `delivery.md` to deliveryPath.
- If not final: do not write delivery.md; do not claim full plan done.
- Do NOT commit unless explicitly told.
- Reply with **JSON only**. Never embed delivery markdown in JSON.

## Return — escalation

```json
{
  "escalation": true,
  "blockedTaskId": 3,
  "escalationPath": "{repoRoot}/.planning/pipeline/{slug}/escalation.md",
  "summary": "one-line blocker"
}
```

If escalating: write escalation markdown to `escalationPath` (use junior escalation-template structure: problem, evidence paths, options).

## Return — batch ok (not final)

```json
{
  "escalation": false,
  "isFinalBatch": false,
  "tasksCompleted": [1, 2, 3],
  "filesTouched": ["src/..."],
  "notes": "optional one-liner"
}
```

## Return — final ok

```json
{
  "escalation": false,
  "isFinalBatch": true,
  "artifactPath": "{deliveryPath}",
  "tasksCompleted": [1, 2, 3, 4, 5, 6],
  "tasksTotal": 6,
  "checkOk": true,
  "filesTouched": ["src/..."]
}
```
```

---

## Review-code

```
subagent_type: code-reviewer
readonly: true
description: Pipeline code review {slug}
```

```markdown
## Objective

Code review for pipeline `{slug}` implementation.

## Read first

- `{repoRoot}/.cursor/skills/pr-review/pr-review-rubric.md` (if exists; else CLAUDE.md / AGENTS.md)
- Plan: `{repoRoot}/.planning/pipeline/{slug}/plan.md` — §2 scope, §12 AC cross-check only for scope creep
- Delivery: `{repoRoot}/.planning/pipeline/{slug}/delivery.md`

## Diff scope

Base ref: `{baseRef}`

```bash
git diff {baseRef}...HEAD
```

Changed files: {list or "run git diff in repo"}

## Rules

- Read actual source at cited paths/lines before emitting findings.
- Flag scope creep vs plan §2.
- Do NOT evaluate FR/AC spec conformance here — spec subagent handles that (unless lite skipped spec).
- **JSON only** — keep findings concise (no large code dumps).

## Return

```json
{
  "findings": [
    {
      "severity": "critical|warning|note",
      "dimension": "correctness|security|performance|types|conventions",
      "confidence": "high|medium|low",
      "path": "src/...",
      "line": 42,
      "title": "...",
      "problem": "...",
      "suggestedFix": "..."
    }
  ],
  "positives": ["..."]
}
```
```

---

## Review-spec

```
subagent_type: explore
readonly: true
description: Pipeline spec gate {slug}
```

**Skip entirely when `state.meta.lite === true`** unless user explicitly requests spec review.

```markdown
## Objective

Spec conformance gate for pipeline `{slug}` — parallel to code review (full mode).

## Read first

- `{repoRoot}/.cursor/skills/spec-check/gate-rubric.md`
- `{repoRoot}/.cursor/skills/spec-check/spec-baseline.md`
- Spec baseline: `{specBaselinePath}`
- Plan: `{repoRoot}/.planning/pipeline/{slug}/plan.md`
- Delivery: `{repoRoot}/.planning/pipeline/{slug}/delivery.md`

## Diff scope

Base ref: `{baseRef}`

## Baseline precedence

1. **PRD** (`fix-prd.md`) — FR + AC gate.
2. **Plan** — when PRD absent; when both exist, PRD wins for FR/AC; plan §12 supplements.

## Workflow

1. Extract numbered FR-n / AC-n from baseline.
2. Map diff + files to each requirement.
3. Status per spec-baseline with `path:Lx` evidence.
4. Scope creep (ℹ️) for out-of-scope changes.

## Rules

- No Paperclip/ClickUp. No triage handoff.
- **JSON only** per gate-rubric.md. Concise evidence strings.

## Return

JSON per gate-rubric.md (`specSummary`, `findings`, `scopeCreep`, `conflicts`).
```

---

## Review merge (parent orchestrator)

After Review-code (+ Review-spec if not lite):

1. Map spec findings → `dimension: spec` (❌ → critical, ⚠️ → warning, ℹ️ → note).
2. Dedupe on `path:line`.
3. **Parent writes** `review.md` (only merged artifact the parent authors):

```markdown
# Review — {slug}

## Spec conformance
**Baseline:** {fix-prd.md | plan.md | skipped-lite}
**Verdict:** …

## Code findings
### Critical / Warning / Note
…

## Spec findings
…

## Positives
…
```

4. French recap for CP4.
