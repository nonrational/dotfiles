#!/usr/bin/env bash
# Backs the /speak skill. Usage: <on|off|status> <session_id>
set -u

read -r action _ <<<"${1:-status}"
action="${action:-status}"
session_id="${2:-}"
dir="${HOME}/.claude/tts"
flag="${dir}/${session_id}"
here="$(dirname "$0")"
model_dir="${HOME}/.cache/kokoro-onnx"

# The id becomes a file name, so anything but the harness's UUID shape is refused.
case "$session_id" in
  "" | *[!A-Za-z0-9-]*) echo "Speech: no valid session id available."; exit 0 ;;
esac

case "$action" in
  on)
    if ! { mkdir -p "$dir" && touch "$flag"; }; then
      echo "Speech: could not write ${flag}."
      exit 0
    fi
    find "$dir" -type f -mtime +7 -delete 2>/dev/null
    notes=""
    if ! { command -v afplay >/dev/null 2>&1 && command -v uv >/dev/null 2>&1; }; then
      notes+=" Nothing will play here: afplay (macOS) and uv are required."
    fi
    if [[ ! -f "${model_dir}/kokoro-v1.0.onnx" || ! -f "${model_dir}/voices-v1.0.bin" ]]; then
      pgrep -f 'speak-response\.py --fetch' >/dev/null 2>&1 \
        || nohup "$here/speak-response.py" --fetch >/dev/null 2>&1 &
      notes+=" Downloading the voice model (about 350MB); speech starts once it finishes."
    fi
    echo "Speech on for this session. Replies will have a spoken SUMMARY and a DETAILS section.${notes}"
    ;;
  off)
    rm -f "$flag"
    "$here/stop-speech.sh" "$session_id" </dev/null
    echo "Speech off for this session."
    ;;
  status)
    [[ -f "$flag" ]] && echo "Speech is on for this session." || echo "Speech is off for this session."
    ;;
  *)
    echo "Usage: /speak on | off | status"
    ;;
esac
exit 0
