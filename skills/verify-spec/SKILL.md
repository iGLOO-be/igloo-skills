---
name: verify-spec
description: >-
  Spec conformance owner: ClickUp/Paperclip baseline, gate-mode JSON for pr-review,
  and full product audit (matrix, drift analysis). Gate mode runs when pr-review
  detects spec refs; audit mode for post-merge or standalone reports. Routes fixes
  through paperclip-triage-issue only post-merge. Use for "audit spec", "verify spec",
  "drift analysis", or when invoked by pr-review for spec gate.
---

# Verify Spec

**Owner of all spec logic** — baseline, Paperclip fetch, conformance matrix, gate output for merge, and full audit reports.

Communicate with the user in French. Code citations and commit messages stay in English.

## Skill root (portable)

Directory containing this `SKILL.md` — when installed via `npx skills add`, typically **`.agents/skills/verify-spec/`**. Also discoverable at `.cursor/skills/verify-spec/` in projects that vendor skills locally.

| File | Role |
|------|------|
| [spec-baseline.md](spec-baseline.md) | Spec resolution, precedence, statuses, audit template |
| [gate-rubric.md](gate-rubric.md) | JSON output schema for pr-review gate |
| [scripts/fetch-paperclip-spec.sh](scripts/fetch-paperclip-spec.sh) | Paperclip spec fetch |
| [examples.md](examples.md) | Usage examples |

## When to use which skill

| Situation | Skill |
|-----------|-------|
| PR ouverte, gate merge (code + spec) | **pr-review** (delegates spec to verify-spec gate mode when installed) |
| Rapport produit complet, audit post-merge | **verify-spec** audit mode |
| Bug signalé / symptôme à valider | **paperclip-triage-issue** |
| Drift spec sur PR ouverte | **pr-review** — jamais triage |
| Drift confirmé, déjà mergé ou fix hors PR | **verify-spec** → **paperclip-triage-issue** (si user confirme) |

## Gate mode (pr-review delegation)

**Trigger:** pr-review Step 1B when `specCheck === true` and this skill is installed.

**Do not** produce the audit report template. **Do not** STOP for user in gate mode — return JSON to the pr-review parent only.

1. **Phase 1 — Load spec baseline** — [spec-baseline.md](spec-baseline.md); run `scripts/fetch-paperclip-spec.sh` for Paperclip IDs (mandatory).
2. **Phase 2 — Load implementation** — PR diff from `context.json` / `diffPath` only; read full files where needed.
3. **Phase 3 — Conformance** — evaluate FR/AC per spec-baseline; output **only** JSON per [gate-rubric.md](gate-rubric.md).

If `conflicts` non-empty → pr-review parent STOPs and asks PO.

## Audit mode (standalone)

**Trigger:** user invokes `@verify-spec` directly, or post-merge / branch / main scope.

At least **one spec source** and **one implementation scope**:

| Implementation scope | How to resolve |
|---------------------|----------------|
| Open PR | Prefer **pr-review** for merge gate; proceed audit-only if user insists |
| Branch | Current branch or named ref vs `main` diff |
| Merged / main | `git diff main...ref` or inspect production paths on `main` |

If the user provides an **open PR** without audit-only intent, suggest **pr-review**:

> Pour une PR ouverte avec gate merge (code + spec + commentaires GitHub), utilisez **pr-review**. **verify-spec** audit mode sert au rapport complet ou post-merge.

### Phase 1 — Load spec baseline

Read [spec-baseline.md](spec-baseline.md). Run `scripts/fetch-paperclip-spec.sh` for Paperclip (mandatory — no « API indisponible » without running it).

### Phase 2 — Load implementation

1. Determine scope (PR diff, branch diff, or main).
2. Read full files for context — not just hunks.
3. Map changed/inspected files to requirements.
4. Check colocated tests and E2E specs where the project has them.

**Scope guard**: >30 files → ask user which directories to focus on.

### Phase 3 — Conformance matrix

For each FR/AC, assign status per spec-baseline (✅ ⚠️ ❌ ➖ ℹ️) with evidence.

### Phase 4 — Report

Present using the **Full audit report template** in spec-baseline.md. Compute verdict (CONFORME / PARTIELLEMENT CONFORME / NON CONFORME).

**STOP.** Ask how to proceed:

| Verdict | Default next step |
|---------|-------------------|
| CONFORME | Done |
| Drifts + **open PR** | User should fix on PR → suggest **pr-review** |
| Drifts + **merged / fix hors PR** | Offer triage handoff (Phase 5) |

### Phase 5 — Handoff to paperclip-triage-issue (restricted)

Execute **only when all** are true:

1. User explicitly confirms triage (not auto).
2. Implementation is **already merged**, or fix **cannot** land on the current PR/branch.
3. At least one ❌ or ⚠️ drift needs a structured Fix PRD.

**Never** run Phase 5 for drifts fixable on an open PR — redirect to pr-review.

1. Read the project's installed **paperclip-triage-issue** skill (typically `.agents/skills/paperclip-triage-issue/SKILL.md`).
2. Group drifts by root cause.
3. For each group, formulate claim (see [examples.md](examples.md)).
4. Run triage Phase 2–3 (investigate + Fix PRD). Gap is pre-validated — produce Fix PRD, do not re-debate existence.
5. Present Fix PRD(s). **STOP for approval** before Paperclip (triage Phase 4).
6. On approval, triage Phase 4 (issue + fix-prd + assign architect).

## Rules

- Original spec (ClickUp/Paperclip) is source of truth — not PR description alone.
- No ✅ without code evidence.
- No Paperclip issues without user approval (via triage Phase 4).
- No triage handoff from open-PR drifts.
- Resolve Paperclip company/project via paperclip-triage-issue Phase 4.0 — never default to first company.
- Gate mode: JSON only, no audit report, no Paperclip issue creation.

## Additional resources

- Examples: [examples.md](examples.md)
- Merge orchestrator: **pr-review** skill
