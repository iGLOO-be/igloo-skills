---
name: pr-review
description: >-
  Orchestrates GitHub PR review: script bundles context, subagents analyze code
  and optional spec (ClickUp/Paperclip), parent validates and posts findings.
  Use for "review PR", "pr review", or a PR URL/number. Spec gaps block merge —
  never paperclip-triage-issue.
disable-model-invocation: true
---

# PR Review (orchestrator)

Thin orchestrator — **no inline diff loading in parent**. I/O via script; analysis via subagents; gates + posting in parent.

Communicate in French. Code/commits in English. After code edits: run the project's documented pre-commit check.

## Skill root (portable)

Directory containing this `SKILL.md` — when installed via `npx skills add`, typically **`.agents/skills/pr-review/`** in the consuming project. All sibling files (`pr-review-rubric.md`, `spec-baseline.md`, `scripts/`) live in that same directory.

Run scripts **from the skill root**:

```bash
bash scripts/fetch-pr-review-context.sh [--out-dir DIR] [PR_NUMBER|URL]
```

Or from the project root:

```bash
bash .agents/skills/pr-review/scripts/fetch-pr-review-context.sh [--out-dir DIR] [PR_NUMBER|URL]
```

## Step 0 — Context bundle

Parse stdout JSON. Keep `diffPath`, `outDir/context.json`, `reviewState`, `specCheck`, `paperclipIds`, `clickupUrls`.

If `scopeGuard: true` (>30 files) → ask user which directories to focus **before** Step 1. Pass focus paths to subagents.

If user provided extra ClickUp/Paperclip refs not in JSON → set `specCheck: true` and append IDs.

## Step 1 — Delegate analysis (parallel)

Launch **both in one message** when `specCheck`; else code only.

### A — Code review

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

### B — Spec conformance (if specCheck)

```
Task(subagent_type="explore", prompt="""
Read {skillRoot}/pr-review-spec-rubric.md and {skillRoot}/spec-baseline.md.
Read {outDir}/context.json and diff at {diffPath}.
Paperclip IDs: {paperclipIds} — use fetch-paperclip-spec.sh (mandatory).
ClickUp: {clickupUrls or user IDs} — MCP clickup_get_task.
Return ONLY the JSON schema from pr-review-spec-rubric.md.
""")
```

Subagents must **not** post to GitHub or talk to the user.

## Step 2 — Merge (parent)

1. Parse both JSON outputs (tolerate missing spec if specCheck false).
2. If spec `conflicts` non-empty → **STOP**, ask PO which source wins.
3. Map spec findings to same shape as code findings (`dimension: spec`).
4. Cross-reference `reviewState` → assign `TO_CREATE` / `TO_UPDATE` / `TO_RESOLVE`.
5. Drop low-confidence code findings. Dedupe spec + code on same line.

## Step 3 — Present & validate

Present recap (structure below). **STOP** — user validates / invalidates / edits.

```markdown
## Code Review — PR #N: TITLE
**Scope**: N files | **Prior agent comments**: M open, K resolved
### Spec conformance (if specCheck)
**Verdict**: … | sources …
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
- Idempotent: always start from Step 0 script (fresh reviewState).
- Full spec audit report → **verify-spec** skill (optional, separate).

## Resources

| File | Role |
|------|------|
| [scripts/fetch-pr-review-context.sh](scripts/fetch-pr-review-context.sh) | PR + diff + review state bundle |
| [scripts/fetch-paperclip-spec.sh](scripts/fetch-paperclip-spec.sh) | Paperclip issue + spec |
| [pr-review-rubric.md](pr-review-rubric.md) | code-reviewer subagent |
| [pr-review-spec-rubric.md](pr-review-spec-rubric.md) | explore subagent (spec) |
| [spec-baseline.md](spec-baseline.md) | Spec precedence & conflicts |
| [pr-review-post.md](pr-review-post.md) | GitHub posting |
| **verify-spec** skill | Post-merge product audit |
