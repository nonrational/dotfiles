#!/usr/bin/env bash
# Stops this session's spoken reply, if one is playing. Runs as the
# UserPromptSubmit hook (session id from the hook JSON on stdin) and as a
# helper for speak-response.sh and speak-toggle.sh (session id as $1).
set -u

session_id="${1:-}"
if [[ -z "$session_id" ]]; then
  input=$(cat)
  session_id=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
  # A subagent hand-back reaches this hook as a prompt, but the user did not
  # speak, so the reply being read aloud keeps playing.
  [[ "$(jq -r '.prompt // empty' <<<"$input" 2>/dev/null)" == "<agent-message"* ]] && exit 0
fi
case "$session_id" in "" | *[!A-Za-z0-9-]*) exit 0 ;; esac

pidfile="${HOME}/.claude/tts/${session_id}.pid"
[[ -f "$pidfile" ]] || exit 0
pid=$(<"$pidfile")
rm -f "$pidfile"
[[ "$pid" =~ ^[0-9]+$ ]] || exit 0

# The pidfile can outlive its process, and the OS recycles PIDs.
ps -o command= -p "$pid" 2>/dev/null | grep -q 'speak-response' || exit 0

descendants() {
  local child
  for child in $(pgrep -P "$1" 2>/dev/null); do
    echo "$child"
    descendants "$child"
  done
}

# Collect first, kill the parent next: a dead parent reparents its children
# to launchd, where pgrep -P can no longer find them, and a live parent can
# still spawn the next afplay.
victims=$(descendants "$pid")
kill "$pid" 2>/dev/null
# shellcheck disable=SC2086
[[ -n "$victims" ]] && kill $victims 2>/dev/null

# Explicit: a failed kill must never block the prompt.
exit 0
