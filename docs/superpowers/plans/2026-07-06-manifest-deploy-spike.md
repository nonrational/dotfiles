# Manifest-Driven Deploy Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a declarative `manifest` + a small `deploy.sh` driver (apply, `--dry-run`, audit, backup-on-conflict) that reaches parity with `link-dotfiles.sh` for `bin.*` and `.bashrc.nyx`, answering the spike question in https://github.com/nonrational/dotfiles/issues/6.

**Architecture:** One ~100-line bash driver reads a three-column whitespace-separated manifest at the repo root, validates every line before acting, then reconciles each condition-matched entry to a symlink. A self-contained bash test suite runs the driver against a sandboxed copy (its own repo dir + fake `$HOME` under `mktemp -d`), so tests never touch the real home directory.

**Tech Stack:** bash 3.2-compatible shell (macOS `/bin/bash`), BSD/GNU coreutils, git, gh.

**Spec:** `docs/superpowers/specs/2026-07-06-manifest-deploy-spike-design.md`

## Global Constraints

- Target `/bin/bash` on macOS = **bash 3.2**: arrays, `+=()`, `<<<` herestrings are fine; `mapfile`, associative arrays, `${var^^}` are not.
- **coreutils only** — no external engine, no brew dependencies. BSD userland must work: `readlink` without `-f`, `sed`, `find`, `mktemp`, `cksum`.
- Both scripts start with `set -euf -o pipefail` (matches `link-dotfiles.sh`).
- Never write `cmd | grep -q pat` (pipefail + SIGPIPE race). Grep captured variables via herestring: `grep -q pat <<<"$out"`.
- Quote every path expansion — `$HOME` and `mktemp` paths may contain spaces.
- Do NOT modify `link-dotfiles.sh` or `Makefile`.
- Manifest entries whose condition does not match are **skipped, never removed**.
- Commit messages: plain and descriptive — NO conventional-commit prefixes (`feat:`, `fix:`). Every commit message ends with these two trailer lines:
  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0117PaLyHdWjQwzFbdP34Hft
  ```
- Working directory is the worktree root: `/Users/norton/.dotfiles/.claude/worktrees/manifest-deploy-spike`. All relative paths below are relative to it.

## File Structure

- `deploy.sh` (create, Task 1; complete by Task 4) — the driver. Owns arg parsing, manifest parsing/validation, condition matching, apply and audit.
- `test_deploy.sh` (create, Task 1; grows through Task 4) — self-contained test suite. Helpers at top, one function per test, explicit runner list at the bottom. Exit 0 iff all tests pass.
- `manifest` (create, Task 5) — the pilot slice: `bin.Darwin`, `bin.Linux`, `.bashrc.nyx`.
- Findings comment on issue #6 (Task 6) — not a repo file; drafted in the scratchpad, posted with `gh` after user approval.

## Output vocabulary (fixed across all tasks)

`deploy.sh` prints exactly one line per manifest entry, first token one of:
`ok:` `link:` `relink:` `backup:` `skip:` `missing:` `drift:` — plus `error:` lines on stderr. In `--dry-run` apply, action lines (`link:`/`relink:`/`backup:`) are prefixed `would: `; `ok:` and `skip:` never are.

---

### Task 1: Driver skeleton — CLI parsing and manifest validation

**Files:**
- Create: `deploy.sh`
- Create: `test_deploy.sh`

**Interfaces:**
- Consumes: nothing (first task).
- Produces:
  - `deploy.sh [--dry-run] [apply|audit]` CLI contract: unknown arg → usage on stderr, exit 2; validation failure → `error: …` on stderr, exit 1. Globals `dry_run` (0/1), `mode` (`apply`|`audit`), `DOTS` (script's own dir), `MANIFEST` (`$DOTS/manifest`).
  - `parse_manifest()` — fills parallel arrays `sources`, `targets`, `conditions` (condition may be empty string); exits 1 on: missing manifest, <2 or >3 columns, condition not `os=<val>`/`host=<val>`, missing source file, zero entries. Validates ALL lines before anything acts.
  - Test harness globals/helpers: `ROOT`, `BASE`, `sandbox()` (sets `SB`, `REPO`, `FAKEHOME`; copies `deploy.sh` into `$REPO`; creates source fixtures `rc` file and `bin.any/` dir; does NOT create a manifest), `deploy()` (runs `$REPO/deploy.sh` with `HOME="$FAKEHOME"`, sets `out` and `status`), `ok()`/`bad()` counters, runner that prints `N passed, M failed` and exits non-zero on any failure.

- [ ] **Step 1: Write the failing test file**

Create `test_deploy.sh` with exactly this content:

```bash
#!/bin/bash
# Tests for deploy.sh. Each test runs against a sandboxed repo copy and a
# fake $HOME under mktemp, so nothing here touches the real home directory.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-deploy.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

