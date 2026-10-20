#!/usr/bin/env bash
# Stop hook: reads the SUMMARY of Claude's reply aloud with Kokoro (speak-response.py).
#
# Opt-in per session via /speak on (flag: ~/.claude/tts/<session_id>). Without
# the flag this no-ops, so hosts that redeploy this repo unattended (no
# speakers, no model cache) stay silent.
set -u

input=$(cat)

session_id=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
case "$session_id" in "" | *[!A-Za-z0-9-]*) exit 0 ;; esac
[[ -f "${HOME}/.claude/tts/${session_id}" ]] || exit 0
command -v afplay >/dev/null 2>&1 || exit 0
command -v uv >/dev/null 2>&1 || exit 0

text=$(jq -r '.last_assistant_message // empty' <<<"$input" 2>/dev/null)
if [[ -z "$text" ]]; then
  transcript=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null)
  [[ -f "${transcript:-}" ]] || exit 0
  text=$(tail -n 50 "$transcript" | jq -rs '
    [.[] | select(.type == "assistant")] | last
    | [.message.content[]? | select(.type == "text") | .text] | join(" ")' 2>/dev/null)
fi
[[ -z "$text" || "$text" == "null" ]] && exit 0

here="$(dirname "$0")"

# A new reply from this session replaces one still playing.
"$here/stop-speech.sh" "$session_id" </dev/null

# Instant feedback while the voice model loads and synthesizes. Fire and
# forget: the Funk file is 2s long but audible for under 1s, and Python
# startup alone outlasts that, so the speech never lands on the chime.
chime="${SPEAK_CHIME:-/System/Library/Sounds/Funk.aiff}"
[[ -f "$chime" ]] && afplay "$chime" >/dev/null 2>&1 &

# Detached: synthesis takes seconds, and the stop must not wait on it.
nohup "$here/speak-response.py" <<<"$text" >/dev/null 2>&1 &
echo $! > "${HOME}/.claude/tts/${session_id}.pid"

# Explicit: a failed launch must never block the stop.
exit 0
