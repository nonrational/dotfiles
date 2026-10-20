---
name: speak
description: Turn spoken replies on or off for this session. Use as /speak on, /speak off, or /speak status.
argument-hint: "on | off | status"
disable-model-invocation: true
allowed-tools: Bash(~/.claude/hooks/speak/speak-toggle.sh *)
---

!`~/.claude/hooks/speak/speak-toggle.sh "$ARGUMENTS" "${CLAUDE_SESSION_ID}"`

Relay the line above to the user verbatim and stop. Do not add commentary.
