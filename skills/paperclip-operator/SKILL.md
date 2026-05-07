---
name: paperclip-operator
description: >
  Interact with a remote Paperclip instance as a board operator. List tasks,
  inspect issues, create issues and plan documents, view dashboard and agents.
  Use when the user asks to check tasks, create work items, or manage a
  Paperclip instance from Cursor or another LLM client. Not for agent
  heartbeat mode — this is the human-operator companion skill.
---

# Paperclip Operator Skill

Lightweight skill for **board operators** (humans using an LLM client) to interact with a remote Paperclip control-plane instance via its REST API.

This skill does **not** cover the agent heartbeat loop, checkout semantics, or agent governance. For that, use the `paperclip` agent skill.

## Prerequisites

Two environment variables must be set:

| Variable | Description |
|---|---|
| `PAPERCLIP_API_URL` | Base URL of the Paperclip instance (e.g. `https://my-server.tail12345.ts.net`) |
| `PAPERCLIP_API_KEY` | Board-operator bearer token (see Auth Setup below) |

Optional:

| Variable | Description |
|---|---|
| `PAPERCLIP_COMPANY_ID` | Default company ID (avoids passing it in every call) |

Before making any API call, verify these env vars are set. If not, guide the user through **Auth Setup**.

## Auth Setup (one-time)

Board operators authenticate via a CLI challenge flow. Run this from the Paperclip repo checkout:

```bash
pnpm paperclipai auth login --api-base "$PAPERCLIP_API_URL"
```

This opens a browser challenge that must be approved in the Paperclip board UI.
Once approved, the token is stored in `~/.paperclip/auth.json`.

Extract the token for use in env vars:

```bash
export PAPERCLIP_API_URL="https://my-server.example.com"
export PAPERCLIP_API_KEY=$(jq -r --arg base "$PAPERCLIP_API_URL" '.credentials[$base].token // .credentials[($base + "/")].token // empty' ~/.paperclip/auth.json)
```

Verify it works:

```bash
curl -sS "$PAPERCLIP_API_URL/api/companies" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq .
```

If the instance runs in `local_trusted` mode (no auth), `PAPERCLIP_API_KEY` can be omitted.

## API Call Convention

All calls use this pattern:

```bash
curl -sS "$PAPERCLIP_API_URL/api/<path>" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json"
```

When a company ID is needed, use `$PAPERCLIP_COMPANY_ID` or ask the user.

Always pipe through `jq` for readable output.

---

## Critical: Description vs Document

Paperclip **truncates** issue `description` fields when they are too long. Markdown **documents** (e.g. `plan`) are stored without truncation.

**Rule:** Never put long-form content (plans, specs, analysis, detailed requirements) in the `description` field. Instead:

1. Create the issue with a **short summary** as `description` (1–3 sentences).
2. Immediately create a document (typically key `plan`) with the full content via `PUT /api/issues/{id}/documents/plan`.

This is a two-step process: create the issue first, then attach the document using the returned issue `id`.

## Common Workflows

### 1. Discover Companies

```bash
curl -sS "$PAPERCLIP_API_URL/api/companies" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq '.[] | {id, name, prefix}'
```

Use the company `id` for subsequent calls. If only one company exists, use it automatically and inform the user.

### 2. Dashboard Overview

```bash
curl -sS "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/dashboard" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq .
```

Summarize: active issues count, agent statuses, recent activity.

### 3. List Issues

```bash
curl -sS "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/issues?status=todo,in_progress,in_review,blocked" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq '.[] | {id, identifier, title, status, priority, assigneeAgentId}'
```

Useful filters (combine with `&`):

| Parameter | Example | Description |
|---|---|---|
| `status` | `todo,in_progress` | Comma-separated status filter |
| `assigneeAgentId` | `<agent-id>` | Issues assigned to a specific agent |
| `projectId` | `<project-id>` | Issues in a project |
| `labelId` | `<label-id>` | Issues with a label |
| `q` | `dockerfile` | Full-text search (title, identifier, description, comments) |
| `parentId` | `<issue-id>` | Direct children of an issue |

Present results as a concise table or summary.

### 4. Get Issue Details

```bash
curl -sS "$PAPERCLIP_API_URL/api/issues/<issue-id-or-identifier>" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq .
```

The response includes: title, description, status, priority, assignee, project, goal, ancestors, `blockedBy`, `blocks`.

To also get comments:

```bash
curl -sS "$PAPERCLIP_API_URL/api/issues/<issue-id>/comments" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq '.[] | {id, body, authorAgentId, authorUserId, createdAt}'
```

To get issue documents (plan, etc.):

```bash
curl -sS "$PAPERCLIP_API_URL/api/issues/<issue-id>/documents" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq .
```

### 5. Search Issues

```bash
curl -sS "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/issues?q=<search-term>" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq '.[] | {id, identifier, title, status, priority}'
```

Results ranked by relevance: title > identifier > description > comments.

### 6. Create an Issue

**Remember:** `description` is truncated for long text. Keep it short. Put plans and detailed content in a document (see workflow 9).

```bash
ISSUE_ID=$(curl -sS -X POST "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/issues" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg title "Issue title" \
    --arg description "Short summary of the issue." \
    --arg status "todo" \
    --arg priority "medium" \
    '{title: $title, description: $description, status: $status, priority: $priority}'
  )" | jq -r '.id')
echo "Created issue: $ISSUE_ID"
```

