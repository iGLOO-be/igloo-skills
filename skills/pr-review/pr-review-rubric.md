# PR Review — Code rubric (subagent)

Used by **code-reviewer** subagent in pr-review Step 1. Parent merges output with spec findings.

## Input from orchestrator

- `context.json` from `fetch-pr-review-context.sh` (metadata + reviewState)
- `diffPath` — read diff; for each changed file, read full file on PR head if needed (`Read` locally or `gh api contents`)
- `reviewState.inlineComments` + `threads` — cross-reference rules below

## Dimensions

| Dimension | Check |
|-----------|-------|
| **correctness** | Logic errors, null/undefined, races, missing error handling, edge cases |
| **security** | Injection, XSS, auth bypass, secrets, missing validation |
| **performance** | N+1, unbounded loops, missing indexes, re-renders, bundle bloat |
| **types** | Unsafe casts, missing guards, `any`, schema/type mismatches |
| **conventions** | Project patterns per `CLAUDE.md` / `AGENTS.md` (auth scope, ORM, forms, i18n, offline/PWA as applicable) |

Skip linter-only nits unless they indicate a real defect.

## Output format (JSON only)

Return **only** this JSON (no prose):

```json
{
  "findings": [
    {
      "severity": "critical|warning|note",
      "dimension": "correctness|security|performance|types|conventions",
      "confidence": "high|medium|low",
      "path": "src/...",
      "line": 42,
      "title": "short title",
      "problem": "description",
      "suggestedFix": "code or steps",
      "status": "new|still_open|updated",
      "existingCommentId": null
    }
  ],
  "resolved": [
    { "path": "...", "line": 10, "title": "...", "existingCommentId": 123 }
  ],
  "positives": ["what looks good"]
}
```

## Cross-reference existing comments

| Situation | Action |
|-----------|--------|
| Matches **resolved** thread | Omit from findings |
| Matches **open** comment, issue persists | `status: still_open`, set `existingCommentId` |
| Matches **open** comment, fixed | Add to `resolved` |
| New issue | `status: new` |
| Open comment, no matching issue | Add to `resolved` |

Only **high** and **medium** confidence in `findings` (low → omit).

## Scope guard

If `scopeGuard: true` in context, analyze only paths the orchestrator passed in the prompt.
