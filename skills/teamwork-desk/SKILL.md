---
name: teamwork-desk
description: Query and interact with Teamwork Desk API v2 for support ticket management. Use when the user asks to list tickets, read ticket details, read messages or notes, post notes, or perform any Teamwork Desk helpdesk operation.
---

# Teamwork Desk

## Prérequis

Le CLI Python requiert `requests` :

```bash
pip install requests
```

## Configuration

Requires two env vars (check env, ask user if missing):

| Variable | Description | Example |
|---|---|---|
| `TEAMWORK_DESK_DOMAIN` | Subdomain | `mycompany.teamwork.com` |
| `TEAMWORK_DESK_API_KEY` | API key (Bearer token) | `tkn_...` |

## Emplacement (portable)

Racine du skill : **`skills/teamwork-desk/`** (dans ce dépôt ou tout clone du bundle de skills).

Dans ce dépôt, un symlink **`.cursor/skills/teamwork-desk`** pointe vers `skills/teamwork-desk/` pour la découverte automatique par Cursor.

## CLI (primary interface)

Always prefer the CLI over raw curl. It handles auth, filtering, pagination, name resolution, and formatted output.

The CLI script `support-cli.py` is co-located with this SKILL.md.

**Depuis la racine du dépôt** (où se trouve le dossier `skills/`) :

```bash
python3 skills/teamwork-desk/support-cli.py --help
```

**Depuis le dossier du skill** (`skills/teamwork-desk/`) :

```bash
python3 support-cli.py --help
```

**Chemin canonique** : `skills/teamwork-desk/support-cli.py`

### scan — List tickets

```bash
# Active tickets in an inbox (last 14 days)
python3 skills/teamwork-desk/support-cli.py scan --inbox-id 4364 --status active --days 14

# Active + Waiting on customer
python3 skills/teamwork-desk/support-cli.py scan --inbox-id 4364 --status active,waiting

# All statuses, last 30 days, max 10 rows
python3 skills/teamwork-desk/support-cli.py scan --inbox-id 4364 --days 30 --limit 10

# No date filter (latest 50)
python3 skills/teamwork-desk/support-cli.py scan --inbox-id 4364 --days 0
```

**Status names for `--status`:** `active`(1), `waiting`(3), `on-hold`(4), `solved`(5), `closed`(6), `spam`(7)

### read — Ticket detail + messages

```bash
# Full ticket: header + all messages
python3 skills/teamwork-desk/support-cli.py read 92325990

# Internal notes only
python3 skills/teamwork-desk/support-cli.py read 92325990 --notes-only

# Header only (skip messages)
python3 skills/teamwork-desk/support-cli.py read 92325990 --no-messages
```

**threadType values** (shown in message output):

| ID | Name | Description |
|---|---|---|
| 1 | `message` | Customer/agent reply |
| 2 | `forward` | Forwarded message |
| 3 | `note` | Internal note (private) |
| 4 | `eventInfo` | System event |

### post-note — Post an internal note

```bash
# Inline HTML body
python3 skills/teamwork-desk/support-cli.py post-note 92325990 --body '<p>Analysis here.</p>'

# From stdin (pipe)
echo '<p>Note content</p>' | python3 skills/teamwork-desk/support-cli.py post-note 92325990
```

> **CRITICAL — HTML required:** The note body MUST contain **HTML markup**, not plain text.
> Plain `\n` line breaks are **silently ignored** by Teamwork Desk — the note renders as one continuous block.
> Always wrap content in `<p>`, `<br/>`, `<ul>`, `<li>`, `<strong>`, `<em>` etc.

#### HTML formatting guide

| Intent | HTML |
|---|---|
| Paragraph / line break | `<p>…</p>` or `<br/>` |
| Bold (section titles only) | `<strong>Title</strong>` |
| Italic | `<em>…</em>` |
| Bullet list | `<ul><li>…</li></ul>` |
| Numbered list | `<ol><li>…</li></ol>` |
| Hyperlink | `<a href="url">label</a>` |
| Horizontal rule | `<hr/>` |

**Minimal example** (internal analysis note):

```html
<p><em>Cette note est proposée par un assistant IA.</em></p>
<ul>
  <li><strong>Contexte</strong> — Client X, problème Y, urgence faible.</li>
  <li><strong>Action effectuée</strong> — Analyse ticket + recherche doc.</li>
  <li><strong>Prochaine étape</strong> — Support humain vérifie Z.</li>
</ul>
<hr/>
<p><strong>Résumé & Analyse</strong></p>
<p>Diagnostic détaillé ici…</p>
<p><strong>Liens de documentation</strong></p>
<ul>
  <li><a href="https://docs.example.com/page1">Page 1</a></li>
  <li><a href="https://docs.example.com/page2">Page 2</a> — faq-candidate</li>
</ul>
```