pass=0
fail=0
sb_count=0

ok()  { pass=$((pass + 1)); echo "PASS: $1"; }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

# Fresh sandbox: $REPO holds deploy.sh + source fixtures; $FAKEHOME is $HOME.
# Tests write their own manifest into $REPO.
sandbox() {
    sb_count=$((sb_count + 1))
    SB="$BASE/$sb_count"
    REPO="$SB/repo"
    FAKEHOME="$SB/home"
    mkdir -p "$REPO" "$FAKEHOME"
    cp "$ROOT/deploy.sh" "$REPO/deploy.sh"
    echo "content-rc" > "$REPO/rc"
    mkdir "$REPO/bin.any"
    echo "content-tool" > "$REPO/bin.any/tool"
}

# Run the sandboxed deploy.sh; capture combined output in $out, exit in $status.
deploy() {
    set +e
    out="$(HOME="$FAKEHOME" "$REPO/deploy.sh" "$@" 2>&1)"
    status=$?
    set -e
}

test_rejects_unknown_flag() {
    sandbox
    printf 'rc\t~/.rc\n' > "$REPO/manifest"
    deploy --bogus
    if [ "$status" = 2 ] && grep -q "usage:" <<<"$out"; then
        ok "unknown flag exits 2 with usage"
    else
        bad "unknown flag exits 2 with usage (status=$status, out=$out)"
    fi
}

test_rejects_missing_manifest() {
    sandbox
    deploy apply
    if [ "$status" = 1 ] && grep -q "manifest not found" <<<"$out"; then
        ok "missing manifest exits 1"
    else
        bad "missing manifest exits 1 (status=$status, out=$out)"
    fi
}

test_rejects_malformed_line() {
    sandbox
    printf 'only-one-column\n' > "$REPO/manifest"
    deploy apply
    if [ "$status" = 1 ] && grep -q "line 1" <<<"$out"; then
        ok "one-column line exits 1 naming the line"
    else
        bad "one-column line exits 1 naming the line (status=$status, out=$out)"
    fi
}

test_rejects_extra_columns() {
    sandbox
    printf 'rc\t~/.rc\tos=Darwin\tsurprise\n' > "$REPO/manifest"
    deploy apply
    if [ "$status" = 1 ] && grep -q "line 1" <<<"$out"; then
        ok "four-column line exits 1 naming the line"
    else
        bad "four-column line exits 1 naming the line (status=$status, out=$out)"
    fi
}

test_rejects_unknown_condition() {
    sandbox
    printf 'rc\t~/.rc\tarch=arm64\n' > "$REPO/manifest"
    deploy apply
    if [ "$status" = 1 ] && grep -q "unknown condition" <<<"$out"; then
        ok "unknown condition key exits 1"
    else
        bad "unknown condition key exits 1 (status=$status, out=$out)"
    fi
}

test_rejects_missing_source() {
    sandbox
    printf 'rc\t~/.rc\nnope\t~/.nope\n' > "$REPO/manifest"
    deploy apply
    if [ "$status" = 1 ] && grep -q "does not exist" <<<"$out" \
        && [ ! -e "$FAKEHOME/.rc" ] && [ ! -L "$FAKEHOME/.rc" ]; then
        ok "missing source exits 1 before acting on valid entries"
    else
        bad "missing source exits 1 before acting on valid entries (status=$status, out=$out)"
    fi
}

test_rejects_empty_manifest() {
    sandbox
    printf '# comments only\n\n' > "$REPO/manifest"
    deploy apply
    if [ "$status" = 1 ] && grep -q "no entries" <<<"$out"; then
        ok "comment-only manifest exits 1"
    else
        bad "comment-only manifest exits 1 (status=$status, out=$out)"
    fi
}

# --- runner -----------------------------------------------------------------
test_rejects_unknown_flag
test_rejects_missing_manifest
test_rejects_malformed_line
test_rejects_extra_columns
test_rejects_unknown_condition
test_rejects_missing_source
test_rejects_empty_manifest

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

Then make it executable:

```bash
chmod +x test_deploy.sh
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./test_deploy.sh`
Expected: non-zero exit; first sandbox aborts with `cp: …/deploy.sh: No such file or directory` because `deploy.sh` does not exist yet.

