#!/usr/bin/python3
# System interpreter on purpose: this repo pins runtimes with asdf but pins no
# python, so `env python3` dies in the asdf shim. Stdlib only; 3.9+ is fine.
"""File find-inspiration triage decisions as GitHub issues and log them durably.

Usage:
  triage-issues.py --summarize-decisions
  triage-issues.py --run RUN.json [--dry-run]

Reads a run JSON (schema in ../SKILL.md). Items decided `adopt` or `spike` become
GitHub issues; `reject` items are logged only. Every decision is appended to
decisions.jsonl next to the SKILL.md so later runs can pre-filter already-decided
ideas. Idempotent: issues dedup on a `[find-inspiration:<id>]` title marker, and a
decision identical to the latest logged one for that id is not re-appended. The
script never mutates or closes existing issues — when a decision changes, it
warns and leaves the old issue to the user.
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# Pinned because this clone has a second remote under a different owner; an
# unpinned gh could file personal triage issues in the work repo.
REPO = "nonrational/dotfiles"

SKILL_DIR = Path(__file__).resolve().parent.parent
DEFAULT_DECISIONS = SKILL_DIR / "decisions.jsonl"
MARKER_FMT = "[find-inspiration:{id}]"
VALID_DECISIONS = {"", "adopt", "spike", "reject"}
LABELS = {
    "find-inspiration": ("5319e7", "Idea triaged via the find-inspiration skill"),
    "adopt": ("0e8a16", "Decided: adopt into this repo"),
    "spike": ("fbca04", "Decided: research spike before adopting"),
}


def gh(*args, check=True):
    try:
        result = subprocess.run(["gh", *args], capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit("gh CLI not found on PATH — install GitHub CLI first")
    if check and result.returncode != 0:
        sys.exit(f"gh {' '.join(args[:2])}... failed: {result.stderr.strip()}")
    return result.stdout


def load_decisions(path):
    """Latest decision per id (last line wins)."""
    latest = {}
    if path.exists():
        for lineno, line in enumerate(path.read_text().splitlines(), start=1):
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError as err:
                sys.exit(f"corrupt decision log {path} line {lineno}: {err}")
            latest[record["id"]] = record
    return latest


def load_run(path):
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        sys.exit(f"run file not found: {path}")
    except json.JSONDecodeError as err:
        sys.exit(f"run file {path} is not valid JSON: {err}")


def validate(run):
    problems = []
    for key in ("source_repo", "run_date", "items"):
        if key not in run:
            problems.append(f"missing top-level key: {key}")
    seen = set()
    for item in run.get("items", []):
        item_id = item.get("id", "<missing id>")
        if item_id in seen:
            problems.append(f"duplicate item id: {item_id}")
        seen.add(item_id)
        for key in ("id", "title", "kind"):
            if not item.get(key):
                problems.append(f"item {item_id}: missing {key}")
        decision = item.get("decision", "")
        if decision not in VALID_DECISIONS:
            problems.append(
                f"item {item_id}: decision {decision!r} not one of adopt/spike/reject/empty"
            )
        if decision == "reject" and not item.get("rationale"):
            problems.append(f"item {item_id}: reject requires a rationale")
    if problems:
        sys.exit("run JSON invalid:\n  " + "\n  ".join(problems))


def issue_body(item, run):
    source = item.get("source") or run["source_repo"]
    meta = [
        f"**Kind:** {item['kind']} \\",
        f"**Effort:** {item.get('effort', '?')} · **Risk:** {item.get('risk', '?')} \\",
        f"**Source:** {source} (run {run['run_date']}) \\",
        f"**Decision:** {item['decision']}",
    ]
    sections = [
        ("Problem", "problem"),
        ("Current state (this repo)", "you"),
        ("Their approach", "them"),
        ("Difference that matters", "difference"),
        ("Translation into this repo", "translation"),
        ("Pilot slice", "pilot"),
        ("Spike question", "spike_question"),
    ]
    parts = ["\n".join(meta)]
    for heading, key in sections:
        if item.get(key):
            parts.append(f"## {heading}\n\n{item[key]}")
    return "\n\n".join(parts) + "\n"


def fetch_issues():
    """All issues once, matched client-side — gh's --search index lags fresh
    issues, which would break dedup on an immediate re-run."""
    out = gh("issue", "list", "-R", REPO, "--state", "all",
             "--json", "number,title,url", "--limit", "500")
    return json.loads(out or "[]")


def find_issue(issues, marker):
    for issue in issues:
        if marker in issue["title"]:
            return issue
    return None


def ensure_labels(names):
    listed = gh("label", "list", "-R", REPO, "--json", "name", "--limit", "200")
    have = {label["name"] for label in json.loads(listed or "[]")}
    for name in names:
        if name not in have:
            color, description = LABELS[name]
            gh("label", "create", name, "-R", REPO,
               "--color", color, "--description", description)


def append_record(path, record):
    with path.open("a") as f:
        f.write(json.dumps(record) + "\n")


def cmd_run(run_path, decisions_path, dry_run):
    run = load_run(run_path)
    validate(run)
    logged = load_decisions(decisions_path)

    decided = [item for item in run["items"] if item.get("decision")]
    untriaged = [item for item in run["items"] if not item.get("decision")]
    actionable = [item for item in decided if item["decision"] in ("adopt", "spike")]

    # A rejects-only triage needs no gh at all, so it can run offline.
    issues = fetch_issues() if actionable else []
    if actionable and not dry_run:
        ensure_labels({"find-inspiration"} | {item["decision"] for item in actionable})

    would_log = 0
    for item in decided:
        decision = item["decision"]
        marker = MARKER_FMT.format(id=item["id"])
        prior = logged.get(item["id"])
        issue_url = None

        if decision in ("adopt", "spike"):
            existing = find_issue(issues, marker)
            if existing:
                issue_url = existing["url"]
                print(f"SKIP    {item['id']}: issue #{existing['number']} already exists")
                if prior and prior.get("decision") != decision:
                    print(f"WARN    {item['id']}: decision changed "
                          f"{prior['decision']} -> {decision}; issue #{existing['number']} "
                          f"keeps its old labels/body — update or close it by hand")
            elif dry_run:
                print(f"CREATE  {item['id']}: [{decision}] \"{item['title']} {marker}\"")
            else:
                issue_url = gh(
                    "issue", "create", "-R", REPO,
                    "--title", f"{item['title']} {marker}",
                    "--body", issue_body(item, run),
                    "--label", f"find-inspiration,{decision}",
                ).strip()
                print(f"CREATED {item['id']}: {issue_url}")
        else:
            print(f"LOG     {item['id']}: reject — {item.get('rationale', '')}")
            if prior and prior.get("decision") in ("adopt", "spike") and prior.get("issue_url"):
                print(f"WARN    {item['id']}: previously filed as {prior['decision']} "
                      f"({prior['issue_url']}) — close that issue by hand")

        # Append when the decision is new/changed, or to heal a missing URL
        # (e.g. a crash after issue creation left the log without it).
        needs_log = (
            not prior
            or prior.get("decision") != decision
            or (issue_url and prior.get("issue_url") != issue_url)
        )
        if not needs_log:
            print(f"        (decision '{decision}' already logged for {item['id']})")
            continue
        would_log += 1
        if not dry_run:
            # Written per item, not batched at the end, so a later gh failure
            # can't lose the decisions already carried out.
            append_record(decisions_path, {
                "id": item["id"],
                "decision": decision,
                "title": item["title"],
                "kind": item["kind"],
                "rationale": item.get("rationale", ""),
                "source_repo": item.get("source") or run["source_repo"],
                "run_date": run["run_date"],
                "issue_url": issue_url,
                "logged_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            })

    for item in untriaged:
        print(f"PASS    {item['id']}: untriaged — will resurface next run")

    if dry_run:
        print(f"\ndry-run: no issues, labels or log entries written "
              f"({would_log} decision(s) would be logged)")
    elif would_log:
        print(f"\nlogged {would_log} decision(s) to {decisions_path} — commit it")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summarize-decisions", action="store_true")
    parser.add_argument("--run", metavar="RUN.json")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--decisions-path", type=Path, default=DEFAULT_DECISIONS,
                        help="override decision log location (mainly for tests)")
    args = parser.parse_args()

    if args.summarize_decisions:
        print(json.dumps(load_decisions(args.decisions_path), indent=2))
    elif args.run:
        cmd_run(args.run, args.decisions_path, args.dry_run)
    else:
        parser.error("need --summarize-decisions or --run RUN.json")


if __name__ == "__main__":
    main()
