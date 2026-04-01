#!/usr/bin/env bash
# List unresolved inline review threads on a GitHub PR as a Markdown table.
# Requires: gh (authenticated), jq.
# Usage:
#   list-open-review-threads.sh OWNER REPO PR_NUMBER
#   list-open-review-threads.sh https://github.com/OWNER/REPO/pull/123
set -euo pipefail

resolve_args() {
  if [[ $# -eq 1 && "$1" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    PR="${BASH_REMATCH[3]}"
  elif [[ $# -eq 3 ]]; then
    OWNER="$1"
    REPO="$2"
    PR="$3"
  else
    echo "Usage: $0 OWNER REPO PR_NUMBER" >&2
    echo "   or: $0 https://github.com/OWNER/REPO/pull/123" >&2
    exit 2
  fi
}

resolve_args "$@"

QUERY='
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isResolved
          path
          line
          comments(first: 30) {
            nodes {
              databaseId
              url
              body
              author { login __typename }
            }
          }
        }
      }
    }
  }
}'

accum='[]'
cursor_json='null'
while true; do
  body=$(jq -n -c \
    --arg query "$QUERY" \
    --arg owner "$OWNER" \
    --arg name "$REPO" \
    --arg pr "$PR" \
    --argjson cursor "$cursor_json" \
    '{query: $query, variables: {owner: $owner, name: $name, number: ($pr | tonumber), cursor: $cursor}}')

  page=$(echo "$body" | gh api graphql --input -)

  nodes=$(echo "$page" | jq '.data.repository.pullRequest.reviewThreads.nodes // []')
  accum=$(echo "$accum" "$nodes" | jq -s '.[0] + .[1]')

  has_next=$(echo "$page" | jq '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  if [[ "$has_next" != "true" ]]; then
    break
  fi
  end=$(echo "$page" | jq -c '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
  cursor_json="$end"
done

echo "$accum" | jq -r --arg owner "$OWNER" --arg repo "$REPO" --argjson pr "$PR" '
def trim(s): s | gsub("^\\s+"; "") | gsub("\\s+$"; "");
def oneline(s):
  trim(s)
  | split("\n")
  | map(select(length > 0))
  | .[0]
  // ""
  | gsub("\\|"; "¦")
  | if length > 140 then .[0:137] + "..." else . end;

def classify($login; $typename):
  ($login | ascii_downcase) as $l
  | if ($l | test("coderabbit")) then "CodeRabbit"
    elif ($l | test("bugbot")) then "Bugbot"
    elif $l == "cursor" and $typename == "Bot" then "Bugbot"
    else "Human"
    end;

[ .[]
  | select(.isResolved == false)
  | . as $thread
  | ($thread.comments.nodes[0] | select(. != null))
  | . as $c
  | {
      id: $c.databaseId,
      source: classify($c.author.login; $c.author.__typename),
      author: ("@" + $c.author.login),
      file: ($thread.path // "—"),
      line: (($thread.line // "—") | tostring),
      summary: oneline($c.body),
      link: ($c.url // "—")
    }
] as $rows
| ($rows | sort_by(.id)) as $open
| [
    "# Open inline review threads (unresolved only)",
    "",
    ("**Repo:** " + $owner + "/" + $repo + " · **PR:** #" + ($pr | tostring) + " · **Count:** " + (($open | length) | tostring)),
    "",
    "| Source | Author | File | Line | Summary | Link |",
    "|--------|--------|------|------|---------|------|",
    ( $open[]
      | "| \(.source) | \(.author) | \(.file) | \(.line) | \(.summary) | \(.link) |"
    ),
    ""
  ]
| .[]
'