- [ ] **Step 3: Write the skeleton `deploy.sh`**

Create `deploy.sh` with exactly this content:

```bash
#!/bin/bash
# Manifest-driven deploy: apply/audit symlinks declared in ./manifest.
# Spec: docs/superpowers/specs/2026-07-06-manifest-deploy-spike-design.md
set -euf -o pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$DOTS/manifest"

dry_run=0
mode=apply

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        apply | audit) mode="$1" ;;
        *)
            echo "usage: $0 [--dry-run] [apply|audit]" >&2
            exit 2
            ;;
    esac
    shift
done

sources=()
targets=()
conditions=()

parse_manifest() {
    local lineno=0 line src trg cond extra
    if [ ! -f "$MANIFEST" ]; then
        echo "error: manifest not found at $MANIFEST" >&2
        exit 1
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        line="${line%%#*}"
        if [ -z "${line//[[:space:]]/}" ]; then
            continue
        fi
        read -r src trg cond extra <<<"$line"
        if [ -z "$trg" ] || [ -n "$extra" ]; then
            echo "error: manifest line $lineno: expected 2 or 3 columns" >&2
            exit 1
        fi
        case "$cond" in
            "" | os=?* | host=?*) ;;
            *)
                echo "error: manifest line $lineno: unknown condition '$cond'" >&2
                exit 1
                ;;
        esac
        if [ ! -e "$DOTS/$src" ]; then
            echo "error: manifest line $lineno: source $DOTS/$src does not exist" >&2
            exit 1
        fi
        sources+=("$src")
        targets+=("$trg")
        conditions+=("$cond")
    done <"$MANIFEST"
    if [ "${#sources[@]}" -eq 0 ]; then
        echo "error: manifest has no entries" >&2
        exit 1
    fi
}

parse_manifest
```

(`dry_run` and `mode` are parsed but unused until Tasks 2–3; that is intentional — the CLI contract is fixed now so tests never change.)

Then make it executable:

```bash
chmod +x deploy.sh
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./test_deploy.sh`
Expected: exit 0, ending with `7 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add deploy.sh test_deploy.sh
git commit -m "$(cat <<'EOF'
Add deploy.sh skeleton with manifest validation and test harness

Parses [--dry-run] [apply|audit] and validates every manifest line
(column count, condition key, source existence) before acting.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0117PaLyHdWjQwzFbdP34Hft
EOF
)"
```

---

### Task 2: Apply mode — link, relink, condition skip, backup-on-conflict

**Files:**
- Modify: `deploy.sh` (append functions after `parse_manifest`, replace the trailing `parse_manifest` call with `main`)
- Modify: `test_deploy.sh` (append tests before the runner; extend runner)

**Interfaces:**
- Consumes: `parse_manifest` + arrays, `dry_run`/`mode` globals, harness `sandbox`/`deploy`/`ok`/`bad` (Task 1).
- Produces:
  - `condition_matches "<cond>"` — exit 0 if empty, `os=$(uname)`, or `host=` short hostname (`uname -n` minus `.lan`/`.local`); used by `main`.
  - `expand_target "<raw>"` — prints target with leading `~/` expanded to `$HOME`.
  - `apply_entry "<abs-src>" "<abs-trg>"` — reconciles one entry per the spec's state table; increments global `failures` instead of exiting when `<trg>.bak` already exists.
  - `main` — loop over entries; unmatched condition prints `skip: <raw-target> (<cond>)`; exits 1 if `failures > 0`. Task 4 extends its `case "$mode"` with an `audit` arm.

- [ ] **Step 1: Write the failing tests**

In `test_deploy.sh`, insert these functions immediately above the `# --- runner` line:

```bash
test_apply_creates_missing_link() {
    sandbox
    printf 'rc\t~/.rc\n' > "$REPO/manifest"
    deploy apply
    if [ "$status" = 0 ] && [ "$(readlink "$FAKEHOME/.rc")" = "$REPO/rc" ] \
        && grep -q "^link: " <<<"$out"; then
        ok "apply creates missing link"
    else
        bad "apply creates missing link (status=$status, out=$out)"
    fi
}

test_apply_is_idempotent() {
    sandbox
    printf 'rc\t~/.rc\n' > "$REPO/manifest"
    deploy apply
    deploy apply
    if [ "$status" = 0 ] && grep -q "^ok: " <<<"$out"; then
        ok "second apply is a no-op reported as ok"
    else
        bad "second apply is a no-op reported as ok (status=$status, out=$out)"
    fi
}

test_apply_creates_parent_dirs() {
    sandbox
    printf 'rc\t~/.config/deep/rc\n' > "$REPO/manifest"
    deploy apply
    if [ "$status" = 0 ] && [ "$(readlink "$FAKEHOME/.config/deep/rc")" = "$REPO/rc" ]; then
        ok "apply mkdir -p's missing parent dirs"
    else
        bad "apply mkdir -p's missing parent dirs (status=$status, out=$out)"
    fi
}

test_apply_relinks_wrong_symlink() {
    sandbox
    printf 'rc\t~/.rc\n' > "$REPO/manifest"
    ln -s /somewhere/else "$FAKEHOME/.rc"
    deploy apply
    if [ "$status" = 0 ] && [ "$(readlink "$FAKEHOME/.rc")" = "$REPO/rc" ] \
        && grep -q "^relink: " <<<"$out"; then
        ok "apply replaces a wrong symlink"
    else
        bad "apply replaces a wrong symlink (status=$status, out=$out)"
    fi
}

test_apply_skips_unmatched_condition() {
    sandbox
    printf 'rc\t~/.rc\tos=NoSuchOS\n' > "$REPO/manifest"
    deploy apply
    if [ "$status" = 0 ] && grep -q "^skip: " <<<"$out" \
        && [ ! -e "$FAKEHOME/.rc" ] && [ ! -L "$FAKEHOME/.rc" ]; then
        ok "unmatched condition is skipped, target untouched"
    else
        bad "unmatched condition is skipped, target untouched (status=$status, out=$out)"
    fi
}

test_apply_matches_os_and_host() {
    sandbox
    os_now="$(uname)"
    host_now="$(uname -n | sed -e 's/\.lan$//g' -e 's/\.local$//g')"
    printf 'rc\t~/.rc\tos=%s\nbin.any\t~/bin\thost=%s\n' "$os_now" "$host_now" > "$REPO/manifest"
    deploy apply
    if [ "$status" = 0 ] && [ "$(readlink "$FAKEHOME/.rc")" = "$REPO/rc" ] \
        && [ "$(readlink "$FAKEHOME/bin")" = "$REPO/bin.any" ]; then
        ok "matching os= and host= conditions are applied"
    else
        bad "matching os= and host= conditions are applied (status=$status, out=$out)"
    fi
}

test_apply_backs_up_regular_file() {
    sandbox
    printf 'rc\t~/.rc\n' > "$REPO/manifest"
    echo "precious" > "$FAKEHOME/.rc"
    deploy apply
    if [ "$status" = 0 ] && [ "$(cat "$FAKEHOME/.rc.bak")" = "precious" ] \
        && [ "$(readlink "$FAKEHOME/.rc")" = "$REPO/rc" ] \
        && grep -q "^backup: " <<<"$out"; then
        ok "regular file is backed up then linked"
    else
        bad "regular file is backed up then linked (status=$status, out=$out)"
    fi
}

test_apply_backs_up_directory() {
    sandbox
    printf 'bin.any\t~/bin\n' > "$REPO/manifest"
    mkdir "$FAKEHOME/bin"
    echo "old-tool" > "$FAKEHOME/bin/tool"
    deploy apply
    if [ "$status" = 0 ] && [ "$(cat "$FAKEHOME/bin.bak/tool")" = "old-tool" ] \
        && [ "$(readlink "$FAKEHOME/bin")" = "$REPO/bin.any" ]; then
        ok "conflicting directory is backed up then linked"
    else
        bad "conflicting directory is backed up then linked (status=$status, out=$out)"
    fi
}

test_apply_refuses_second_backup() {
    sandbox
    printf 'rc\t~/.rc\n' > "$REPO/manifest"
    echo "precious" > "$FAKEHOME/.rc"
    echo "older" > "$FAKEHOME/.rc.bak"
    deploy apply
    if [ "$status" = 1 ] && [ "$(cat "$FAKEHOME/.rc")" = "precious" ] \
        && [ "$(cat "$FAKEHOME/.rc.bak")" = "older" ] \
        && grep -q "already exists" <<<"$out"; then
        ok "existing .bak refused; target and backup untouched; exit 1"
    else
        bad "existing .bak refused; target and backup untouched; exit 1 (status=$status, out=$out)"
    fi
}
```

In the runner list, insert these calls after `test_rejects_empty_manifest`:

