---
name: paperclip-triage-issue
description: >-
  Investigate a reported issue or bug claim against the codebase to validate or
  invalidate it. If validated, produce a PRD-level fix specification and, when
  Paperclip is configured, send it to the architect agent — resolving the correct
  company and project first (never default to the first Paperclip company). If
  invalidated, stop immediately. Also receives post-merge drift handoffs from
  spec-check (never from pr-review). Use when the user says "triage this issue",
  "investigate this bug", "validate this report", or provides a bug claim to verify.
---

# Paperclip Triage Issue

Analyze a claim, investigate the source, validate or invalidate, and produce an implementation-ready PRD for the architect agent.

## Related: pr-review & spec-check

| Situation | Skill |
|-----------|-------|
| PR ouverte — code + spec, gate merge | **pr-review** (délègue spec à **spec-check** gate mode si installé) |
| Audit produit / post-merge / rapport complet | **spec-check** |
| Bug report / symptôme à valider | **paperclip-triage-issue** |
| Drift spec sur PR ouverte | **pr-review** — fix sur la PR, **jamais triage** |
| Drift confirmé post-merge, fix hors PR | **spec-check** → **paperclip-triage-issue** (si user confirme) |

**pr-review** never creates Paperclip issues or hands off to triage for spec gaps — drifts become inline PR findings and `REQUEST_CHANGES`.

When **spec-check** routes here (Phase 5, post-merge only), the gap is **pre-validated**. Run triage Phase 2–3 for root cause + Fix PRD; do not re-debate whether the drift exists. Claim format: see the project's **spec-check** skill `examples.md` when that skill is installed locally.

## Workflow

### Phase 1 — Understand the claim

1. Parse the user's request to extract:
   - **What** is reported (symptom, error, unexpected behavior)
   - **Where** it allegedly occurs (route, component, function, flow)
   - **When** / under what conditions

2. If the claim is ambiguous, ask one focused clarification question (max one round).

### Phase 2 — Investigate the source

1. Locate the relevant code paths using search tools (Grep, SemanticSearch, Read).
2. Trace the execution flow that the claim describes.
3. Determine whether the reported behavior is actually possible given the current code.
4. Collect evidence: file paths, line numbers, logic that confirms or contradicts.
5. Identify all related code touchpoints (callers, consumers, tests, validators, types).

### Phase 3 — Verdict

Reach one of two conclusions:

#### INVALIDATED

If the code does NOT support the claim (the bug cannot occur, the behavior is already handled, or the premise is wrong):

1. Explain briefly why the claim is unfounded (cite the relevant code).
2. **STOP. Do nothing further.**

#### VALIDATED

If the code DOES confirm the issue, produce a **Fix PRD** — a self-contained specification document that leaves no room for interpretation. The architect agent must be able to implement the fix using ONLY this document, without needing additional context or investigation.

Produce the PRD with **exactly** this structure:

```markdown
# Fix PRD — [Titre court et descriptif]

## 1. Énoncé du problème

### Symptôme utilisateur
[Description du comportement observé tel qu'un utilisateur final le subirait. 2-3 phrases concrètes.]

### Cause racine
[Explication technique précise de pourquoi le bug se produit. Inclure le mécanisme exact de la défaillance, pas juste sa localisation.]

### Étapes de reproduction
1. [Étape concrète]
2. [Étape concrète]
3. [Résultat observé vs résultat attendu]

## 2. Impact

| Dimension | Évaluation |
|-----------|------------|
| Utilisateurs affectés | [Rôle(s) — ex: tous les recruteurs, admins d'une instance spécifique] |
| Sévérité | [Critique / Haute / Moyenne / Basse] |
| Fréquence | [Systématique / Conditions spécifiques / Rare] |
| Contournement possible | [Oui (décrire) / Non] |

## 3. Comportement attendu

[Description précise et non ambiguë du comportement correct après fix. Formulé en termes de résultat observable, pas d'implémentation.]

## 4. Exigences fonctionnelles

Chaque FR est testable et implémentation-agnostique :

- FR1: [Acteur] peut [capacité corrigée] [contexte]
- FR2: [Acteur] peut [capacité corrigée] [contexte]
- ...

## 5. Contraintes et effets de bord

### Ne pas casser
- [Fonctionnalité existante qui doit continuer à fonctionner — être spécifique]
- [Autre fonctionnalité adjacente]

### Limites du scope
- [Ce qui n'est PAS dans le scope de ce fix]
- [Problème connexe qui nécessite un ticket séparé, le cas échéant]

### Contraintes techniques
- [Contrainte d'architecture pertinente — ex: multi-tenant isolation, offline-first, permissions]
- [Dépendance ou pattern existant à respecter]

## 6. Spécification technique du fix

### Fichiers à modifier

| Fichier | Modification | Justification |
|---------|-------------|---------------|
| `path/to/file.ts:L42` | [Description précise du changement] | [Pourquoi ce changement résout le problème] |
| `path/to/other.ts:L15-20` | [Description précise] | [Justification] |

### Logique de correction

[Pseudo-code ou description algorithmique du fix. Assez détaillé pour qu'un développeur n'ait pas besoin de réfléchir à la logique, seulement à la syntaxe.]

### Migrations / données (si applicable)

[Modifications de schéma, migrations de données, ou changements de seed nécessaires. "Aucune" si non applicable.]

## 7. Critères d'acceptation

Conditions vérifiables que le fix doit satisfaire pour être considéré complet :

- [ ] [Critère testable 1 — formulé comme assertion]
- [ ] [Critère testable 2]
- [ ] [Régression : vérifier que X continue de fonctionner]
- [ ] [Edge case : vérifier le comportement quand Y]

## 8. Références

| Fichier | Lignes | Rôle dans le problème |
|---------|--------|----------------------|
| `path/file.ts` | L12-45 | [Explication de la pertinence] |
| `path/other.ts` | L78 | [Explication] |
```