If the user provided a plan or long-form content, **immediately** attach it as a document:

```bash
curl -sS -X PUT "$PAPERCLIP_API_URL/api/issues/$ISSUE_ID/documents/plan" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg title "Plan" \
    --arg body "$PLAN_CONTENT" \
    '{title: $title, format: "markdown", body: $body, baseRevisionId: null}'
  )" | jq .
```

Available fields:

| Field | Required | Values |
|---|---|---|
| `title` | yes | string |
| `description` | no | short summary only (truncated if long!) |
| `status` | no | `backlog`, `todo`, `in_progress`, `in_review`, `done`, `blocked`, `cancelled` |
| `priority` | no | `critical`, `high`, `medium`, `low` |
| `assigneeAgentId` | no | agent UUID |
| `parentId` | no | parent issue UUID |
| `projectId` | no | project UUID |
| `goalId` | no | goal UUID |
| `blockedByIssueIds` | no | array of issue UUIDs |
| `billingCode` | no | string |

Use `jq -n` with `--arg`/`--argjson` to build the JSON body safely — never hand-craft JSON strings with embedded markdown.

### 7. Update an Issue

```bash
curl -sS -X PATCH "$PAPERCLIP_API_URL/api/issues/<issue-id>" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg status "in_progress" \
    --arg comment "Started working on this." \
    '{status: $status, comment: $comment}'
  )" | jq .
```

Updatable fields: `title`, `description`, `status`, `priority`, `assigneeAgentId`, `projectId`, `goalId`, `parentId`, `billingCode`, `blockedByIssueIds`, `comment`.

### 8. Add a Comment

```bash
curl -sS -X POST "$PAPERCLIP_API_URL/api/issues/<issue-id>/comments" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg body "Comment in **markdown**." '{body: $body}')" | jq .
```

### 9. Create or Update a Plan Document

Create a plan for an issue:

```bash
curl -sS -X PUT "$PAPERCLIP_API_URL/api/issues/<issue-id>/documents/plan" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg title "Plan" \
    --arg body "# Plan

## Goal
...

## Approach
...

## Tasks
1. ...
2. ...

## Risks
- ...
" \
    '{title: $title, format: "markdown", body: $body, baseRevisionId: null}'
  )" | jq .
```

To update an existing plan, first fetch the current revision:

```bash
REVISION=$(curl -sS "$PAPERCLIP_API_URL/api/issues/<issue-id>/documents/plan" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq -r '.revisionId')
```

Then update with `baseRevisionId` set:

```bash
curl -sS -X PUT "$PAPERCLIP_API_URL/api/issues/<issue-id>/documents/plan" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg title "Plan" \
    --arg body "# Updated plan content..." \
    --arg rev "$REVISION" \
    '{title: $title, format: "markdown", body: $body, baseRevisionId: $rev}'
  )" | jq .
```

### 10. List Agents

```bash
curl -sS "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/agents" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq '.[] | {id, name, role, title, status}'
```

Get agent details:

```bash
curl -sS "$PAPERCLIP_API_URL/api/agents/<agent-id>" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq .
```

### 11. List Projects

```bash
curl -sS "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/projects" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq '.[] | {id, name, status, description}'
```

### 12. Approvals

List pending approvals:

```bash
curl -sS "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/approvals?status=pending" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq .
```

Approve / reject:

```bash
curl -sS -X POST "$PAPERCLIP_API_URL/api/approvals/<approval-id>/approve" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"decisionNote": "Approved."}' | jq .

curl -sS -X POST "$PAPERCLIP_API_URL/api/approvals/<approval-id>/reject" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"decisionNote": "Rejected — reason here."}' | jq .
```

### 13. Activity Log

```bash
curl -sS "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/activity" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq '.[:10]'
```

Filter by agent or entity:

```bash
# By agent
curl -sS "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/activity?agentId=<agent-id>" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq .

# By entity
curl -sS "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/activity?entityType=issue&entityId=<issue-id>" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq .
```

---

## Presentation Guidelines

When presenting results to the user:

- **Issues list**: concise table with identifier, title, status, priority, assignee
- **Issue detail**: structured summary with status, assignee, description excerpt, blockers, recent comments
- **Dashboard**: high-level summary (active counts, blocked items, agent health)
- **Plans**: render the markdown content directly
- **Agents**: table with name, role, status

Use the company prefix from issue identifiers (e.g. `PAP` from `PAP-42`) to construct board UI links:

- Issue: `$PAPERCLIP_API_URL/<prefix>/issues/<identifier>`
- Agent: `$PAPERCLIP_API_URL/<prefix>/agents/<agent-url-key>`
- Project: `$PAPERCLIP_API_URL/<prefix>/projects/<project-url-key>`

## Troubleshooting

| Problem | Fix |
|---|---|
| `401 Unauthorized` | Token expired or invalid. Re-run `paperclipai auth login --api-base "$PAPERCLIP_API_URL"` and re-export the token. |
| `403 Forbidden` | Not a member of the target company, or company ID is wrong. Check with `GET /api/companies`. |
| `404 Not Found` | Wrong issue/agent ID, or the entity belongs to another company. |
| Missing env vars | Guide user through Auth Setup section. |
