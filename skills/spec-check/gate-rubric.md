# Verify Spec — Gate mode rubric (subagent)

Used when **pr-review** delegates spec conformance on an open PR. The explore subagent runs spec-check Phases 1–3 in gate mode and returns JSON only — no audit report, no user-facing STOP.

## Input

- `context.json` from pr-review `fetch-pr-review-context.sh`
- `diffPath` — PR diff (scope = changed files only)
- Paperclip: run `scripts/fetch-paperclip-spec.sh --check-auth` then `scripts/fetch-paperclip-spec.sh <ID> --markdown` (default `--spec-source auto` → **fix-prd** > plan rev 1). Use **`specReference`** body only — never `plan` latest for gate.
- ClickUp: MCP `clickup_get_task` if URLs/IDs provided by orchestrator
- Rules: [spec-baseline.md](spec-baseline.md)

## Output format (JSON only)

Return **only** this JSON (no prose):

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

## Severity mapping (pr-review parent applies)

| Drift | severity |
|-------|----------|
| ❌ Non conforme | critical |
| ⚠️ Partiel | warning |
| ℹ️ Scope creep | note |

## Conflict protocol

If ClickUp vs Paperclip conflict: populate `conflicts` array with details. **Do not** emit findings on contested requirements — pr-review STOPs and asks PO.

Never hand off to paperclip-triage-issue — fixes belong on the PR.
