#!/usr/bin/env bash
# Stop hook: stamps the wall-clock time this turn ended. The statusline reads
# the stamp back to show how long it has been since Claude last finished.
#
# Kept separate from record-session-cost.sh on purpose: that script early-exits
# on a zero-cost or already-logged session, which is exactly when the stamp
# still needs writing.
set -u

input=$(cat)

session_id=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
[[ -z "$session_id" ]] && exit 0

# One stamp per session, not one shared file: concurrent sessions (several
# panes in the same tmux window) would otherwise overwrite each other.
dir="${HOME}/.claude/turn-end"
mkdir -p "$dir" || exit 0
date +%s > "${dir}/${session_id}"

# Stamps accumulate one per session forever otherwise.
find "$dir" -type f -mtime +7 -delete 2>/dev/null

# Explicit: a nonzero exit from find above would otherwise block the stop.
exit 0