```bash
test_apply_creates_missing_link
test_apply_is_idempotent
test_apply_creates_parent_dirs
test_apply_relinks_wrong_symlink
test_apply_skips_unmatched_condition
test_apply_matches_os_and_host
test_apply_backs_up_regular_file
test_apply_backs_up_directory
test_apply_refuses_second_backup
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `./test_deploy.sh`
Expected: exit 1, `7 passed, 9 failed` — every new apply test fails because `deploy.sh` parses and exits without acting.

- [ ] **Step 3: Implement apply**

In `deploy.sh`, delete the final `parse_manifest` line and append exactly this in its place:

```bash
os="$(uname)"
host="$(uname -n | sed -e 's/\.lan$//g' -e 's/\.local$//g')"
failures=0

condition_matches() {
    case "$1" in
        "") return 0 ;;
        os=*) [ "${1#os=}" = "$os" ] ;;
        host=*) [ "${1#host=}" = "$host" ] ;;
    esac
}

expand_target() {
    case "$1" in
        "~/"*) printf '%s\n' "$HOME/${1#\~/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

apply_entry() {
    local src="$1" trg="$2"
    if [ -L "$trg" ] && [ "$(readlink "$trg")" = "$src" ]; then
        echo "ok: $trg -> $src"
    elif [ -L "$trg" ]; then
        echo "relink: $trg -> $src (was $(readlink "$trg"))"
        rm "$trg"
        ln -s "$src" "$trg"
    elif [ -e "$trg" ]; then
        if [ -e "$trg.bak" ] || [ -L "$trg.bak" ]; then
            echo "error: $trg.bak already exists; skipping $trg" >&2
            failures=$((failures + 1))
        else
            echo "backup: $trg -> $trg.bak, link $trg -> $src"
            mv "$trg" "$trg.bak"
            ln -s "$src" "$trg"
        fi
    else
        echo "link: $trg -> $src"
        mkdir -p "$(dirname "$trg")"
        ln -s "$src" "$trg"
    fi
}

main() {
    local i src trg cond
    parse_manifest
    i=0
    while [ "$i" -lt "${#sources[@]}" ]; do
        src="$DOTS/${sources[$i]}"
        trg="$(expand_target "${targets[$i]}")"
        cond="${conditions[$i]}"
        if condition_matches "$cond"; then
            case "$mode" in
                apply) apply_entry "$src" "$trg" ;;
            esac
        else
            echo "skip: ${targets[$i]} ($cond)"
        fi
        i=$((i + 1))
    done
    if [ "$failures" -gt 0 ]; then
        exit 1
    fi
}

main
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./test_deploy.sh`
Expected: exit 0, `16 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add deploy.sh test_deploy.sh
git commit -m "$(cat <<'EOF'
Implement deploy.sh apply with backup-on-conflict

Reconciles each condition-matched manifest entry: correct link is a
no-op, missing target is linked (creating parents), wrong symlink is
replaced, and a regular file or directory is moved to <target>.bak
first. Refuses to clobber an existing .bak and exits non-zero instead.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0117PaLyHdWjQwzFbdP34Hft
EOF
)"
```

---

### Task 3: `--dry-run` for apply

**Files:**
- Modify: `deploy.sh` (replace `apply_entry` only)
- Modify: `test_deploy.sh` (add `snapshot` helper + two tests; extend runner)

**Interfaces:**
- Consumes: `apply_entry`, `dry_run` global (Tasks 1–2).
- Produces:
  - `apply_entry` honors `dry_run=1`: prints the same decision lines prefixed `would: ` and performs no filesystem action. `ok:` lines and the `.bak`-exists error keep their normal form (nothing would be done / the error is real either way). `--dry-run audit` needs no code: audit never writes.
  - Test helper `snapshot "<dir>"` — prints a stable listing of paths, symlink destinations and regular-file checksums; two snapshots compare equal iff the tree is unchanged.

- [ ] **Step 1: Write the failing tests**

In `test_deploy.sh`, insert this helper directly below the existing `deploy()` function:

```bash
# Stable fingerprint of a tree: paths, symlink destinations, file checksums.
snapshot() {
    (
        cd "$1"
        find . | sort
        find . -type l | sort | while read -r link; do
            printf '%s -> %s\n' "$link" "$(readlink "$link")"
        done
        find . -type f | sort | while read -r f; do
            printf '%s %s\n' "$f" "$(cksum <"$f")"
        done
    )
}
```

Insert these tests immediately above the `# --- runner` line:

