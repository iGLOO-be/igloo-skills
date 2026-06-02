#!/usr/bin/env bash
# Fetch Paperclip issue + spec PRD for pr-review / verify-spec.
# Spec reference: fix-prd (triage) > plan revision 1 > issue description — never plan latest for gate.
set -euo pipefail

AUTH_FILE="${PAPERCLIP_AUTH_FILE:-$HOME/.paperclip/auth.json}"
FORMAT="markdown"
SPEC_SOURCE="auto"
INCLUDE_ARCHITECT_PLAN=false

usage() {
  cat <<'EOF'
Usage: fetch-paperclip-spec.sh <issue-id> [options]

  issue-id    Paperclip identifier (e.g. IGLAA-91) or UUID

Options:
  --json | --markdown     Output format (default: markdown)
  --check-auth            Verify auth only
  --spec-source MODE      Spec reference resolution (default: auto)
                          auto       — fix-prd → plan rev 1 → issue description
                          fix-prd    — documents/fix-prd only
                          plan-rev-1 — oldest plan revision only
                          plan-latest — latest plan (implementation context, NOT spec gate)
  --include-architect-plan  Also output latest plan body (context only)

Exit codes: 0 OK | 1 auth | 2 not found | 3 API error | 4 usage
EOF
}

die() {
  echo "fetch-paperclip-spec: $*" >&2
  exit "${DIE_EXIT:-1}"
}

load_auth() {
  if [[ -n "${PAPERCLIP_API_URL:-}" && -n "${PAPERCLIP_API_KEY:-}" ]]; then
    return 0
  fi
  if [[ ! -f "$AUTH_FILE" ]]; then
    die "Auth Paperclip manquante — exécuter: pnpm paperclipai auth login (voir paperclip-operator skill)"
  fi
  if [[ -z "${PAPERCLIP_API_URL:-}" ]]; then
    local key_count
    key_count="$(jq -r '.credentials | keys | length' "$AUTH_FILE")"
    if [[ "$key_count" -eq 1 ]]; then
      PAPERCLIP_API_URL="$(jq -r '.credentials | keys[0]' "$AUTH_FILE")"
    else
      die "PAPERCLIP_API_URL non défini — instances: $(jq -r '.credentials | keys | join(", ")' "$AUTH_FILE")"
    fi
  fi
  PAPERCLIP_API_KEY="$(jq -r --arg base "$PAPERCLIP_API_URL" \
    '.credentials[$base].token // .credentials[($base + "/")].token // empty' "$AUTH_FILE")"
  if [[ -z "$PAPERCLIP_API_KEY" ]]; then
    die "Token Paperclip introuvable pour $PAPERCLIP_API_URL"
  fi
  export PAPERCLIP_API_URL PAPERCLIP_API_KEY
}

api_get() {
  local path="$1"
  local allow_404="${2:-false}"
  local tmp http_code
  tmp="$(mktemp)"
  http_code="$(curl -sS -o "$tmp" -w "%{http_code}" \
    "${PAPERCLIP_API_URL}/api/${path}" \
    -H "Authorization: Bearer ${PAPERCLIP_API_KEY}" \
    -H "Content-Type: application/json" 2>"$tmp.curlerr" || true)"
  if [[ ! -s "$tmp.curlerr" || -s "$tmp" ]]; then :; else
    DIE_EXIT=3 die "Erreur réseau Paperclip: $(cat "$tmp.curlerr")"
  fi
  rm -f "$tmp.curlerr"
  if [[ "$http_code" == "401" || "$http_code" == "403" ]]; then
    rm -f "$tmp"
    DIE_EXIT=1 die "Auth Paperclip refusée (HTTP $http_code)"
  fi
  if [[ "$http_code" == "404" ]]; then
    rm -f "$tmp"
    if [[ "$allow_404" == "true" ]]; then return 1; fi
    DIE_EXIT=2 die "Ressource introuvable (HTTP 404): /api/${path}"
  fi
  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    local snippet
    snippet="$(head -c 200 "$tmp" | tr '\n' ' ')"
    rm -f "$tmp"
    DIE_EXIT=3 die "Erreur API Paperclip (HTTP $http_code): ${snippet}"
  fi
  cat "$tmp"
  rm -f "$tmp"
}

