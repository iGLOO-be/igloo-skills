# Exploration Checklist

Run only sections relevant to the user's request. Mark each section done before moving on.

## Project identity

- [ ] Project purpose (from README / AGENTS.md / package.json description)
- [ ] Target users and deployment target
- [ ] Monorepo vs single app — workspace structure if applicable

## Stack & dependencies

- [ ] Runtime version (Node, Python, etc.)
- [ ] Framework and major libraries
- [ ] Package manager and key scripts (`dev`, `build`, `test`, `lint`)

## Architecture

- [ ] Directory layout and layer boundaries
- [ ] Routing structure (pages, API routes, route groups)
- [ ] Server/client boundary (RSC, SSR, SPA patterns)
- [ ] State management and data-fetching patterns

## Data layer

- [ ] ORM / database client location
- [ ] Schema file(s) and key entities
- [ ] Migration strategy
- [ ] Seed or fixture data for local dev

## Auth & authorization

- [ ] Auth provider and config file(s)
- [ ] Login / logout / session lifecycle
- [ ] Protected routes, middleware, or procedure guards
- [ ] Role/permission model if any

## API & business logic

- [ ] API layer type (tRPC, REST, GraphQL, Server Actions)
- [ ] Router/handler organization by domain
- [ ] Input validation pattern (Zod, etc.)
- [ ] Error handling conventions

## External integrations

- [ ] Third-party services and their client wrappers
- [ ] Mock/fallback modes for local dev
- [ ] Required env vars per integration

## UI

- [ ] Component library and styling approach
- [ ] Layout structure (sidebar, auth layout, etc.)
- [ ] Feature component organization

## Testing & quality

- [ ] Test runner and file location convention
- [ ] Mocking patterns for external deps
- [ ] CI pipeline steps and required checks
- [ ] Lint/format tooling

## Dev environment

- [ ] Prerequisites (runtime, DB, Docker, etc.)
- [ ] Env setup from `.env.example`
- [ ] First-run commands to get a working local instance
- [ ] Known pitfalls (documented or discovered)

## Git & workflow

- [ ] Branch strategy and base branch
- [ ] Commit message conventions
- [ ] PR / review process if documented
