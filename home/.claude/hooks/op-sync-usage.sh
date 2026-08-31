#!/usr/bin/env bash
# Stop hook: cache Claude plan usage from 1Password-authenticated web endpoint.
# Statusline rendering must stay local because it runs far more often than turns end.
set -u

verbose=false
if [[ "${1:-}" == "-v" ]]; then
  verbose=true
  shift
fi
if [[ $# -ne 0 ]]; then
  printf 'Usage: %s [-v]\n' "${0##*/}" >&2
  exit 2
fi

fail() {
  if "$verbose"; then
    printf 'Claude usage sync: %s\n' "$1" >&2
    exit 1
  fi
  exit 0
}

config="${HOME}/.claude/.statusline.local"
cache="${HOME}/.claude/cache/usage.json"

[[ -r "$config" ]] || fail "missing ${config}"
# shellcheck disable=SC1090
source "$config"

if [[ -r "$cache" ]]; then
  fetched_at=$(jq -r '.fetched_at // empty' "$cache" 2>/dev/null)
  if [[ "$fetched_at" =~ ^[0-9]+$ ]] && (( $(date +%s) - fetched_at < 900 )); then
    "$verbose" && printf 'Claude usage sync: cache is less than 15 minutes old\n'
    exit 0
  fi
fi

command -v op >/dev/null 2>&1 || fail "1Password CLI (op) is not installed"

# 1Password supplies both endpoint values, so neither persists under ~/.claude.
organization_id=$(op read 'op://Private/claude.ai_statusline/username' 2>/dev/null) || fail "cannot read organization ID from 1Password"
cookies=$(op read 'op://Private/claude.ai_statusline/password' 2>/dev/null) || fail "cannot read cookies from 1Password"
[[ -n "$organization_id" ]] || fail "organization ID is empty"
[[ -n "$cookies" ]] || fail "cookies are empty"

mkdir -p "${cache%/*}" || fail "cannot create cache directory"
tmp="$(mktemp "${cache}.XXXXXX")" || fail "cannot create temporary cache file"
trap 'rm -f "$tmp"' EXIT

response=$(curl --silent --show-error --fail --max-time 5 \
  --header "Accept: application/json" \
  --header "Referer: https://claude.ai/new" \
  --header "anthropic-client-platform: web_claude_ai" \
  --header "Cookie: ${cookies}" \
  "https://claude.ai/api/organizations/${organization_id}/usage" 2>&1) || fail "request failed: ${response}"

# Do not replace the last known good value if the endpoint's schema or session changes.
# `spend.percent` matches Claude's total plan-usage meter. `nimbus_quill` is the
# separate rolling five-hour window and can correctly remain at zero.
usage_percent=$(jq -r '.spend.percent // empty' <<<"$response" 2>/dev/null)
[[ "$usage_percent" =~ ^[0-9]+([.][0-9]+)?$ ]] || fail "response did not contain spend.percent"

jq -nc --argjson fetched_at "$(date +%s)" --argjson usage_percent "$usage_percent" --argjson usage "$response" \
  '{fetched_at:$fetched_at, usage_percent:$usage_percent, usage:$usage}' > "$tmp" || fail "cannot write cache"
mv "$tmp" "$cache" || fail "cannot replace cache"
if "$verbose"; then
  printf 'Claude usage sync: cached plan usage at %.0f%%\n' "$usage_percent"
fi
exit 0