check_auth() {
  load_auth
  api_get "companies" >/dev/null
  echo "Paperclip OK — $PAPERCLIP_API_URL" >&2
}

# Outputs JSON object for spec reference: {type, key, revisionNumber, title, body} or empty
resolve_fix_prd() {
  local issue_id="$1"
  local doc
  if ! doc="$(api_get "issues/${issue_id}/documents/fix-prd" true)"; then return 1; fi
  echo "$doc" | jq '{
    type: "fix-prd",
    key: "fix-prd",
    revisionNumber: (.latestRevisionNumber // null),
    title: (.title // "Fix PRD"),
    body: (.body // "")
  }'
}

resolve_plan_rev_1() {
  local issue_id="$1"
  local revs
  if ! revs="$(api_get "issues/${issue_id}/documents/plan/revisions" true)"; then return 1; fi
  if [[ "$(echo "$revs" | jq 'length')" -eq 0 ]]; then return 1; fi
  echo "$revs" | jq 'min_by(.revisionNumber) | {
    type: "plan-rev-1",
    key: "plan",
    revisionNumber: .revisionNumber,
    title: (.title // "Plan"),
    body: (.body // "")
  }'
}

resolve_plan_latest() {
  local issue_id="$1"
  local doc
  if ! doc="$(api_get "issues/${issue_id}/documents/plan" true)"; then return 1; fi
  echo "$doc" | jq '{
    type: "plan-latest",
    key: "plan",
    revisionNumber: (.latestRevisionNumber // null),
    title: (.title // "Plan"),
    body: (.body // "")
  }'
}

resolve_issue_description() {
  local issue_json="$1"
  local body
  body="$(echo "$issue_json" | jq -r '.description // ""')"
  if [[ -z "$body" ]]; then return 1; fi
  jq -n --arg body "$body" '{
    type: "issue-description",
    key: null,
    revisionNumber: null,
    title: "Issue description",
    body: $body
  }'
}

resolve_spec_auto() {
  local issue_id="$1" issue_json="$2"
  local spec=""
  if spec="$(resolve_fix_prd "$issue_id")"; then echo "$spec"; return 0; fi
  if spec="$(resolve_plan_rev_1 "$issue_id")"; then echo "$spec"; return 0; fi
  if spec="$(resolve_issue_description "$issue_json")"; then echo "$spec"; return 0; fi
  echo 'null'
}

resolve_spec() {
  local issue_id="$1" issue_json="$2"
  case "$SPEC_SOURCE" in
    auto) resolve_spec_auto "$issue_id" "$issue_json" ;;
    fix-prd)
      resolve_fix_prd "$issue_id" || echo 'null'
      ;;
    plan-rev-1)
      resolve_plan_rev_1 "$issue_id" || echo 'null'
      ;;
    plan-latest)
      resolve_plan_latest "$issue_id" || echo 'null'
      ;;
    *)
      DIE_EXIT=4 die "spec-source invalide: $SPEC_SOURCE"
      ;;
  esac
}

