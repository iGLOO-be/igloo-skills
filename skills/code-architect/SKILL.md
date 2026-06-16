---
name: code-architect
description: >-
  Produces a codebase-grounded implementation plan from a Fix PRD, feature brief,
  or free-text description — ready for a junior developer to execute without
  further investigation. Use when the user asks for a technical plan, architecture
  blueprint, implementation spec, or when downstream of paperclip-triage-issue
  (Fix PRD). Does not implement code; does not call Paperclip API.
---

# Code Architect

Transform product intent into an **implementation plan** anchored in the actual codebase. The output must be executable by a junior developer using only the plan + repo access.

## Skill root

**`skills/code-architect/`** in this repo; install to `.agents/skills/code-architect/` in target projects.

## Related skills

| Situation | Skill |
|-----------|-------|
| Bug report to validate → Fix PRD | **paperclip-triage-issue** |
| Execute architect plan in repo | **junior-dev** |
| Merge gate on open PR | **pr-review** |
| Post-merge spec audit | **spec-check** |
| Milestone phase planning (GSD) | **gsd-plan-phase** |

**Boundary:** triage writes **Fix PRD** (what/why). This skill writes **plan** (how, in this repo). Never re-open a validated root cause from a Fix PRD.

## Inputs

Accept one of:

1. **Fix PRD** — full document from triage (sections 1–8). Treat sections 1–5 and 7 as frozen spec; extend section 6 into a full implementation blueprint.
2. **Feature brief** — actor, capability, constraints, acceptance hints (structured or prose).
3. **Free description** — symptom, user story, or "we need X". Requires lightweight discovery before planning.

If input is ambiguous, ask **one** focused question (max one round).

## Workflow

### Phase 1 — Classify and lock scope

1. Identify input type (Fix PRD / feature / description).
2. Extract: actors, expected outcome, constraints, out-of-scope.
3. For Fix PRD: copy acceptance criteria (section 7) verbatim into the plan — do not weaken them.
4. For description-only: state assumptions explicitly in the plan under **Hypothèses**.

### Phase 2 — Codebase reconnaissance

Investigate before writing the plan. Minimum:

1. Read project conventions: `CLAUDE.md`, `AGENTS.md` (workspace facts).
2. Locate analogous features (SemanticSearch + Grep + Read).
3. Map touchpoints: routes, tRPC routers, validators, components, tests, i18n keys, Prisma models/migrations.
4. Record **evidence**: file paths with line ranges, existing patterns to reuse.

**Rules:**

- Cite real paths from the repo — never invent modules.
- Prefer extending existing abstractions over new ones.
- Flag multi-tenant (`instanceScopedProcedure`), offline/Dexie, permissions, soft-delete rules when relevant.
- If a requirement conflicts with repo constraints, stop and surface the conflict — do not silently bend the spec.

### Phase 3 — Design decisions

Resolve implementation choices the PRD leaves open:

- Data model changes (fields, relations, migration need)
- API surface (procedure name, input schema, permission)
- UI surface (route, component tree, form pattern)
- Error/edge-case handling
- Test strategy (unit colocated `__tests__`, E2E only if user-facing flow)

Document each decision as **Decision / Rationale / Alternative rejected** (one line each).

### Phase 4 — Write the plan

Use the template in [plan-template.md](plan-template.md). Output language: **French** (matching triage and team docs).

Quality bar — a junior dev must be able to:

- Know **which files** to create or edit, in **what order**
- Copy **patterns** from cited reference files
- Verify completion against **checklist** without guessing

### Phase 5 — Self-check (mandatory)

Before presenting, verify every item in [checklist.md](checklist.md). Fix gaps; do not ship a plan with TBD on critical paths.

### Phase 6 — Deliver

1. Present the full plan markdown to the user.
2. Summarize: scope, file count, migration yes/no, estimated task count, risks.
3. **STOP.** Do not implement, commit, or open PRs unless the user explicitly asks.

## Output rules

- **Do not** modify application source in architect mode.
- **Do not** call Paperclip API (local document only).
- **Do not** overwrite or rewrite a Fix PRD — reference it; the plan is a separate artifact.
- Every task references at least one real file path.
- Tasks ordered by dependency (schema → server → client → tests → i18n).
- Acceptance criteria remain binary pass/fail.
- Prefer over-specifying file-level steps to under-specifying.

## Task granularity

Each implementation task should be completable in **one focused PR slice** (roughly 1–4 hours junior time):

- ✅ "Add `cancelReasonId` to bulletin requalify input schema in `src/lib/validators/bulletin.ts`"
- ❌ "Fix bulletin flow"

Include for each task: **Goal**, **Files**, **Steps**, **Verify** (command or assertion).

## When to escalate

Stop planning and ask the user if:

- Scope requires a product decision not inferable from input
- Two valid architectures with very different cost (e.g. new table vs JSON column)
- Security/compliance impact unclear (PII, permissions escalation)
- Fix PRD acceptance criteria contradict current architecture

## Additional resources

- Plan structure: [plan-template.md](plan-template.md)
- Quality gate: [checklist.md](checklist.md)
- Example (fix): [examples/fix-plan-excerpt.md](examples/fix-plan-excerpt.md)
