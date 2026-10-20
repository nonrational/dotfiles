#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10,<3.13"
# dependencies = ["kokoro-onnx", "soundfile"]
# ///
"""Reads a reply aloud with Kokoro, then plays it with afplay.

Reads the reply on stdin and speaks its SUMMARY section. `--fetch` downloads
the model files and exits.

Pinned below 3.13 because onnxruntime wheels trail new CPython releases.
"""
import os
import re
import signal
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

import soundfile as sf
from kokoro_onnx import Kokoro

RELEASE = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
MODEL_DIR = Path.home() / ".cache" / "kokoro-onnx"
MODEL_FILES = ("kokoro-v1.0.onnx", "voices-v1.0.bin")
VOICE = "af_heart"
SPEED = 1.5

# Long replies are tedious to hear in full and slow to synthesize. Cut at a
# sentence boundary so the audio does not stop mid-thought.
MAX_CHARS = 600

# Bounds the text the regexes below ever see; a pasted blob must not stall them.
MAX_INPUT_CHARS = 20000

EXTENSIONS = "py|sh|md|json|js|ts|tsx|jsx|ex|exs|rb|go|rs|yml|yaml|toml|txt|html|css|sql|lock|env|cfg|conf"
FILE = re.compile(rf"^(?P<name>[\w.-]*)\.(?P<ext>{EXTENSIONS})(?::(?P<line>\d+)(?:-\d+)?)?$")
SUMMARY = re.compile(
    r"^[\s*#>_-]*SUMMARY[*_]*[ \t]*:[*_]*[ \t]*(.*?)(?=^[\s*#>_-]*DETAILS[*_]*[ \t]*:|\Z)",
    re.M | re.S,
)
ABBREVIATIONS = ((r"\be\.g\.", "for example"), (r"\bi\.e\.", "that is"), (r"\betc\.", "and so on"), (r"\bvs\.", "versus"))


def fetch(name: str) -> None:
    path = MODEL_DIR / name
    if path.exists():
        return
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    # Per-process part file: two concurrent fetches must not interleave writes.
    part = path.with_name(f"{name}.{os.getpid()}.part")
    try:
        urllib.request.urlretrieve(f"{RELEASE}/{name}", part)
        os.replace(part, path)
    finally:
        part.unlink(missing_ok=True)


def spoken_token(match: re.Match) -> str:
    token = match.group(0)
    lead = token[: len(token) - len(token.lstrip("(\"'["))]
    body = token[len(lead):]
    core = body.rstrip(".,;:!?)\"']")
    tail = body[len(core):]
    segments = [s for s in core.split("/") if s]
    last = segments[-1] if segments else ""

    file = FILE.match(last)
    if file:
        name = file["name"].replace(".", " dot ")
        spoken = f"{name} dot {file['ext']}".strip()
        if file["line"]:
            spoken = f"line {file['line']} of {spoken}"
        return f"{lead}{spoken}{tail}"

    # Dates and fractions also contain slashes; a numeric last segment is not a folder.
    is_path = core.startswith(("/", "~", "./", "../")) or core.count("/") >= 2 or core.endswith("/")
    if is_path and last and not last.isdigit():
        return f"{lead}{last.replace('.', ' dot ')} folder{tail}"
    return token


def speakable(text: str) -> str:
    text = text[:MAX_INPUT_CHARS]
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    text = re.sub(r"```.*", " ", text, flags=re.S)
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    # Keeps the sentence's closing punctuation, which \S+ would swallow.
    text = re.sub(r"https?://[^\s)]*[^\s).,;:!?]", "a link", text)
    text = re.sub(r"^\s*[-=_*]{3,}\s*$", " ", text, flags=re.M)
    text = re.sub(r"^\s*(#+|[-*>]|\d+\.)\s+", "", text, flags=re.M)
    text = re.sub(r"\*{1,3}(?=\S)(.+?)(?<=\S)\*{1,3}", r"\1", text)
    text = re.sub(r"(?<!\w)_{1,2}(?=\S)(.+?)(?<=\S)_{1,2}(?!\w)", r"\1", text)
    text = re.sub(r"[|~]", " ", text)

    # List items carry no terminator, so without one a list reads as a single run-on.
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    text = " ".join(line if line[-1] in ".!?:;," else line + "." for line in lines)

    text = re.sub(r"\S+", spoken_token, text)
    for pattern, spoken in ABBREVIATIONS:
        text = re.sub(pattern, spoken, text)
    # The phonemizer reads the dot in "0.7" as a sentence break.
    text = re.sub(r"(?<=\d)\.(?=\d)", " point ", text)
    text = text.replace("_", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return re.sub(r"\s+([.,;:!?])", r"\1", text)


def spoken_part(reply: str) -> str:
    match = SUMMARY.search(reply[:MAX_INPUT_CHARS])
    return match.group(1) if match else reply


def trim(text: str) -> str:
    if len(text) <= MAX_CHARS:
        return text
    cut = text[:MAX_CHARS]
    end = max(cut.rfind(". "), cut.rfind("? "), cut.rfind("! "))
    return cut[: end + 1] if end > 0 else cut


def synthesize(kokoro: Kokoro, text: str, wav: Path) -> bool:
    # The phonemizer rejects text with nothing pronounceable (e.g. "---").
    if not re.search(r"\w", text):
        return False
    # At speeds above about 1.2 the model swallows the first word of an
    # utterance; a leading ellipsis gives it a pause to absorb instead. Also
    # trim=True would cut soft openings ("I", "Ch") with the leading silence.
    samples, rate = kokoro.create(f"... {text}", voice=VOICE, speed=SPEED, lang="en-us", trim=False)
    sf.write(wav, samples, rate)
    return True


def main() -> None:
    if "--fetch" in sys.argv:
        for name in MODEL_FILES:
            fetch(name)
        return

    # Never download here: the next prompt kills this process, and a killed
    # download restarts from zero. /speak on starts the fetch instead.
    model, voices = (MODEL_DIR / name for name in MODEL_FILES)
    if not (model.exists() and voices.exists()):
        return

    text = trim(speakable(spoken_part(sys.stdin.read())))
    if not text:
        return

    # Default SIGTERM skips the temp-dir cleanup below.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    kokoro = Kokoro(str(model), str(voices))

    # speak-response.sh plays a chime at launch to cover this wait. Synthesizing
    # only the first sentence before playing, then the remainder while it plays,
    # keeps the gap after the chime independent of the summary's length.
    parts = re.split(r"(?<=[.!?])\s+", text, maxsplit=1)
    first, rest = parts[0], (parts[1] if len(parts) > 1 else "")

    with tempfile.TemporaryDirectory(prefix="speak-") as tmp:
        first_wav, rest_wav = Path(tmp) / "first.wav", Path(tmp) / "rest.wav"
        if not synthesize(kokoro, first, first_wav):
            return
        playing = subprocess.Popen(["afplay", str(first_wav)])
        rest_ready = bool(rest) and synthesize(kokoro, rest, rest_wav)
        playing.wait()
        if rest_ready:
            subprocess.run(["afplay", str(rest_wav)], check=False)


if __name__ == "__main__":
    main()
