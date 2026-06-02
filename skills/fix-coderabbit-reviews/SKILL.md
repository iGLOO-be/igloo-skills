---
name: fix-coderabbit-reviews
description: Fetches unresolved CodeRabbit review threads on a GitHub PR, validates suggestions against the codebase, and applies fixes after user approval. Use when the user wants to fix CodeRabbit comments, clear bot review threads, or resolve automated PR review feedback on the current git remote.
---

# Fix CodeRabbit reviews

Resolve unresolved **CodeRabbit** review comments on a GitHub pull request. Do not apply code changes until the user approves the fix plan.

## Pre-commit check

After edits, run the project's documented pre-commit check before pushing (e.g. `pnpm check`, `npm run lint`, etc.). Respect **`.cursor/rules/`**, **`AGENTS.md`** or **`CLAUDE.md`**, and existing patterns. User-facing communication may be French; **commit messages and code comments in English**.

## Input

The PR can be given as:

- A full GitHub PR URL
- A PR number only
- **Nothing** → use the current branch's open PR (`gh pr view`)

## Step 1 — Identify the PR

1. If the user passed a URL, parse `owner`, `repo`, and `number` from it.
2. If the user passed a number only, resolve **`owner` / `repo`** from the current repository (see below).
3. If nothing was passed:

   ```bash
   gh pr view --json number,url,headRefName --jq '{number, url, headRefName}'
   ```

4. **Checkout and sync** the PR head when you need to edit (or confirm the user is already on that branch):

   ```bash
   git checkout <headRefName>
   git pull
   ```

### Resolve `owner` and `repo` (current clone)

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
```

Use the part before `/` as **owner** and after as **name** (e.g. `iGLOO-be` / `streetfundraising`).

## Step 2 — Fetch unresolved CodeRabbit threads

Use the GitHub GraphQL API. Replace `<OWNER>`, `<NAME>`, and `<PR_NUMBER>`.

```bash
gh api graphql -f query='
{
  repository(owner: "<OWNER>", name: "<NAME>") {
    pullRequest(number: <PR_NUMBER>) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          id
          comments(first: 20) {
            nodes {
              author { login }
              path
              line
              originalLine
              body
            }
          }
        }
      }
    }
  }
}'
```

**Filter nodes:**

- `isResolved == false`
- First comment's author is **`coderabbitai`** or **`coderabbitai[bot]`** (treat as CodeRabbit)

If `reviewThreads` is truncated, use the GraphQL `pageInfo` / `endCursor` pattern to paginate (rare for typical PRs).

If there are **no** matching threads, tell the user and stop.

## Step 3 — Summarize

Give a **numbered list**. For each thread:

1. **File:line** (e.g. `src/foo.ts:42` — use `line` or `originalLine` as appropriate)
2. **Severity** if present in the body (e.g. major / minor icons or labels CodeRabbit uses)
3. **One-line summary** of the ask

## Step 4 — Analyze each comment

For each unresolved thread:

1. **Read** the file at the path; inspect surrounding lines, not just the single line.
2. **Read** the full comment body (including any suggested diff).
3. **Evaluate** valid / partial / dismiss:
   - CodeRabbit can misunderstand context; verify against real code.
   - Conflicts with project rules → call it out.
   - Deliberate product/design choices → mark for skip or discussion.
4. **Draft** a concrete fix or a dismissal reason.

## Step 5 — Present the fix plan and wait

Use this structure (user must **approve** before any edits):

```markdown
## Fix Plan for PR #<number>

### 1. ✅ Fix — <file>:<line>
**CodeRabbit says:** <summary>
**Analysis:** <your analysis>
**Proposed change:** <what you will change>

### 2. ⏭️ Skip — <file>:<line>
**CodeRabbit says:** <summary>
**Analysis:** <why skip>

### 3. ⚠️ Needs discussion — <file>:<line>
...
```

**Markers:** ✅ Fix · ⏭️ Skip · ⚠️ Needs discussion

**Stop here** until the user confirms or adjusts the plan.

## Step 6 — Apply (after approval)

1. Implement approved fixes only; skip or park others per user.
2. Run the project's documented pre-commit check; fix any failures.
3. Commit in **English**, conventional style, for example:

   ```text
   fix: resolve CodeRabbit review comments on PR #<number>
   ```

4. Push:

   ```bash
   git push
   ```

## Step 7 — Report

Summarize:

- How many comments were fixed vs skipped (with short reasons).
- Anything left for manual follow-up.
- That the user can **resolve** threads in the GitHub UI or leave them if CodeRabbit auto-resolves on new commits (depends on their setup).

## Rules

- **No code changes** before the user validates the plan.
- **Verify** every suggestion against the real codebase.
- **Skip** nits with no real benefit, or false positives, explicitly in the plan.
- Run the project's documented pre-commit check before pushing.

## Additional resources

- GitHub CLI auth must allow `gh api` / `gh pr` for the repo.
- If the PR is in another `owner/repo`, the URL or `gh pr view <url|branch>` can disambiguate before GraphQL.