```bash
test_dry_run_reports_would_link() {
    sandbox
    printf 'rc\t~/.rc\n' > "$REPO/manifest"
    deploy --dry-run apply
    if [ "$status" = 0 ] && grep -q "^would: link: " <<<"$out" \
        && [ ! -e "$FAKEHOME/.rc" ] && [ ! -L "$FAKEHOME/.rc" ]; then
        ok "dry-run prints would: link and creates nothing"
    else
        bad "dry-run prints would: link and creates nothing (status=$status, out=$out)"
    fi
}

test_dry_run_changes_nothing() {
    sandbox
    printf 'rc\t~/.rc\nbin.any\t~/bin\n' > "$REPO/manifest"
    ln -s /somewhere/else "$FAKEHOME/.rc"
    mkdir "$FAKEHOME/bin"
    echo "old-tool" > "$FAKEHOME/bin/tool"
    before="$(snapshot "$FAKEHOME")"
    deploy --dry-run apply
    after="$(snapshot "$FAKEHOME")"
    if [ "$status" = 0 ] && [ "$before" = "$after" ] \
        && grep -q "^would: relink: " <<<"$out" \
        && grep -q "^would: backup: " <<<"$out"; then
        ok "dry-run leaves a dirty tree byte-identical"
    else
        bad "dry-run leaves a dirty tree byte-identical (status=$status, out=$out)"
    fi
}
```

In the runner list, insert after `test_apply_refuses_second_backup`:

```bash
test_dry_run_reports_would_link
test_dry_run_changes_nothing
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `./test_deploy.sh`
Expected: exit 1, `16 passed, 2 failed` — `--dry-run` is parsed but currently ignored, so apply mutates the tree and prints unprefixed lines.

- [ ] **Step 3: Implement dry-run**

In `deploy.sh`, replace the entire `apply_entry` function with:

```bash
apply_entry() {
    local src="$1" trg="$2" prefix=""
    if [ "$dry_run" = 1 ]; then
        prefix="would: "
    fi
    if [ -L "$trg" ] && [ "$(readlink "$trg")" = "$src" ]; then
        echo "ok: $trg -> $src"
    elif [ -L "$trg" ]; then
        echo "${prefix}relink: $trg -> $src (was $(readlink "$trg"))"
        if [ "$dry_run" = 0 ]; then
            rm "$trg"
            ln -s "$src" "$trg"
        fi
    elif [ -e "$trg" ]; then
        if [ -e "$trg.bak" ] || [ -L "$trg.bak" ]; then
            echo "error: $trg.bak already exists; skipping $trg" >&2
            failures=$((failures + 1))
        else
            echo "${prefix}backup: $trg -> $trg.bak, link $trg -> $src"
            if [ "$dry_run" = 0 ]; then
                mv "$trg" "$trg.bak"
                ln -s "$src" "$trg"
            fi
        fi
    else
        echo "${prefix}link: $trg -> $src"
        if [ "$dry_run" = 0 ]; then
            mkdir -p "$(dirname "$trg")"
            ln -s "$src" "$trg"
        fi
    fi
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./test_deploy.sh`
Expected: exit 0, `18 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add deploy.sh test_deploy.sh
git commit -m "$(cat <<'EOF'
Add --dry-run to deploy.sh apply

Prints the same per-entry decisions prefixed "would:" and touches
nothing, proven in tests by checksumming the tree before and after.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0117PaLyHdWjQwzFbdP34Hft
EOF
)"
```

---

### Task 4: Audit mode

**Files:**
- Modify: `deploy.sh` (add `audit_entry`; add `audit` arm to `main`'s case)
- Modify: `test_deploy.sh` (four tests; extend runner)

**Interfaces:**
- Consumes: `main` case dispatch, `failures` counter (Task 2).
- Produces: `audit_entry "<abs-src>" "<abs-trg>"` — read-only; prints `ok:` (correct link), `missing:` (target absent) or `drift:` (target exists but is not the expected link); `missing`/`drift` increment `failures` so the run exits 1. `skip:` lines for unmatched conditions already come from `main`.

- [ ] **Step 1: Write the failing tests**

In `test_deploy.sh`, insert immediately above the `# --- runner` line:

