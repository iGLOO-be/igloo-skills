#!/usr/bin/env bash
# Bundle PR metadata, diff, and existing agent review state for pr-review orchestrator.
set -euo pipefail

OUT_DIR=""
PR_INPUT=""

usage() {
  cat <<'EOF'
Usage: fetch-pr-review-context.sh [--out-dir DIR] [PR]

  PR          Optional: PR number, #123, or GitHub PR URL. Default: current branch PR.

Options:
  --out-dir DIR   Write diff.patch + context.json here (default: temp dir)

Stdout: compact JSON (paths + metadata; diff in diffPath file, not inlined).

Exit codes:
  0  Success
  1  gh auth / repo error
  2  PR not found
  4  Invalid usage
EOF
}

die() {
  echo "fetch-pr-review-context: $*" >&2
  exit "${DIE_EXIT:-1}"
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      DIE_EXIT=4 die "Option inconnue: $1"
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [[ ${#POSITIONAL[@]} -gt 1 ]]; then
  DIE_EXIT=4 die "Un seul argument PR attendu"
fi
PR_INPUT="${POSITIONAL[0]:-}"

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-review-context.XXXXXX")"
fi
mkdir -p "$OUT_DIR"

PR_NUMBER=""
if [[ -z "$PR_INPUT" ]]; then
  if ! PR_NUMBER="$(gh pr view --json number -q .number 2>/dev/null)"; then
    DIE_EXIT=2 die "Aucune PR ouverte sur la branche courante"
  fi
elif [[ "$PR_INPUT" =~ ^https://github.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  PR_NUMBER="${BASH_REMATCH[3]}"
elif [[ "$PR_INPUT" =~ ^#?([0-9]+)$ ]]; then
  PR_NUMBER="${BASH_REMATCH[1]}"
else
  DIE_EXIT=4 die "PR invalide: $PR_INPUT"
fi

REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || DIE_EXIT=1 die "gh repo view a échoué — gh auth status?"
OWNER="${REPO_SLUG%%/*}"
REPO="${REPO_SLUG##*/}"

PR_META="$(gh pr view "$PR_NUMBER" --json number,url,title,body,headRefName,baseRefName,headRefOid,additions,deletions,changedFiles,labels,author,files 2>/dev/null)" \
  || DIE_EXIT=2 die "PR #$PR_NUMBER introuvable"

gh pr diff "$PR_NUMBER" > "$OUT_DIR/diff.patch"
mapfile -t CHANGED_FILES < <(gh pr diff "$PR_NUMBER" --name-only)

RECAP_COMMENTS="$(gh api "repos/${OWNER}/${REPO}/issues/${PR_NUMBER}/comments" --paginate \
  --jq '[.[] | select(.body | contains("Automated review by Cursor Agent")) | {id, body, created_at, updated_at}]' 2>/dev/null || echo '[]')"
RECAP_ID="$(echo "$RECAP_COMMENTS" | jq -r 'sort_by(.created_at) | last | .id // empty')"

INLINE_COMMENTS="$(gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments" --paginate \
  --jq '[.[] | select(.body | contains("<!-- cursor-review -->")) | {id, path, line, body, in_reply_to_id, created_at, pull_request_review_id}]' 2>/dev/null || echo '[]')"

THREADS="$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            isOutdated
            line
            path
            comments(first: 5) {
              nodes {
                id
                databaseId
                body
                author { login }
              }
            }
          }
        }
      }
    }
  }
' -f owner="$OWNER" -f repo="$REPO" -F number="$PR_NUMBER" 2>/dev/null \
  | jq '.data.repository.pullRequest.reviewThreads.nodes // []' || echo '[]')"

TITLE="$(echo "$PR_META" | jq -r '.title // ""')"
BODY="$(echo "$PR_META" | jq -r '.body // ""')"
SEARCH_TEXT="$TITLE $BODY"

mapfile -t PAPERCLIP_IDS < <(printf '%s\n' "$SEARCH_TEXT" | grep -oE '[A-Z]{2,10}-[0-9]+' | sort -u || true)
mapfile -t CLICKUP_URLS < <(printf '%s\n' "$SEARCH_TEXT" | grep -oE 'https://app\.clickup\.com[^[:space:]<>"]+' | sort -u || true)

PAPERCLIP_JSON="$(printf '%s\n' "${PAPERCLIP_IDS[@]:-}" | jq -R -s 'split("\n") | map(select(length > 0))')"
CLICKUP_JSON="$(printf '%s\n' "${CLICKUP_URLS[@]:-}" | jq -R -s 'split("\n") | map(select(length > 0))')"

SPEC_CHECK=false
if [[ "$(echo "$PAPERCLIP_JSON" | jq 'length')" -gt 0 ]] || [[ "$(echo "$CLICKUP_JSON" | jq 'length')" -gt 0 ]]; then
  SPEC_CHECK=true
fi

CHANGED_COUNT="$(echo "$PR_META" | jq -r '.changedFiles // 0')"
SCOPE_GUARD=false
if [[ "$CHANGED_COUNT" -gt 30 ]]; then
  SCOPE_GUARD=true
fi

FILES_JSON="$(printf '%s\n' "${CHANGED_FILES[@]:-}" | jq -R -s 'split("\n") | map(select(length > 0))')"

CONTEXT_JSON="$(jq -n \
  --arg outDir "$OUT_DIR" \
  --arg diffPath "$OUT_DIR/diff.patch" \
  --argjson pr "$PR_META" \
  --arg owner "$OWNER" \
  --arg repo "$REPO" \
  --argjson files "$FILES_JSON" \
  --argjson paperclipIds "$PAPERCLIP_JSON" \
  --argjson clickupUrls "$CLICKUP_JSON" \
  --argjson specCheck "$SPEC_CHECK" \
  --argjson scopeGuard "$SCOPE_GUARD" \
  --arg recapId "$RECAP_ID" \
  --argjson recapComments "$RECAP_COMMENTS" \
  --argjson inlineComments "$INLINE_COMMENTS" \
  --argjson threads "$THREADS" \
  '{
    outDir: $outDir,
    diffPath: $diffPath,
    owner: $owner,
    repo: $repo,
    pr: $pr,
    changedFiles: $files,
    changedFilesCount: ($files | length),
    specCheck: $specCheck,
    paperclipIds: $paperclipIds,
    clickupUrls: $clickupUrls,
    scopeGuard: $scopeGuard,
    reviewState: {
      recapCommentId: (if $recapId == "" then null else ($recapId | tonumber) end),
      recapComments: $recapComments,
      inlineComments: $inlineComments,
      threads: $threads
    }
  }')"

echo "$CONTEXT_JSON" > "$OUT_DIR/context.json"
echo "$CONTEXT_JSON"
