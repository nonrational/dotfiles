#!/usr/bin/env bash
# Stop hook: appends this session's final cost to ~/.claude/session-costs.jsonl.
# The statusline reads that log to show a month-to-date total.
set -u

input=$(cat)

cost=$(jq -r '.total_cost_usd // empty' <<<"$input" 2>/dev/null)
[[ -z "$cost" || "$cost" == "0" || "$cost" == "0.0" ]] && exit 0

session_id=$(jq -r '.session_id // ""' <<<"$input")
date_str=$(date +%Y-%m-%d)
log="${HOME}/.claude/session-costs.jsonl"

# Deduplicate: don't re-record a session that already has an entry.
# (Stop can fire more than once if a hook blocks the exit and retries.)
if [[ -n "$session_id" && -s "$log" ]] && grep -qF "\"$session_id\"" "$log" 2>/dev/null; then
    exit 0
fi

jq -nc --arg d "$date_str" --arg s "$session_id" --argjson c "$cost" \
    '{"date":$d,"session":$s,"cost":$c}' >> "$log"