```bash
test_audit_ok_after_apply() {
    sandbox
    printf 'rc\t~/.rc\n' > "$REPO/manifest"
    deploy apply
    deploy audit
    if [ "$status" = 0 ] && grep -q "^ok: " <<<"$out"; then
        ok "audit reports ok and exits 0 when converged"
    else
        bad "audit reports ok and exits 0 when converged (status=$status, out=$out)"
    fi
}

test_audit_reports_missing() {
    sandbox
    printf 'rc\t~/.rc\n' > "$REPO/manifest"
    deploy audit
    if [ "$status" = 1 ] && grep -q "^missing: " <<<"$out"; then
        ok "audit reports missing and exits 1"
    else
        bad "audit reports missing and exits 1 (status=$status, out=$out)"
    fi
}

test_audit_reports_drift() {
    sandbox
    printf 'rc\t~/.rc\n' > "$REPO/manifest"
    echo "real-file" > "$FAKEHOME/.rc"
    deploy audit
    if [ "$status" = 1 ] && grep -q "^drift: " <<<"$out" \
        && [ "$(cat "$FAKEHOME/.rc")" = "real-file" ]; then
        ok "audit reports drift, exits 1, touches nothing"
    else
        bad "audit reports drift, exits 1, touches nothing (status=$status, out=$out)"
    fi
}

test_audit_skips_unmatched_condition() {
    sandbox
    printf 'rc\t~/.rc\tos=NoSuchOS\n' > "$REPO/manifest"
    deploy audit
    if [ "$status" = 0 ] && grep -q "^skip: " <<<"$out"; then
        ok "audit lists unmatched entries as skip and exits 0"
    else
        bad "audit lists unmatched entries as skip and exits 0 (status=$status, out=$out)"
    fi
}
```

In the runner list, insert after `test_dry_run_changes_nothing`:

```bash
test_audit_ok_after_apply
test_audit_reports_missing
test_audit_reports_drift
test_audit_skips_unmatched_condition
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `./test_deploy.sh`
Expected: exit 1, `19 passed, 3 failed` — audit mode currently does nothing per entry, so the `ok`/`missing`/`drift` tests fail; `test_audit_skips_unmatched_condition` already passes because `skip:` is printed by `main` regardless of mode.

- [ ] **Step 3: Implement audit**

In `deploy.sh`, insert this function directly below `apply_entry`:

```bash
audit_entry() {
    local src="$1" trg="$2"
    if [ -L "$trg" ] && [ "$(readlink "$trg")" = "$src" ]; then
        echo "ok: $trg"
    elif [ -e "$trg" ] || [ -L "$trg" ]; then
        echo "drift: $trg is not a symlink to $src"
        failures=$((failures + 1))
    else
        echo "missing: $trg"
        failures=$((failures + 1))
    fi
}
```

In `main`, replace the case block:

```bash
            case "$mode" in
                apply) apply_entry "$src" "$trg" ;;
            esac
```

with:

```bash
            case "$mode" in
                apply) apply_entry "$src" "$trg" ;;
                audit) audit_entry "$src" "$trg" ;;
            esac
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./test_deploy.sh`
Expected: exit 0, `22 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add deploy.sh test_deploy.sh
git commit -m "$(cat <<'EOF'
Add deploy.sh audit mode

Read-only drift report per manifest entry: ok, missing or drift, with
non-zero exit when anything is missing or drifted.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0117PaLyHdWjQwzFbdP34Hft
EOF
)"
```

---

### Task 5: Pilot manifest + real-machine parity check

**Files:**
- Create: `manifest`

**Interfaces:**
- Consumes: the complete `deploy.sh` (Tasks 1–4).
- Produces: the pilot `manifest`; captured parity evidence (command outputs) for Task 6's findings.

This machine is `nyx` running Darwin, and both pilot targets are already deployed by `link-dotfiles.sh` (`~/bin -> /Users/norton/.dotfiles/bin.Darwin`, `~/.bashrc.nyx -> /Users/norton/.dotfiles/.bashrc.nyx`). Those links point at the **main checkout**, so the parity check must run the driver from `/Users/norton/.dotfiles` — running it from the worktree would report every entry as drift purely because of path prefixes. We simulate the post-merge layout by copying the two files over, running read-only checks, and removing them.

- [ ] **Step 1: Write the manifest**

Create `manifest` with exactly this content:

```
# source        target          condition
bin.Darwin      ~/bin           os=Darwin
bin.Linux       ~/bin           os=Linux
.bashrc.nyx     ~/.bashrc.nyx   host=nyx
```

- [ ] **Step 2: Run the full test suite against it**

Run: `./test_deploy.sh`
Expected: exit 0, `22 passed, 0 failed` (sandboxes use their own manifests; this confirms nothing regressed).

Also validate the real manifest parses — from the worktree root run: `./deploy.sh --dry-run apply; echo "exit=$?"`
Expected: exit 0. On this machine the output reports drift-shaped lines (`would: relink: …`) for `~/bin` and `~/.bashrc.nyx` — expected here, because the worktree's `deploy.sh` resolves sources under the worktree while the live links point at the main checkout. The authoritative parity check is Step 3.

- [ ] **Step 3: Parity check against the live $HOME from the main checkout**

Run exactly:

```bash
test ! -e /Users/norton/.dotfiles/deploy.sh
test ! -e /Users/norton/.dotfiles/manifest
cp deploy.sh manifest /Users/norton/.dotfiles/
/Users/norton/.dotfiles/deploy.sh --dry-run apply; echo "dry-run exit=$?"
/Users/norton/.dotfiles/deploy.sh audit; echo "audit exit=$?"
rm /Users/norton/.dotfiles/deploy.sh /Users/norton/.dotfiles/manifest
```

Expected output (this is verification item 1 and 2 from the spec — zero proposed changes on a converged machine, audit clean):

```
ok: /Users/norton/bin -> /Users/norton/.dotfiles/bin.Darwin
skip: ~/bin (os=Linux)
ok: /Users/norton/.bashrc.nyx -> /Users/norton/.dotfiles/.bashrc.nyx
dry-run exit=0
ok: /Users/norton/bin
skip: ~/bin (os=Linux)
ok: /Users/norton/.bashrc.nyx
audit exit=0
```

Save the actual output — it goes verbatim into the Task 6 findings. If any line differs, STOP and debug before committing (that would mean parity is not reached).

- [ ] **Step 4: Commit**

```bash
git add manifest
git commit -m "$(cat <<'EOF'
Add pilot manifest covering bin.Darwin, bin.Linux and .bashrc.nyx

