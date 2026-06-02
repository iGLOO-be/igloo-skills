# Spec Baseline

Owned by **verify-spec** — single source of truth for spec resolution, conformance, and audit reporting. **pr-review** delegates spec checks here when installed; it does not duplicate this file.

Communicate with the user in French when presenting results.

## Inputs

| Source | Resolution |
|--------|------------|
| ClickUp task | ID, custom ID, or URL → MCP `clickup_get_task` with `detail_level: "detailed"` |
| Paperclip issue | Identifier → `fetch-paperclip-spec.sh` (default `--spec-source auto`) |

## Paperclip spec reference (mandatory bootstrap)

**Never** report « API indisponible » without running the script.

From the **verify-spec skill root** (typically `.agents/skills/verify-spec/`):

```bash
bash scripts/fetch-paperclip-spec.sh --check-auth
bash scripts/fetch-paperclip-spec.sh <ISSUE-ID> --markdown
```

Default `--spec-source auto` resolves **spec reference** in order:

1. Document **`fix-prd`** — Fix PRD from paperclip-triage-issue (immutable convention)
2. **`plan` revision 1** — oldest revision (legacy issues before fix-prd)
3. **Issue description** — fallback only

**Never use `plan` latest for spec conformance gate** — that is the architect's working doc (often rev 2+).

| Flag | Use |
|------|-----|
| `--spec-source auto` | Default — gate spec |
| `--spec-source fix-prd` | Force fix-prd only |
| `--spec-source plan-rev-1` | Legacy triage-on-plan issues |
| `--spec-source plan-latest` | Implementation context only — **not** gate |
| `--include-architect-plan` | Also output latest plan body (informational) |

Exit codes: `0` OK | `1` auth | `2` not found | `3` API | `4` usage

## Source precedence (conflicts)

When multiple sources disagree, report conflicts — never silently merge:

1. Paperclip **`specReference`** from script (fix-prd → plan rev 1 → description)
2. ClickUp task description + checklist
3. Paperclip issue description (if not already used as specReference)
4. Architect **`plan` latest** — informational only, never overrides 1–2 for gate

## Auto-detect spec refs (PR context)

Scan PR `title` and `body` for Paperclip IDs (e.g. `IGLAA-91`, `FOL-42`), ClickUp URLs, and project custom IDs when known.

If none found and user did not provide sources → skip spec check.

## Extract baseline

Number testable **FR-n**, **AC-n**, constraints, out-of-scope. If too vague → STOP, one question.

Checklist:

```
- [ ] fetch-paperclip-spec.sh run (note specReference.type in report)
- [ ] ClickUp loaded (if applicable)
- [ ] FR-n / AC-n numbered
```

## Conformance statuses

| Status | Meaning |
|--------|---------|
| ✅ Conforme | Matches spec intent |
| ⚠️ Partiel | Incomplete / edge cases |
| ❌ Non conforme | Missing or wrong |
| ➖ Hors scope | Spec requires but no implementation touchpoint |
| ℹ️ Scope creep | Not in spec |

Evidence required for non-✅: `path:Lstart-Lend`. No guessing.

## Spec conflict protocol

ClickUp vs Paperclip specReference conflict → STOP, ask PO.

## Map drifts → pr-review severity (gate mode)

| Drift | Severity | Dimension |
|-------|----------|-----------|
| ❌ | 🔴 Critical | spec |
| ⚠️ | 🟡 Warning | spec |
| ℹ️ | 🟢 Note | spec |

## Project defaults

Resolve Paperclip company/project from `AGENTS.md` workspace facts, ClickUp folder/space names, git remote, or Paperclip API — see **paperclip-triage-issue** Phase 4.0. Triage writes **`fix-prd`**; architect owns **`plan`**.

## Full audit report template

Use for **verify-spec audit mode** Phase 4:

```markdown
# Rapport de conformité — [Feature title]

## Sources
- ClickUp: [link or ID]
- Paperclip: [identifier + board URL]
- Implémentation: [branch / main @ sha / PR #N]

## Synthèse
**Verdict : CONFORME | PARTIELLEMENT CONFORME | NON CONFORME**

| ID | Exigence | Statut | Evidence |
|----|----------|--------|----------|
| FR-1 | … | ✅ | `path:Lstart-Lend` |
```
