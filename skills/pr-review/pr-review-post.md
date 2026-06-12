# PR Review — Post to GitHub (Step 4)

Execute **only after user validates** findings from the orchestrator. Requires `context.json` fields: `owner`, `repo`, `pr.number`, `pr.headRefOid`, `reviewState`.

## Resolve / update / create

Build from merged findings: `TO_CREATE`, `TO_UPDATE`, `TO_RESOLVE`.

### Resolve fixed (TO_RESOLVE)

1. Resolve thread (GraphQL):

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { isResolved }
    }
  }
' -f threadId='<THREAD_NODE_ID>'
```

2. Delete inline comment:

```bash
gh api repos/<OWNER>/<REPO>/pulls/comments/<COMMENT_ID> -X DELETE
```

Fallback if delete fails:

```bash
gh api repos/<OWNER>/<REPO>/pulls/comments/<COMMENT_ID> -X PATCH \
  -f body='~~Resolved~~ — this issue has been fixed.
<!-- cursor-review -->'
```

### Update (TO_UPDATE)

```bash
gh api repos/<OWNER>/<REPO>/pulls/comments/<COMMENT_ID> -X PATCH \
  -f body='<updated finding + fix>
<!-- cursor-review -->'
```

Orphaned line → delete + recreate at new line.

### Create (TO_CREATE)

```bash
HEAD_SHA=$(gh pr view <NUMBER> --json headRefOid -q .headRefOid)
gh api repos/<OWNER>/<REPO>/pulls/<NUMBER>/comments \
  -f body='<finding + fix>
<!-- cursor-review -->' \
  -f commit_id="$HEAD_SHA" \
  -f path='<file_path>' \
  -F line=<line> \
  -f side='RIGHT'
```

Every inline body **must** end with `<!-- cursor-review -->`.

### Recap comment

Edit if `reviewState.recapCommentId` set, else `gh pr comment`. Signature: `Automated review by Cursor Agent — last updated: <ISO_DATE>`.

## Formal verdict

**Zero Critical AND zero Warning** → `APPROVE` + `paperclip:approve` label (when the project uses Paperclip merge gates).

**Any Critical or Warning** → `REQUEST_CHANGES`, remove `paperclip:approve` if present:

```bash
gh api repos/<OWNER>/<REPO>/issues/<NUMBER>/labels/paperclip:approve -X DELETE 2>/dev/null || true
```

Never use `COMMENT` event — only `APPROVE` or `REQUEST_CHANGES`.

## Rules

- Never modify non-agent comments (no `<!-- cursor-review -->` marker).
- Resolved threads stay resolved unless bug reintroduced.
- Low-confidence findings: local only, do not post.