Verified against the live machine from the main checkout: dry-run
apply proposes zero changes and audit exits clean.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0117PaLyHdWjQwzFbdP34Hft
EOF
)"
```

---

### Task 6: Findings comment on issue #6

**Files:**
- Create: `/private/tmp/claude-501/-Users-norton--dotfiles/9d8edcf7-53be-41a3-8fe3-98accb0bf8a5/scratchpad/findings.md` (scratchpad only — never committed)

**Interfaces:**
- Consumes: test-suite result (Task 4), parity outputs (Task 5), `wc -l < deploy.sh`.
- Produces: a comment on https://github.com/nonrational/dotfiles/issues/6 answering the spike question.

- [ ] **Step 1: Gather the numbers**

Run: `./test_deploy.sh | tail -1` and `wc -l < deploy.sh`
Expected: `22 passed, 0 failed` and the driver's line count (target was ~100; report the real number whatever it is).

- [ ] **Step 2: Draft the findings comment**

Write the scratchpad file `findings.md` from this template. Replace every `<slot>` with the measured value or real captured output from Task 5 — no slot may survive into the posted comment:

```markdown
## Spike findings

**Answer: yes.** A <line-count>-line bash driver plus a 3-entry manifest reaches parity with `link-dotfiles.sh` for the pilot slice (`bin.*`, `.bashrc.nyx`) with `--dry-run`, backup-on-conflict and `audit` — bash + coreutils only, no external engine.

**Evidence**

- `./test_deploy.sh`: <test-result> — sandboxed fault injection covering missing target, wrong symlink, regular-file and directory conflicts, pre-existing `.bak` refusal, and a checksum proof that `--dry-run` changes nothing.
- Against the live `$HOME` on nyx (Darwin), run from the main checkout:

  ```
  <captured dry-run + audit output from Task 5>
  ```

**Deliberate differences from link-dotfiles.sh**

- Backup-on-conflict is non-interactive — no diff/merge menu. It refuses to clobber an existing `.bak` (skip + non-zero exit).
- Entries whose condition doesn't match are skipped, never removed, so `.bashrc.nyx` already linked on another host is left alone.

**Caveats**

<anything that didn't translate or surprised during implementation; delete the section if empty>

**Next step if adopted**

Merge the branch, then migrate remaining dotfiles into the manifest a few at a time; drop the `bin.$(uname)` special case from `link-dotfiles.sh` once the manifest covers it.
```

- [ ] **Step 3: Get user approval, then post**

Show the drafted comment to the user in chat and wait for approval (it's an outward-facing action). Once approved:

```bash
gh issue comment 6 --repo nonrational/dotfiles --body-file "/private/tmp/claude-501/-Users-norton--dotfiles/9d8edcf7-53be-41a3-8fe3-98accb0bf8a5/scratchpad/findings.md"
```

Expected: gh prints the new comment URL.

---

## After the plan

All tasks done means the spike question is answered and evidence is on the issue. Branch integration (PR vs merge vs keep) is a separate decision — use superpowers:finishing-a-development-branch.
