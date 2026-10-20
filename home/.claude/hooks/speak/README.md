# speak

Reads the SUMMARY of each Claude reply aloud with [Kokoro](https://github.com/thewh1teagle/kokoro-onnx), per session. macOS only (`afplay`), and needs `uv` and `jq`.

## Use

- `/speak on` turns speech on for the current session, `/speak off` turns it off and stops playback, `/speak status` reports.
- Sending your next prompt stops speech in progress for that session.
- While on, a `UserPromptSubmit` hook asks Claude to write every reply as `SUMMARY:` (spoken, 2-3 sentences) then `DETAILS:` (read on screen). A reply without a `SUMMARY:` marker speaks its first 600 characters.

## Files

- `speak-toggle.sh`: backs the `/speak` skill; owns the per-session flag `~/.claude/tts/<session_id>`.
- `speak-context.sh`: `UserPromptSubmit` hook that injects the SUMMARY/DETAILS instruction.
- `speak-response.sh`: `Stop` hook; plays a chime at once (`SPEAK_CHIME` overrides the sound), then launches `speak-response.py` in the background.
- `speak-response.py`: cleans the text for speech, synthesizes it, and plays it. Tunables (`VOICE`, `SPEED`, `MAX_CHARS`) sit at the top.
- `stop-speech.sh`: `UserPromptSubmit` hook; kills this session's playback via `~/.claude/tts/<session_id>.pid`.

## First run

`/speak on` downloads about 350MB of model files to `~/.cache/kokoro-onnx/` in the background. Speech stays silent until that finishes. Behind a TLS-intercepting proxy, `SSL_CERT_FILE` must point at a bundle that includes the proxy's CA.
