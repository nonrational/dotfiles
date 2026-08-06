#!/usr/bin/env python3

import re
import sys
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError:
    sys.exit("[error] PyYAML is required: python3 -m pip install PyYAML")


def is_delimiter(line: str) -> bool:
    return re.fullmatch(r"---[ \t]*(?:\r?\n)?", line) is not None


skills_root = Path(sys.argv[1] if len(sys.argv) > 1 else "home/.agents/skills")
skill_files = sorted(skills_root.glob("*/SKILL.md"))

if not skill_files:
    sys.exit(f"[error] no SKILL.md files found under {skills_root}")

failed = False

for path in skill_files:
    lines = path.read_text().splitlines(keepends=True)

    if not lines or not is_delimiter(lines[0]):
        print(
            f"[error] {path}:1: YAML frontmatter must start with ---",
            file=sys.stderr,
        )
        failed = True
        continue

    closing_index = next(
        (index for index, line in enumerate(lines[1:], start=1) if is_delimiter(line)),
        None,
    )
    if closing_index is None:
        print(
            f"[error] {path}: YAML frontmatter is missing its closing ---",
            file=sys.stderr,
        )
        failed = True
        continue

    frontmatter = "".join(lines[1:closing_index])

    try:
        yaml.compose(frontmatter)
    except yaml.YAMLError as error:
        mark = getattr(error, "problem_mark", None)
        problem = getattr(error, "problem", str(error))
        location = (
            f":{mark.line + 1}:{mark.column + 1}" if mark is not None else ""
        )
        print(f"[error] {path}{location}: {problem}", file=sys.stderr)
        failed = True

if failed:
    sys.exit(1)

print("all skill YAML frontmatter parses")
