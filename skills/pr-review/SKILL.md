---
name: pr-review
description: >-
  Orchestrates GitHub PR review: bundles PR context, delegates code analysis,
  optionally delegates spec gate to verify-spec when installed, validates and posts
  findings. Use for "review PR", "pr review", or a PR URL/number. Spec gaps block
  merge when verify-spec is present — never paperclip-triage-issue.
disable-model-invocation: true
---

# PR Review (orchestrator)

Thin orchestrator — **no inline diff loading in parent**. Code review via subagent; spec via **verify-spec gate mode** when installed; posting in parent.

Communicate in French. Code/commits in English. After code edits: run the project's documented pre-commit check.

## Skill root (portable)

Directory containing this `SKILL.md` — when installed via `npx skills add`, typically **`.agents/skills/pr-review/`**.

Run scripts **from the skill root**:

```bash
bash scripts/fetch-pr-review-context.sh [--out-dir DIR] [PR_NUMBER|URL]
```

Or from the project root:

```bash
bash .agents/skills/pr-review/scripts/fetch-pr-review-context.sh [--out-dir DIR] [PR_NUMBER|URL]
```

## Detect verify-spec (optional, runtime)

Before spec delegation, check if verify-spec is installed (first match wins):

1. `.agents/skills/verify-spec/SKILL.md`
2. `.cursor/skills/verify-spec/SKILL.md`

No verify-spec → **code review only** when `specCheck` is true; warn explicitly in Step 3 recap.

## Step 0 — Context bundle

Parse stdout JSON. Keep `diffPath`, `outDir/context.json`, `reviewState`, `specCheck`, `paperclipIds`, `clickupUrls`.

If `scopeGuard: true` (>30 files) → ask user which directories to focus **before** Step 1. Pass focus paths to subagents.

If user provided extra ClickUp/Paperclip refs not in JSON → set `specCheck: true` and append IDs.

## Step 1 — Delegate analysis (parallel when spec + verify-spec available)

### A — Code review (always)

```
Task(subagent_type="code-reviewer", prompt="""
Read {skillRoot}/pr-review-rubric.md.
Read {outDir}/context.json and diff at {diffPath}.
Analyze changed files per rubric. Cross-reference reviewState.
Return ONLY the JSON schema from the rubric (findings, resolved, positives).
Focus paths: {focusDirs or "all changedFiles"}
""")
```

`{skillRoot}` = directory containing this skill's SKILL.md.

### B — Spec gate (if specCheck AND verify-spec installed)

Launch in parallel with A.

```
Task(subagent_type="explore", prompt="""
Read {verifySpecRoot}/SKILL.md — Gate mode section.
Read {verifySpecRoot}/gate-rubric.md and {verifySpecRoot}/spec-baseline.md.
Read {outDir}/context.json and diff at {diffPath}.
Paperclip IDs: {paperclipIds} — use {verifySpecRoot}/scripts/fetch-paperclip-spec.sh (mandatory).
ClickUp: {clickupUrls or user IDs} — MCP clickup_get_task.
Return ONLY the JSON schema from gate-rubric.md. No audit report.
""")
```

`{verifySpecRoot}` = verify-spec skill directory from detection above.

### B′ — Spec skipped (if specCheck AND verify-spec NOT installed)

Do not launch spec subagent. In Step 3 recap, include:

> ⚠️ Spec refs detected (Paperclip/ClickUp) but **verify-spec** is not installed — **code review only**. Install verify-spec for automatic spec gate.

## Step 2 — Merge (parent)

1. Parse code JSON; parse spec JSON if Step 1B ran.
2. If spec `conflicts` non-empty → **STOP**, ask PO which source wins.
3. Map spec findings to same shape as code findings (`dimension: spec`).
4. Cross-reference `reviewState` → assign `TO_CREATE` / `TO_UPDATE` / `TO_RESOLVE`.
5. Drop low-confidence code findings. Dedupe spec + code on same line.

## Step 3 — Present & validate

Present recap (structure below). **STOP** — user validates / invalidates / edits.

```markdown
## Code Review — PR #N: TITLE
**Scope**: N files | **Prior agent comments**: M open, K resolved
### Spec conformance (if specCheck + verify-spec)
**Verdict**: … | sources …
### ⚠️ Spec skipped (if specCheck without verify-spec)
### 🔴 Critical / 🟡 Warning / 🟢 Note
#### 1. path:line — title [NEW|STILL OPEN|UPDATED]
**Dimension**: … | **Confidence**: …
### ✅ Resolved since last review
### ✅ What looks good
```

Severity: Critical = bug/security/data loss OR spec ❌; Warning = should fix OR spec ⚠️; Note = nice-to-have OR scope creep.

## Step 4 — Post (after user approval)

Follow [pr-review-post.md](pr-review-post.md). Report: comments created/updated/resolved, `paperclip:approve` label state (when used), PR link.

## Rules

- **No GitHub posts** before Step 3 approval.
- Never hallucinate line numbers — subagents read real files.
- Spec drifts → fix on PR, **never** paperclip-triage-issue / Paperclip issues.
- pr-review does **not** own spec baseline or Paperclip fetch — that lives in **verify-spec**.
- Idempotent: always start from Step 0 script (fresh reviewState).
- Full spec audit report → **verify-spec** audit mode (separate invocation).

## Resources

| File | Role |
|------|------|
| [scripts/fetch-pr-review-context.sh](scripts/fetch-pr-review-context.sh) | PR + diff + review state bundle |
| [pr-review-rubric.md](pr-review-rubric.md) | code-reviewer subagent |
| [pr-review-post.md](pr-review-post.md) | GitHub posting |
| **verify-spec** skill | Spec baseline, gate mode, audit mode |
