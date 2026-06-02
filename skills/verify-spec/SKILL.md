---
name: verify-spec
description: >-
  Standalone product audit: compares implementation (PR, branch, or main) against
  the original ClickUp task and/or Paperclip issue spec. Produces a full conformance
  matrix and drift analysis. Routes fixes through paperclip-triage-issue only for post-merge
  or out-of-PR corrections — not for open PRs (use pr-review instead).
  Use when the user says "audit spec", "verify spec", "drift analysis",
  "did we ship what was promised", or post-merge conformance checks.
---

# Verify Spec

**Product audit** — not the merge gate. For open PRs with spec refs, use **pr-review** instead; it posts findings to GitHub and blocks merge. Use verify-spec when you need the full report, post-merge validation, or fixes outside the PR branch.

Communicate with the user in French. Code citations and commit messages stay in English.

## Skill root (portable)

Directory containing this `SKILL.md` — when installed via `npx skills add`, typically **`.agents/skills/verify-spec/`**. Shared spec logic lives in the **pr-review** skill: `.agents/skills/pr-review/spec-baseline.md` and `.agents/skills/pr-review/scripts/fetch-paperclip-spec.sh`.

## When to use which skill

| Situation | Skill |
|-----------|-------|
| PR ouverte, gate merge (code + spec) | **pr-review** |
| Rapport produit complet, audit post-merge | **verify-spec** |
| Bug signalé / symptôme à valider | **paperclip-triage-issue** |
| Drift spec sur PR ouverte | **pr-review** — jamais triage |
| Drift confirmé, déjà mergé ou fix hors PR | **verify-spec** → **paperclip-triage-issue** (si user confirme) |

## Inputs

At least **one spec source** and **one implementation scope**:

| Implementation scope | How to resolve |
|---------------------|----------------|
| Open PR | Number/URL — prefer **pr-review** instead unless user explicitly wants audit-only |
| Branch | Current branch or named ref vs `main` diff |
| Merged / main | `git diff main...ref` or inspect production paths on `main` |

| Spec source | See pr-review [spec-baseline.md](../pr-review/spec-baseline.md) when both skills are installed |

If the user provides an **open PR** without asking for audit-only, **redirect** to pr-review:

> Pour une PR ouverte, utilisez **pr-review** — il vérifie la spec et poste les findings sur GitHub. **verify-spec** sert à l'audit produit (post-merge ou rapport complet).

Proceed with verify-spec only if the user insists on audit-only or scope is not an open PR gate.

## Workflow

### Phase 1 — Load spec baseline

Read pr-review [spec-baseline.md](../pr-review/spec-baseline.md). For Paperclip identifiers, run `fetch-paperclip-spec.sh` from the pr-review skill scripts directory (mandatory — no « API indisponible » without running it).

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
3. For each group, formulate claim:

   ```markdown
   ## Claim (from verify-spec — post-merge)

   **Symptom** : [user-observable gap vs spec]
   **Where** : [route, component, procedure]
   **When** : [conditions]
   **Spec reference** : [FR-/AC- ID + excerpt]
   **Evidence** : [`path:Lstart-Lend` — actual vs expected]
   **Context** : [merged in PR #N / on main since DATE / fix outside original branch]
   ```

4. Run triage Phase 2–3 (investigate + Fix PRD). Gap is pre-validated — produce Fix PRD, do not re-debate existence.
5. Present Fix PRD(s). **STOP for approval** before Paperclip (triage Phase 4).
6. On approval, triage Phase 4 (issue + fix-prd + assign architect).

## Rules

- Original spec (ClickUp/Paperclip) is source of truth — not PR description alone.
- No ✅ without code evidence.
- No Paperclip issues without user approval (via triage Phase 4).
- No triage handoff from open-PR drifts.
- Resolve Paperclip company/project via paperclip-triage-issue Phase 4.0 — never default to first company.

## Additional resources

- Shared spec logic: pr-review [spec-baseline.md](../pr-review/spec-baseline.md)
- Paperclip fetch script: pr-review [scripts/fetch-paperclip-spec.sh](../pr-review/scripts/fetch-paperclip-spec.sh)
- Examples: [examples.md](examples.md)
- Merge gate: **pr-review** skill
