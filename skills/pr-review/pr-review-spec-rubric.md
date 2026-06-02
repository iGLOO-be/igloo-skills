# PR Review — Spec rubric (subagent)

Used by **explore** subagent when `context.specCheck === true`. Parent maps drifts to pr-review severities.

## Input

- `context.json` from `fetch-pr-review-context.sh`
- `diffPath` — PR diff
- Paperclip: run `scripts/fetch-paperclip-spec.sh --check-auth` then `scripts/fetch-paperclip-spec.sh <ID> --markdown` (default `--spec-source auto` → **fix-prd** > plan rev 1). Use **`specReference`** body only — never `plan` latest for gate. Optional `--include-architect-plan` for context.
- ClickUp: MCP `clickup_get_task` if URLs/IDs provided by orchestrator
- Rules: [spec-baseline.md](spec-baseline.md) (same skill directory)

## Output format (JSON only)

```json
{
  "specSummary": {
    "sources": { "clickup": "...", "paperclip": "IGLAA-91 (fix-prd|plan-rev-1)" },
    "verdict": "CONFORME|PARTIELLEMENT CONFORME|NON CONFORME",
    "counts": { "conforme": 0, "partiel": 0, "nonConforme": 0, "scopeCreep": 0 }
  },
  "conflicts": [],
  "findings": [
    {
      "requirementId": "AC-2",
      "severity": "critical|warning|note",
      "driftType": "Missing|Wrong|Partial",
      "path": "src/...",
      "line": 55,
      "title": "[AC-2] short title",
      "specExcerpt": "...",
      "implemented": "...",
      "problem": "...",
      "suggestedFix": "..."
    }
  ],
  "scopeCreep": [{ "description": "...", "path": "..." }]
}
```

## Severity mapping (orchestrator applies)

| Drift | severity |
|-------|----------|
| ❌ Non conforme | critical |
| ⚠️ Partiel | warning |
| ℹ️ Scope creep | note |

## Conflict protocol

If ClickUp vs Paperclip conflict: populate `conflicts` array with details. **Do not** emit findings on contested requirements — orchestrator STOPs and asks PO.

Never hand off to paperclip-triage-issue — fixes belong on the PR.
