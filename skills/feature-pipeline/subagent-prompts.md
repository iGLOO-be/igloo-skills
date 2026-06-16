# Subagent prompts — Feature Pipeline

Parent fills `{placeholders}` and spawns via `Task`. Every prompt must include `{repoRoot}` (absolute path).

Return contract: subagent ends with a fenced JSON block — parent parses it.

---

## Triage

```
subagent_type: generalPurpose
readonly: true
description: Pipeline triage {slug}
```

```markdown
## Objective

Produce a **PRD** for pipeline `{slug}` — mandatory gate before architect.

## Read first

- `{repoRoot}/.agents/skills/paperclip-triage-issue/SKILL.md` (bugs)
- `{repoRoot}/.agents/skills/feature-pipeline/prd-templates.md` (bugs + features)

## Input type

`{bug | feature}` — classify from intake.

## Input

```markdown
{intake.md contents}
```

## Workflow

### Bug (`inputType: bug`)

Execute **paperclip-triage-issue** Phases 1–3. Output: **Fix PRD** per triage skill template.

### Feature (`inputType: feature`)

1. Parse need: actors, capability, constraints, out-of-scope hints.
2. Investigate codebase (analogous features, routes, permissions, tests).
3. Output: **Feature PRD** per prd-templates.md § Feature.
4. `validated` = scoped, feasible, not duplicate; `invalidated` = already exists, infeasible, or out of scope.

## Rules

- Do NOT call Paperclip API (skip triage Phase 4 entirely).
- French for PRD content.
- If invalidated: explain with code citations; do not write PRD body.
- PRD must be self-sufficient for **code-architect** — no open investigation left.

## Return

1. Markdown PRD (full, if validated) — parent writes to `fix-prd.md`
2. JSON block:

```json
{
  "verdict": "validated",
  "inputType": "bug|feature",
  "prdType": "fix|feature",
  "summary": {
    "title": "...",
    "severity": "Critique|Haute|Moyenne|Basse",
    "rootCauseOneLine": "... bug only, else null ...",
    "objectiveOneLine": "... feature one-liner ..."
  },
  "fixPrdMarkdown": "... full PRD markdown or null if invalidated ..."
}
```
```

---

## Architect

```
subagent_type: generalPurpose
readonly: true
description: Pipeline architect {slug}
```

```markdown
## Objective

Produce implementation plan for pipeline `{slug}` per **code-architect** workflow.

## Read first

- `{repoRoot}/.agents/skills/code-architect/SKILL.md`
- `{repoRoot}/.agents/skills/code-architect/plan-template.md`
- `{repoRoot}/.agents/skills/code-architect/checklist.md`

## Input

Type: {fix-prd | feature-brief}
Path: `{inputPath}`

## Rules

- Do NOT modify application source files.
- Do NOT call Paperclip API.
- Self-check checklist.md before return.
- French for plan content.

## Return

1. Full plan markdown (plan-template structure)
2. JSON:

```json
{
  "planMarkdown": "...",
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

Same as Architect, plus:

```markdown
## Escalation context

{escalation markdown from junior-dev}

## Task

Amend plan at `{planPath}` minimally. Return amended full plan + JSON with `"amendment": true` and `"sectionsChanged": ["§9 Tâche 3", "..."]`.
```

---

## Junior-dev

```
subagent_type: generalPurpose
readonly: false
description: Pipeline implement {slug}
```

```markdown
## Objective

Implement plan for pipeline `{slug}` per **junior-dev** skill.

## Read first

- `{repoRoot}/.agents/skills/junior-dev/SKILL.md`
- `{repoRoot}/.agents/skills/junior-dev/checklist.md`
- `{repoRoot}/.agents/skills/junior-dev/escalation-template.md`

## Plan path

`{repoRoot}/.planning/pipeline/{slug}/plan.md`

## Scope notes from user (if any)

{cp3-back-impl notes or empty}

## Rules

- Task-by-task per plan §9.
- On blocking ambiguity: STOP and return escalation — do not guess.
- Run `pnpm check` before return.
- Do NOT commit unless explicitly told.
- Code comments English; user-facing summary French.

## Return

If escalation:

```json
{
  "escalation": true,
  "escalationMarkdown": "... filled escalation-template ..."
}
```

If complete:

```json
{
  "escalation": false,
  "deliveryMarkdown": "... junior-dev Phase 4 template ...",
  "tasksCompleted": 8,
  "tasksTotal": 8,
  "checkOk": true,
  "filesTouched": ["src/...", "..."]
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

- `{repoRoot}/.cursor/skills/pr-review/pr-review-rubric.md` (if exists; else project conventions in CLAUDE.md / AGENTS.md)
- Plan: `{repoRoot}/.planning/pipeline/{slug}/plan.md`
- Delivery: `{repoRoot}/.planning/pipeline/{slug}/delivery.md`

## Diff scope

Base ref: `{baseRef}`

```bash
git diff {baseRef}...HEAD
```

Changed files: {list or "run git diff in repo"}

## Rules

- Read actual source at cited paths/lines before emitting findings.
- Cross-check plan §12 / delivery acceptance checklist.
- Flag scope creep vs plan §2.
- Return JSON per pr-review-rubric schema when available.
- Do NOT evaluate FR/AC spec conformance here — spec subagent handles that.

## Return

JSON only (parent merges with spec):

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

```markdown
## Objective

Spec conformance gate for pipeline `{slug}` — **always** runs parallel to code review.

## Read first

- `{repoRoot}/.cursor/skills/spec-check/gate-rubric.md` (output JSON schema)
- `{repoRoot}/.cursor/skills/spec-check/spec-baseline.md` (statuses, evidence rules)
- Spec baseline path: `{specBaselinePath}` (`fix-prd.md` preferred, else `plan.md`)
- Plan (implementation contract): `{repoRoot}/.planning/pipeline/{slug}/plan.md`
- Delivery: `{repoRoot}/.planning/pipeline/{slug}/delivery.md`

## Diff scope

Base ref: `{baseRef}` — evaluate implementation in changed files against spec baseline.

## Baseline precedence

1. **PRD** (`fix-prd.md`) — FR §4 + AC §7 (or Fix PRD §4/§7) are gate requirements.
2. **Plan** (`plan.md`) — use § acceptance criteria + §2 scope when PRD absent; when both exist, PRD wins for FR/AC; plan §12 supplements technical AC.
3. Never use plan amendments post-CP2 as scope expansion without user-approved CP2-bis.

## Workflow

1. Extract numbered FR-n / AC-n from baseline.
2. Map diff + full files to each requirement.
3. Assign status per spec-baseline (✅ ⚠️ ❌ ➖ ℹ️) with `path:Lx` evidence.
4. Emit scope creep (ℹ️) for changes not in PRD/plan scope.

## Rules

- No Paperclip/ClickUp fetch — local pipeline artifacts only.
- No handoff to paperclip-triage-issue — drifts are review findings for CP4 fix loop.
- Return **JSON only** per gate-rubric.md schema.
- Populate `specSummary.sources.pipeline` with baseline path used.

## Return

JSON per gate-rubric.md (`specSummary`, `findings`, `scopeCreep`, `conflicts`).
```

---

## Review merge (parent orchestrator)

After Review-code + Review-spec return:

1. Map spec findings → `dimension: spec`, same severity table as pr-review (❌ → critical, ⚠️ → warning, ℹ️ scope creep → note).
2. Dedupe code + spec on same `path:line`.
3. Write `review.md`:

```markdown
# Review — {slug}

## Spec conformance
**Baseline:** {fix-prd.md | plan.md}
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