### update — Modify ticket fields

```bash
# Change status
python3 skills/teamwork-desk/support-cli.py update 92325990 --status solved

# Assign agent
python3 skills/teamwork-desk/support-cli.py update 92325990 --agent 461854

# Multiple fields at once
python3 skills/teamwork-desk/support-cli.py update 92325990 --status on-hold --agent 461854 --priority high
```

## Output guidelines

- When listing tickets: show a concise table with id, subject, status, inbox, created date, and customer name.
- When showing ticket detail: display subject, status, priority, assignee, customer, tags, and creation date.
- When showing messages: display each thread chronologically with sender, date, type (reply/note/event), and a trimmed body preview.
- Always inform the user before posting/modifying data (notes, replies).

## API Reference (curl fallback)

> Prefer the CLI above. Use curl only for operations not covered by the CLI.

Base URL: `https://{TEAMWORK_DESK_DOMAIN}/desk/api/v2`

Auth header: `Authorization: Bearer {TEAMWORK_DESK_API_KEY}`

### List tickets

```bash
curl -s "https://${TEAMWORK_DESK_DOMAIN}/desk/api/v2/tickets.json?orderBy=createdAt&orderMode=desc&pageSize=20&includes=customers,inboxes,users,ticketstatuses" \
  -H "Authorization: Bearer ${TEAMWORK_DESK_API_KEY}"
```

Filtering: pass `filter` query param with URL-encoded JSON. Operators: `$eq`, `$ne`, `$lt`, `$lte`, `$gt`, `$gte`, `$in`, `$nin`, `$and`, `$or`, `$contains`. Filterable fields: `id`, `subject`, `status`, `state`, `priority`, `inbox`, `agent`, `contact`, `company`, `customer`, `source`, `type`, `createdAt`, `updatedAt`, `deletedAt`, `sla`, `slaBreachedAt`.

Pagination: `page`, `pageSize` (default 20), `pageOffset`. Response `included.pagination` has `records`, `page`, `pages`.

### Get ticket detail

```bash
curl -s "https://${TEAMWORK_DESK_DOMAIN}/desk/api/v2/tickets/${TICKET_ID}.json?includes=customers,inboxes,users,tags,ticketstatuses" \
  -H "Authorization: Bearer ${TEAMWORK_DESK_API_KEY}"
```

### Get ticket messages

```bash
curl -s "https://${TEAMWORK_DESK_DOMAIN}/desk/api/v2/tickets/${TICKET_ID}/messages.json?orderBy=createdAt&orderMode=asc&includes=users,files" \
  -H "Authorization: Bearer ${TEAMWORK_DESK_API_KEY}"
```

### Post a note

`threadType` MUST be the string `"note"` (not integer `3`). `message` MUST be HTML (see formatting guide above).

```bash
curl -s -X POST "https://${TEAMWORK_DESK_DOMAIN}/desk/api/v2/tickets/${TICKET_ID}/messages.json" \
  -H "Authorization: Bearer ${TEAMWORK_DESK_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"message": "<p>HTML here</p>", "threadType": "note"}'
```

### Update ticket

```bash
curl -s -X PATCH "https://${TEAMWORK_DESK_DOMAIN}/desk/api/v2/tickets/${TICKET_ID}.json" \
  -H "Authorization: Bearer ${TEAMWORK_DESK_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"ticket": {"status": {"id": STATUS_ID, "type": "ticketstatuses"}}}'
```

Updatable fields (all optional, omitted fields unchanged):

| Field | Format |
|---|---|
| `status` | `{"id": STATUS_ID, "type": "ticketstatuses"}` |
| `agent` | `{"id": USER_ID, "type": "users"}` |
| `priority` | string (`"high"`, `"low"`, …) |
| `tags` | `[{"id": TAG_ID, "type": "tags"}]` |

## Reference

- [API docs](https://apidocs.teamwork.com/docs/desk)
- [Authentication](https://apidocs.teamwork.com/guides/desk/authentication)
- [Filtering](https://apidocs.teamwork.com/guides/desk/filtering-api-results)
- [Webhook payloads](https://apidocs.teamwork.com/guides/desk/teamwork-desk-webhook-payload-samples)
