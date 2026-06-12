---
name: dev-onboarding
description: Onboards a developer onto an existing project by synthesizing PO context, codebase exploration, and task-oriented maps. Adapts depth to the request — full onboarding or focused deep dive on one aspect (architecture, auth, data model, integrations, setup, conventions). Use when the user explicitly asks for onboarding, project explanation, understanding how the project works, or getting up to speed on an unfamiliar codebase. Skill lives under skills/dev-onboarding in the repository.
---

# Developer Onboarding

Guide a developer resuming work on an existing project. Complement PO-level context with actionable technical understanding.

## Emplacement (portable)

Racine du skill : **`skills/dev-onboarding/`** (dans ce dépôt ou tout clone du bundle de skills). Fichiers de support :

- [checklist.md](checklist.md) — guide d'exploration (lu à la demande)
- [output-template.md](output-template.md) — template du rapport complet

## Scope detection

Before exploring, classify the request:

| Request type | Signals | Output |
|---|---|---|
| **Full onboarding** | "onboarding", "comprendre le projet", "vue d'ensemble", "me mettre à niveau" | Full report — see [output-template.md](output-template.md) |
| **Focused aspect** | "comment fonctionne l'auth", "explique l'architecture", "modèle de données", "setup local", "intégrations" | Targeted section only — skip unrelated areas |
| **Task-oriented** | "je dois faire X", "où modifier pour Y" | Trace end-to-end flow + entry points for that task |

When scope is ambiguous, ask one clarifying question. Default to **focused** if the user named a specific aspect; default to **full** if they said "onboarding" without qualifier.

## Workflow

### Step 1 — Gather user context

Collect what the user already knows (don't re-explore what they provided):

- PO notes or business context already shared
- Upcoming tasks or tickets
- Specific aspect they care about
- Known constraints (env access, deadline, read-only vs write access)

If the user provided nothing beyond the request, proceed with codebase exploration alone.

### Step 2 — Read project docs first

Read in priority order (skip files that don't exist):

1. `README.md`, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`
2. `package.json` — scripts, key dependencies
3. `.env.example` — required env vars
4. `prisma/schema.prisma` or equivalent data schema
5. CI config (`.github/workflows/`)

Extract facts from docs; do not duplicate them verbatim in the output — synthesize and link to source files.

### Step 3 — Explore the codebase

Use [checklist.md](checklist.md) as exploration guide. For **focused** requests, run only the relevant sections.

Explore in parallel when possible. Prioritize:

- **Architecture**: entry points, layer boundaries, routing
- **Data**: schema, migrations, key entities and relations
- **Auth**: provider, session, protected routes/procedures
- **API**: routers, handlers, validation patterns
- **Integrations**: external services, mocks, env requirements
- **UI**: layout groups, feature component organization
- **Tests & CI**: test structure, how to run, what gates exist
- **Conventions**: lint, commit style, path aliases

### Step 4 — Map business to code

For each business domain (from PO notes or inferred from routes/routers):

| Domain | User-facing surface | Backend | Data |
|---|---|---|---|
| ... | pages/components | routers/services | models/tables |

If PO context is missing, infer domains from folder structure and name them explicitly as assumptions.

### Step 5 — Produce output

Use the template matching scope:

- **Full onboarding** → [output-template.md](output-template.md)
- **Focused aspect** → section from template + "Related files" list
- **Task-oriented** → flow diagram + entry points table + risks

Write in the user's language (French if they wrote in French).

### Step 6 — Surface open questions

End with concrete questions for PO/team when:

- Business rules are unclear from code alone
- Env vars or external services are undocumented
- Multiple valid interpretations exist

## Output principles

- **Actionable over exhaustive** — point to files, not paraphrase entire modules
- **Progressive** — start with a 30-second summary, then details
- **Honest gaps** — mark inferred vs confirmed knowledge
- **No duplication** — if `AGENTS.md` covers conventions, reference it instead of copying
- **Proportional depth** — a focused auth question doesn't need a full DB schema dump

## Code citation format

When referencing code, use:

```
startLine:endLine:filepath
```

## Examples

### Full onboarding

User: "Fais-moi un onboarding sur ce projet, j'ai eu un topo PO mais je dois coder dessus."

→ Read docs → explore all checklist sections → produce full template → map upcoming tasks if mentioned.

### Focused aspect

User: "Explique-moi comment l'authentification fonctionne dans ce projet."

→ Read auth config + middleware/proxy + session provider → trace login → session → protected access → output auth section only with flow diagram.

### Task-oriented

User: "Je dois ajouter un champ au profil partenaire, par où commencer ?"

→ Find partner entity in schema → trace read/write path (page → tRPC → Prisma → external CRM if synced) → list files to touch + validation + tests.
