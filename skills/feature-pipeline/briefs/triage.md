# Pipeline brief — Triage

Produce a self-sufficient PRD for the architect. No Paperclip API.

## Bug

1. Parse claim (what / where / when).
2. Investigate codebase (Grep/Read) — evidence with `path:Lx`.
3. Verdict:
   - **invalidated** — bug cannot occur / already fixed / premise wrong → explain with citations; **do not** write PRD body.
   - **validated** — write **Fix PRD** (sections 1–8) per paperclip-triage-issue structure: contexte, cause racine, comportement attendu, exigences, contraintes, notes tech, critères d'acceptation, références.
4. French. FR/AC testable, implementation-agnostic.

## Feature

1. Parse need: actors, capability, constraints, out-of-scope hints.
2. Investigate analogues (routes, permissions, tests).
3. Verdict:
   - **invalidated** — already exists / infeasible / out of scope.
   - **validated** — write **Feature PRD** per [prd-templates.md](../prd-templates.md) § Feature (sections 1–8).
4. French. Every section filled (« Aucune » / « N/A » if needed).

## Output contract

- Write full PRD markdown to `{artifactPath}` **only if** validated (overwrite).
- If invalidated: do **not** write the artifact file.
- Return **thin JSON only** (no PRD body in JSON) — see subagent-prompts § Triage.