**STOP. Present the PRD to the user and ask for explicit confirmation before proceeding.**

### Phase 4 — Send to Paperclip (conditional, only after user confirmation)

Execute Phase 4 **only if** the **`paperclip-operator`** skill is available — installed from igloo-skills (project or global) or at `~/.agents/skills/paperclip-operator/SKILL.md`. If Paperclip is not configured, present the PRD and **STOP**.

When Paperclip is available, proceed **only after** the user has explicitly approved.

Read the **paperclip-operator** skill first — it contains the full API reference, env var setup, and curl patterns. Do not duplicate its commands here.

#### 4.0 — Resolve Paperclip company and project

**Never** pick the first company returned by the API. An issue in the wrong company/project is a hard failure — agents and board URLs will not match the repo the user is working in.

Resolve **both** `companyId` and `projectId` before creating anything:

1. **Workspace memory** — read `AGENTS.md` → *Learned Workspace Facts* for a Paperclip mapping (company name, issue prefix, project name).
2. **ClickUp context** — if triage started from a ClickUp task, use folder/space/list names as hints.
3. **Repo signals** — `package.json` name, git remote URL, README, or project docs in the workspace root.
4. **Paperclip API** — list companies (`GET /api/companies`), then projects for the candidate company (`GET /api/companies/{companyId}/projects`). Match by name against steps 1–3.

**Confidence rules:**

| Situation | Action |
|-----------|--------|
| Single unambiguous match (company + project) | Proceed; state the resolved mapping in the confirmation recap |
| Multiple plausible matches | **STOP.** Ask the user one focused question listing candidates (`Company / Project — prefix`) |
| Company known, project ambiguous | List matching projects; ask user to pick one |
| Nothing matches | **STOP.** Ask user for company and project names |

Record before creation: `companyId`, `companyName`, `issuePrefix`, `projectId`, `projectName`.

**Wrong-company recovery:** if an issue was already created in the wrong company, cancel it (`status: cancelled` + comment explaining the mistake) and recreate in the correct company/project. Report both identifiers to the user.

#### 4.1 — Resolve the architect agent

Use paperclip-operator **workflow 11** (List Agents) on the **resolved company** (`GET /api/companies/{companyId}/agents`) — not a different company. Find the agent with role `architect` (or whose name/title contains "architect"). Store its `id` for assignment. If no architect agent is found, warn the user and ask which agent to assign instead.

#### 4.2 — Create the issue + attach plan + THEN assign

**CRITICAL SEQUENCING:** Paperclip agents start executing immediately upon assignment. The issue context MUST be complete (plan document attached) BEFORE assigning the architect. Never set `assigneeAgentId` at creation time.

Use this **three-step pattern**:

1. **Create the issue** (workflow 6) in the **resolved company** with `projectId` set, a short description (1-2 sentences summarizing the symptom), status `todo`, appropriate priority, and **NO `assigneeAgentId`** — leave it unassigned.
2. **Attach the Fix PRD as immutable spec reference** — document key **`fix-prd`** (NOT `plan`), title `Fix PRD — [titre court]`, containing the **full Phase 3 PRD** followed by the original report:

```bash
curl -sS -X PUT "$PAPERCLIP_API_URL/api/issues/$ISSUE_ID/documents/fix-prd" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg title "Fix PRD — [titre court]" \
    --arg body "$PRD_CONTENT" \
    '{title: $title, format: "markdown", body: $body, baseRevisionId: null}'
  )"
```

PRD body ends with:

```markdown
---

## Rapport original

> [user's original text as blockquote]
```

**Do not write the Fix PRD to `plan`.** The **`plan`** key is reserved for the architect's working document (may be revised to v2+). **`fix-prd`** is the spec reference for pr-review / spec-check — convention: only triage writes it; architect must not overwrite it.

3. **Assign the architect** via `PATCH /api/issues/{issueId}` with `{"assigneeAgentId": "<architect-id>"}` — only AFTER the `fix-prd` document is confirmed attached.

#### 4.3 — Confirm to the user

Report back: issue identifier, **company + project names**, and the board URL using the resolved issue prefix (see paperclip-operator Presentation Guidelines for the URL pattern). If a wrong-company issue was cancelled, mention its identifier too.

## Rules

- Never create the issue without explicit user approval after the PRD.
- If invalidated, do NOT create an issue — explain and stop.
- If Paperclip is not configured, never attempt API calls — present the PRD and stop.
- The PRD must be self-sufficient: the architect agent implements using ONLY this document.
- Every section must be filled. If a section genuinely doesn't apply (ex: no migration), write "Aucune" — never leave it blank or vague.
- Prefer over-specifying to under-specifying. When in doubt, add detail.
- "Spécification technique du fix" must cite exact file paths and line numbers found during investigation, not vague module names.
- Functional requirements use the pattern: [Acteur] peut [capacité]. No implementation detail in FRs.
- Acceptance criteria are binary pass/fail assertions, not descriptions.
- Always assign to the architect agent **in the same company** as the issue. If no architect is found, ask the user.
- Resolve company and project before creating the issue (Phase 4.0). Never default to the first Paperclip company. Ask the user when ambiguous.
- Pass `projectId` when creating the issue. Verify the returned identifier prefix matches the resolved company.
- Use the short description + **`fix-prd`** document pattern — never put the full PRD in the `description` field or in `plan`.
- Use French for all communication with the user and all document content.
