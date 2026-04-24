#!/usr/bin/env bash
# List open PRs on a GitHub repo with agent-detection, Paperclip ref extraction,
# CI / review / merge status, and a recommended action for each PR.
# Requires: gh (authenticated), jq.
#
# Usage:
#   list-pr-status.sh [OPTIONS] OWNER REPO
#   list-pr-status.sh [OPTIONS] https://github.com/OWNER/REPO
#
# Options:
#   --prefix PREFIX   Paperclip identifier prefix (default: FOL)
#   --agent-only      Only show PRs identified as agent PRs
#   --json            Output raw JSON instead of Markdown table
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
PREFIX="FOL"
AGENT_ONLY=false
OUTPUT_JSON=false

# ── Arg parsing ───────────────────────────────────────────────────────────────
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)     PREFIX="$2"; shift 2 ;;
    --agent-only) AGENT_ONLY=true; shift ;;
    --json)       OUTPUT_JSON=true; shift ;;
    -*)           echo "Unknown option: $1" >&2; exit 2 ;;
    *)            POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]}"

resolve_args() {
  if [[ $# -eq 1 && "$1" =~ ^https://github\.com/([^/]+)/([^/]+)(/.*)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
  elif [[ $# -eq 2 ]]; then
    OWNER="$1"
    REPO="$2"
  else
    echo "Usage: $0 [OPTIONS] OWNER REPO" >&2
    echo "   or: $0 [OPTIONS] https://github.com/OWNER/REPO" >&2
    exit 2
  fi
}

resolve_args "$@"

# ── GraphQL query ─────────────────────────────────────────────────────────────
read -r -d '' QUERY << 'GRAPHQL' || true
query($owner: String!, $name: String!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: OPEN, first: 50, after: $cursor, orderBy: {field: CREATED_AT, direction: DESC}) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number
        title
        headRefName
        body
        isDraft
        mergeable
        url
        reviewDecision
        labels(first: 20) { nodes { name } }
        reviewThreads(first: 100) {
          nodes {
            isResolved
            path
            line
            comments(first: 1) {
              nodes {
                author { login __typename }
              }
            }
          }
        }
        commits(last: 5) {
          nodes {
            commit {
              message
              statusCheckRollup {
                contexts(first: 100) {
                  nodes {
                    __typename
                    ... on CheckRun {
                      name
                      status
                      conclusion
                    }
                    ... on StatusContext {
                      context
                      state
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
GRAPHQL

# ── Paginated fetch ──────────────────────────────────────────────────────────
accum='[]'
cursor_json='null'
while true; do
  body=$(jq -n -c \
    --arg query "$QUERY" \
    --arg owner "$OWNER" \
    --arg name "$REPO" \
    --argjson cursor "$cursor_json" \
    '{query: $query, variables: {owner: $owner, name: $name, cursor: $cursor}}')

  page=$(echo "$body" | gh api graphql --input -)

  nodes=$(echo "$page" | jq '.data.repository.pullRequests.nodes // []')
  accum=$(echo "$accum" "$nodes" | jq -s '.[0] + .[1]')

  has_next=$(echo "$page" | jq '.data.repository.pullRequests.pageInfo.hasNextPage')
  if [[ "$has_next" != "true" ]]; then
    break
  fi
  cursor_json=$(echo "$page" | jq -c '.data.repository.pullRequests.pageInfo.endCursor')
done

# ── jq triage filter ─────────────────────────────────────────────────────────
# Kept in a heredoc so bash does not try to parse jq syntax inside $().
read -r -d '' JQ_TRIAGE << 'JQFILTER' || true

def extract_ref($pfx):
  ($pfx + "-[0-9]+") as $pat |
  if test($pat) then capture("(?<r>" + $pat + ")") | .r else null end;

def first_ref($branch; $title; $body; $pfx):
  ($branch | extract_ref($pfx)) //
  ($title  | extract_ref($pfx)) //
  ($body   | extract_ref($pfx));

def has_paperclip_coauthor:
  any(.[]; .commit.message | test("Co-Authored-By:.*Paperclip"; "i"));

def agent_branch($branch):
  ($branch | test("^paperclip/"; "i")) or ($branch | test("^agent/"; "i"));

def has_label($name):
  any(.labels.nodes[]?; .name == $name);

def agent_signals($commits; $branch):
  [ (if ($commits | has_paperclip_coauthor) then "co-authored-by" else empty end),
    (if agent_branch($branch) then "branch-prefix" else empty end),
    (if has_label("paperclip:agent") then "label" else empty end) ];

def classify_thread_author($login; $typename):
  ($login | ascii_downcase) as $l |
  if ($l | test("coderabbit")) then "CodeRabbit"
  elif ($l | test("bugbot")) then "Bugbot"
  elif $l == "cursor" and $typename == "Bot" then "Bugbot"
  else "human"
  end;

def unresolved_threads($threads):
  [ $threads[]?
    | select(.isResolved == false)
    | (.comments.nodes[0]? // {}) as $c
    | ($c.author // {}) as $a
    | {
        source: classify_thread_author(($a.login // "unknown"); ($a.__typename // "")),
        file:   (.path // null),
        line:   (.line // null)
      }
  ];

def ci_from_contexts($contexts):
  [ $contexts[]?
    | if .__typename == "CheckRun" then
        select(.name | test("vercel"; "i") | not)
        | { name: .name, ok: (.conclusion == "SUCCESS"), pending: (.status != "COMPLETED") }
      elif .__typename == "StatusContext" then
        select(.context | test("vercel"; "i") | not)
        | { name: .context, ok: (.state == "SUCCESS"), pending: (.state == "PENDING") }
      else empty
      end
  ] as $checks
  | if ($checks | length) == 0 then { status: "none", failures: [] }
    elif any($checks[]; .pending) then { status: "pending", failures: [] }
    elif all($checks[]; .ok) then { status: "pass", failures: [] }
    else { status: "fail", failures: [ $checks[] | select(.ok | not) | select(.pending | not) | .name ] }
    end;

def decide_action($is_agent; $mergeable; $ci; $review; $approve; $bot_threads):
  if ($is_agent | not) then "skip"
  elif $mergeable == "CONFLICTING" then "handoff_coder"
  elif $ci.status == "fail" then "handoff_coder"
  elif $ci.status == "pending" then "wait_ci"
  elif $review == "CHANGES_REQUESTED" then "handoff_coder"
  elif ($bot_threads | length) > 0 then "handoff_coder"
  elif $approve then "merge"
  else "wait_approval"
  end;

def action_reason($is_agent; $mergeable; $ci; $review; $approve; $bot_threads):
  if ($is_agent | not) then "not an agent PR"
  elif $mergeable == "CONFLICTING" then "git conflict"
  elif $ci.status == "fail" then "CI failures: " + ($ci.failures | join(", "))
  elif $ci.status == "pending" then "CI still running"
  elif $review == "CHANGES_REQUESTED" then "changes requested in review"
  elif ($bot_threads | length) > 0 then
    ($bot_threads | length | tostring) + " unresolved bot review thread(s): "
    + ([ $bot_threads[] | .source + " on " + (.file // "?") ] | join(", "))
  elif $approve then "ready to merge"
  else "waiting for paperclip:approve label"
  end;

[ .[] |
  . as $pr |
  ($pr.commits.nodes // []) as $commits |
  agent_signals($commits; $pr.headRefName) as $signals |
  (($signals | length) > 0) as $is_agent |
  first_ref($pr.headRefName; $pr.title; ($pr.body // ""); $prefix) as $ref |
  (($commits | last // {commit:{}}).commit.statusCheckRollup.contexts.nodes // []) as $ctx |
  ci_from_contexts($ctx) as $ci |
  ($pr.reviewDecision // null) as $review |
  ($pr | has_label("paperclip:approve")) as $approve |
  ($pr.mergeable // "UNKNOWN") as $mergeable |
  unresolved_threads($pr.reviewThreads.nodes // []) as $threads |
  ([ $threads[] | select(.source != "human") ]) as $bot_threads |
  decide_action($is_agent; $mergeable; $ci; $review; $approve; $bot_threads) as $action |
  action_reason($is_agent; $mergeable; $ci; $review; $approve; $bot_threads) as $reason |
  {
    number:                  $pr.number,
    title:                   $pr.title,
    branch:                  $pr.headRefName,
    url:                     $pr.url,
    is_draft:                $pr.isDraft,
    is_agent_pr:             $is_agent,
    agent_signals:           $signals,
    paperclip_ref:           $ref,
    mergeable:               $mergeable,
    ci_status:               $ci.status,
    ci_failures:             $ci.failures,
    review_decision:         $review,
    has_approve_label:       $approve,
    unresolved_threads:      ($threads | length),
    unresolved_bot_threads:  ($bot_threads | length),
    unresolved_thread_details: $bot_threads,
    action:                  $action,
    action_reason:           $reason
  }
]
| if $agent_only then [ .[] | select(.is_agent_pr) ] else . end
| sort_by(.number) | reverse

JQFILTER

RESULT=$(echo "$accum" | jq -r \
  --arg prefix "$PREFIX" \
  --argjson agent_only "$AGENT_ONLY" \
  --arg owner "$OWNER" \
  --arg repo "$REPO" \
  "$JQ_TRIAGE")

# ── Markdown formatter ────────────────────────────────────────────────────────
read -r -d '' JQ_TABLE << 'JQTABLE' || true

def short(s; n): if (s | length) > n then s[0:n-3] + "..." else s end;
def dash_or(v): if v == null or v == "" then "\u2014" else v end;
def yn(b): if b then "yes" else "no" end;
def mg(s): if s == "MERGEABLE" then "ok" elif s == "CONFLICTING" then "CONFLICT" elif s == "UNKNOWN" then "unknown" else "?" end;

[
  "# PR Status \u2014 " + $owner + "/" + $repo,
  "",
  "| # | Title | Branch | Ref | Mergeable | CI | Review | Threads | Approve | Action |",
  "|---|-------|--------|-----|-----------|-----|--------|---------|---------|--------|",
  ( .[] |
    "| " + (.number | tostring) +
    " | " + short(.title; 50) +
    " | " + short(.branch; 40) +
    " | " + dash_or(.paperclip_ref) +
    " | " + mg(.mergeable) +
    " | " + .ci_status +
    " | " + dash_or(.review_decision) +
    " | " + (if .unresolved_bot_threads > 0 then (.unresolved_bot_threads | tostring) + " bot" elif .unresolved_threads > 0 then (.unresolved_threads | tostring) else "\u2014" end) +
    " | " + yn(.has_approve_label) +
    " | **" + .action + "** |"
  ),
  ""
] | .[]

JQTABLE

# ── Output ────────────────────────────────────────────────────────────────────
if [[ "$OUTPUT_JSON" == "true" ]]; then
  echo "$RESULT"
else
  echo "$RESULT" | jq -r --arg owner "$OWNER" --arg repo "$REPO" "$JQ_TABLE"
fi