fetch_spec() {
  local issue_id="$1"
  load_auth

  local issue_json spec_json architect_json='null'
  issue_json="$(api_get "issues/${issue_id}")"
  spec_json="$(resolve_spec "$issue_id" "$issue_json")"

  if [[ "$INCLUDE_ARCHITECT_PLAN" == true ]]; then
    architect_json="$(resolve_plan_latest "$issue_id" || echo 'null')"
  elif [[ "$(echo "$spec_json" | jq -r '.type // empty')" != "plan-latest" ]]; then
    # Always expose latest plan metadata (not body) when it differs from spec ref
    local latest_meta
    if latest_meta="$(api_get "issues/${issue_id}/documents/plan" true)"; then
      architect_json="$(echo "$latest_meta" | jq '{
        type: "plan-latest",
        key: "plan",
        revisionNumber: (.latestRevisionNumber // null),
        title: (.title // "Plan"),
        body: null,
        note: "implementation context only — not used for spec gate"
      }')"
    fi
  fi

  if [[ "$FORMAT" == "json" ]]; then
    jq -n \
      --arg apiUrl "$PAPERCLIP_API_URL" \
      --argjson issue "$issue_json" \
      --argjson specReference "$spec_json" \
      --argjson architectPlan "$architect_json" \
      --arg specSourceMode "$SPEC_SOURCE" \
      '{
        apiUrl: $apiUrl,
        specSourceMode: $specSourceMode,
        issue: $issue,
        specReference: $specReference,
        architectPlan: (if $architectPlan == null then null else $architectPlan end),
        specGateRule: "Never use plan-latest for conformance — use specReference only"
      }'
    return 0
  fi

  local identifier title description status prefix board_url
  identifier="$(echo "$issue_json" | jq -r '.identifier // .id')"
  title="$(echo "$issue_json" | jq -r '.title // "Sans titre"')"
  description="$(echo "$issue_json" | jq -r '.description // ""')"
  status="$(echo "$issue_json" | jq -r '.status // "unknown"')"
  prefix="${identifier%%-*}"
  board_url="${PAPERCLIP_API_URL}/${prefix}/issues/${identifier}"

  local spec_type spec_rev spec_body spec_title
  spec_type="$(echo "$spec_json" | jq -r '.type // "absent"')"
  spec_rev="$(echo "$spec_json" | jq -r '.revisionNumber // "n/a"')"
  spec_title="$(echo "$spec_json" | jq -r '.title // ""')"
  spec_body="$(echo "$spec_json" | jq -r '.body // ""')"

  cat <<EOF
# Paperclip ${identifier} — ${title}

- **Board**: ${board_url}
- **Status**: ${status}
- **Spec reference**: ${spec_type} (rev ${spec_rev}) — _used for conformance gate_
- **Architect plan**: $(echo "$architect_json" | jq -r 'if . == null then "unknown" else "plan rev \(.revisionNumber) — not used for spec gate" end')

## Issue description

${description:-_(vide)_}

## Spec PRD (référence conformité)

EOF

  if [[ -n "$spec_body" && "$spec_type" != "absent" && "$spec_type" != "null" ]]; then
    printf '%s\n' "$spec_body"
  else
    echo "_(absent — aucun fix-prd, plan rev 1, ni description utilisable)_"
  fi

  if [[ "$INCLUDE_ARCHITECT_PLAN" == true ]]; then
    local arch_body
    arch_body="$(echo "$architect_json" | jq -r '.body // ""')"
    cat <<EOF

## Plan architecte (contexte implémentation — NON gate spec)

EOF
    if [[ -n "$arch_body" ]]; then
      printf '%s\n' "$arch_body"
    else
      echo "_(absent)_"
    fi
  fi
}

ISSUE_ID=""
CHECK_AUTH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) FORMAT="json" ;;
    --markdown) FORMAT="markdown" ;;
    --check-auth) CHECK_AUTH=true ;;
    --include-architect-plan) INCLUDE_ARCHITECT_PLAN=true ;;
    --spec-source)
      SPEC_SOURCE="$2"
      shift 2
      continue
      ;;
    -h | --help) usage; exit 0 ;;
    -*)
      DIE_EXIT=4 die "Option inconnue: $1"
      ;;
    *)
      if [[ -n "$ISSUE_ID" ]]; then DIE_EXIT=4 die "Un seul issue-id attendu"; fi
      ISSUE_ID="$1"
      ;;
  esac
  shift
done

if [[ "$CHECK_AUTH" == true ]]; then
  check_auth
  exit 0
fi

if [[ -z "$ISSUE_ID" ]]; then
  usage
  DIE_EXIT=4 die "issue-id requis"
fi

fetch_spec "$ISSUE_ID"
