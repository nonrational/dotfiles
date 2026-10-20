#!/usr/bin/env bash
# UserPromptSubmit hook: while /speak is on for this session, asks Claude to
# split each reply into a spoken SUMMARY and a read DETAILS. Re-injected every
# turn rather than said once, because a one-time instruction fades as the
# context grows or compacts.
set -u

input=$(cat)

session_id=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
case "$session_id" in "" | *[!A-Za-z0-9-]*) exit 0 ;; esac
flag="${HOME}/.claude/tts/${session_id}"
[[ -f "$flag" ]] || exit 0

# speak-toggle.sh expires flags by age; a session in use must keep its own fresh.
touch "$flag" 2>/dev/null

jq -n '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext:
  "Spoken-reply mode is on. Format every reply as two parts. First a line reading SUMMARY: followed by two or three sentences of plain spoken prose: the outcome, then anything the user must decide or do. The summary is read aloud by a text-to-speech voice, so it has no lists, tables, code, markdown or directory paths; write file names and numbers the way a person would say them. Then a line reading DETAILS: followed by the full answer in normal formatting. Only the summary is spoken."}}'
exit 0
