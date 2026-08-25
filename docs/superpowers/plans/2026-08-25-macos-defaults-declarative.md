# Declarative macOS Defaults Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 218 `defaults write` lines in `.macos` with a reviewable table and a script that reports when macOS has drifted away from it.

**Architecture:** A tab-delimited table (`macos-defaults`) holds one row per setting. `scripts/macos-defaults.sh` reads it in four modes: `check` validates the file, `audit` compares each row against the live machine, `apply` writes rows that differ, and `accept` rewrites rows to match what is live. Rows that cannot be compared (TCC-protected containers, unset keys, `array`/`dict` values) carry a `noaudit=<reason>` marker: they are still written by `apply`, but `audit` reports them as `skip` and they never affect the exit code.

**Tech Stack:** bash 3.2 (macOS `/bin/bash`), `defaults(1)`, GNU make. No external dependencies, matching `deploy.sh`.

**Spec:** `docs/superpowers/specs/2026-08-25-macos-defaults-declarative-design.md`

## Global Constraints

- **bash 3.2.** `/bin/bash` on macOS is 3.2.57. No associative arrays, no `${var,,}`, no `mapfile`. Expanding an empty array under `set -u` is an error, so avoid empty-array expansion entirely.
- **`set -euf -o pipefail`** at the top of every script, matching `deploy.sh`. Note this enables `nounset`. A bare `[ cond ] && assign` as a standalone statement fires `errexit` when the test fails; use `if` blocks.
- **Validate the whole table before acting on any row.** Same posture as `deploy.sh`: a malformed row means nothing runs.
- **Comments must be a comment only when the first non-whitespace character is `#`.** Do not copy `deploy.sh`'s `${line%%#*}`, which would truncate a value containing `#`.
- **Never split table rows with `IFS=$'\t' read`.** Bash treats tab as IFS *whitespace*, so it collapses runs of tabs and drops a leading one, shifting every field left. Split with parameter expansion.
- **Tests never touch real preferences or the real `$HOME`.** Everything lives under `mktemp -d`. `defaults` accepts an absolute plist path as a domain, which is what makes this possible.
- **`.editorconfig` applies:** LF endings, final newline, no trailing whitespace, UTF-8. `indent_style = space` for `[*]`, so scripts indent with 4 spaces like `deploy.sh`.
- **`make preflight`** (`test` plus every `check-*` target) is the gate. CI calls it directly, so a new `check-*` target needs no `ci.yml` edit.
- **Commit messages carry no Conventional Commit prefixes.** Plain descriptive subject lines.
- **This is a public repo.** No private hostnames, repo names, or identifiers in any committed file.

## File Structure

| File | Responsibility |
|---|---|
| `macos-defaults` (create) | The table. One row per setting; `#` comments carry the *why* over from `.macos`. |
| `scripts/macos-defaults.sh` (create) | Parser plus the four modes. The only thing that knows the table format. |
| `scripts/migrate-macos-defaults.sh` (create) | One-shot generator: parses `.macos` into the table. Committed so the transcription is reviewable. |
| `test/test_macos_defaults.sh` (create) | Parser tests run everywhere; `defaults`-backed tests are Darwin-gated. |
| `.macos` (modify) | Loses all 218 `defaults write` lines; keeps the imperative tail. |
| `Makefile` (modify) | `macos-audit`, `macos-apply`, `macos-accept`, `check-macos-defaults`; `macos` gains the apply step. |
| `.editorconfig` (modify) | A `[macos-defaults]` stanza declaring the tabs as data separators. |
| `CLAUDE.md` (modify) | Commands and Architecture entries for the new table. |

---

### Task 1: Table parser and `check` mode

Produces a script that can read and validate the table but does nothing to the machine. Everything here runs on Linux and macOS alike, so the whole task is testable in CI on both legs.

**Files:**
- Create: `scripts/macos-defaults.sh`
- Create: `test/test_macos_defaults.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `scripts/macos-defaults.sh` honoring `MACOS_DEFAULTS_TABLE` (absolute path to the table; defaults to `$DOTS/macos-defaults`). Modes `check|audit|apply|accept`, flag `--dry-run`, optional positional `domain [key]` filter. Parsed rows land in the globals `t_domain`, `t_key`, `t_type`, `t_value`, `t_status` (parallel indexed arrays) via `parse_table`. Helper `split_row "$line"` fills the global array `ROW`. Later tasks add `audit_row`, `apply_row`, `run_accept`.

- [ ] **Step 1: Write the failing test file**

Create `test/test_macos_defaults.sh`:

```bash
#!/bin/bash
# Tests for scripts/macos-defaults.sh. Table parsing runs on any platform;
# anything that shells out to `defaults` is Darwin-only and skipped elsewhere.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-macos-defaults.XXXXXX")"
BASE="$(cd "$BASE" && pwd)"
trap 'rm -rf "$BASE"' EXIT

pass=0
fail=0
skipped=0
sb_count=0

ok()   { pass=$((pass + 1)); echo "PASS: $1"; }
bad()  { fail=$((fail + 1)); echo "FAIL: $1"; }
note() { skipped=$((skipped + 1)); echo "SKIP: $1"; }

# `defaults` accepts an absolute plist path as a domain, so $DOMAIN keeps every
# write inside the sandbox instead of a real preference domain.
sandbox() {
    sb_count=$((sb_count + 1))
    SB="$BASE/$sb_count"
    mkdir -p "$SB"
    TABLE="$SB/macos-defaults"
    DOMAIN="$SB/com.example.test"
}

mdefaults() {
    set +e
    out="$(MACOS_DEFAULTS_TABLE="$TABLE" "$ROOT/scripts/macos-defaults.sh" "$@" 2>&1)"
    status=$?
    set -e
}

# Emit one tab-delimited row. Written field by field so an empty trailing
# field survives; that case is what the malformed-row tests exercise.
row() {
    local first=1 f
    for f in "$@"; do
        if [ "$first" = 1 ]; then
            printf '%s' "$f"
            first=0
        else
            printf '\t%s' "$f"
        fi
    done
    printf '\n'
}

darwin_only() {
    if [ "$(uname)" != "Darwin" ]; then
        note "$1 (not Darwin)"
        return 1
    fi
    return 0
}

test_rejects_unknown_flag() {
    sandbox
    row NSGlobalDomain SomeKey bool true > "$TABLE"
    mdefaults --bogus
    if [ "$status" = 2 ] && grep -q "usage:" <<<"$out"; then
        ok "unknown flag exits 2 with usage"
    else
        bad "unknown flag exits 2 with usage (status=$status, out=$out)"
    fi
}

test_rejects_missing_table() {
    sandbox
    mdefaults check
    if [ "$status" = 1 ] && grep -q "table not found" <<<"$out"; then
        ok "missing table exits 1"
    else
        bad "missing table exits 1 (status=$status, out=$out)"
    fi
}

test_rejects_three_columns() {
    sandbox
    row NSGlobalDomain SomeKey bool > "$TABLE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "line 1" <<<"$out"; then
        ok "three-column row exits 1 naming the line"
    else
        bad "three-column row exits 1 naming the line (status=$status, out=$out)"
    fi
}

test_rejects_six_columns() {
    sandbox
    row NSGlobalDomain SomeKey bool true noaudit=tcc surprise > "$TABLE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "line 1" <<<"$out"; then
        ok "six-column row exits 1 naming the line"
    else
        bad "six-column row exits 1 naming the line (status=$status, out=$out)"
    fi
}

# A trailing tab makes an empty fifth field. The format reserves the trailing
# position for `status` precisely so no interior field is ever empty; rejecting
# this keeps that invariant, and .editorconfig forbids the trailing whitespace.
test_rejects_empty_status_column() {
    sandbox
    printf 'NSGlobalDomain\tSomeKey\tbool\ttrue\t\n' > "$TABLE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "status" <<<"$out"; then
        ok "empty trailing status column exits 1"
    else
        bad "empty trailing status column exits 1 (status=$status, out=$out)"
    fi
}

test_rejects_unknown_type() {
    sandbox
    row NSGlobalDomain SomeKey number 4 > "$TABLE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "unknown type" <<<"$out"; then
        ok "unknown type exits 1"
    else
        bad "unknown type exits 1 (status=$status, out=$out)"
    fi
}

test_rejects_unknown_status() {
    sandbox
    row NSGlobalDomain SomeKey bool true arch=arm64 > "$TABLE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "unknown status" <<<"$out"; then
        ok "unknown status exits 1"
    else
        bad "unknown status exits 1 (status=$status, out=$out)"
    fi
}

# `audit` has no way to compare a container value, so a container row without a
# noaudit marker would report drift forever.
test_rejects_container_type_without_noaudit() {
    sandbox
    row com.apple.terminal StringEncodings array 4 > "$TABLE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "noaudit" <<<"$out"; then
        ok "container type without noaudit exits 1"
    else
        bad "container type without noaudit exits 1 (status=$status, out=$out)"
    fi
}

test_rejects_empty_table() {
    sandbox
    printf '# comments only\n\n' > "$TABLE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "no rows" <<<"$out"; then
        ok "comment-only table exits 1"
    else
        bad "comment-only table exits 1 (status=$status, out=$out)"
    fi
}

# deploy.sh strips from the first `#` to end of line. That would truncate this
# value, which is why this parser only treats a leading `#` as a comment.
test_hash_inside_value_is_not_a_comment() {
    sandbox
    row com.example.app Greeting string "hello # world" > "$TABLE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "a # inside a value does not start a comment"
    else
        bad "a # inside a value does not start a comment (status=$status, out=$out)"
    fi
}

test_indented_comment_is_a_comment() {
    sandbox
    {
        printf '    # indented\n'
        row NSGlobalDomain SomeKey bool true
    } > "$TABLE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "an indented # line is a comment"
    else
        bad "an indented # line is a comment (status=$status, out=$out)"
    fi
}

# `com.apple.print.PrintingPrefs "Quit When Finished"` is a real row, and it is
# the reason this file is tab-delimited rather than whitespace-columned.
test_key_with_spaces_parses() {
    sandbox
    row com.apple.print.PrintingPrefs "Quit When Finished" bool true > "$TABLE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "a key containing spaces parses"
    else
        bad "a key containing spaces parses (status=$status, out=$out)"
    fi
}

test_check_counts_rows() {
    sandbox
    {
        printf '# a banner\n'
        row NSGlobalDomain FirstKey bool true
        printf '\n'
        row com.apple.Safari SecondKey bool true noaudit=tcc
    } > "$TABLE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "2 rows" <<<"$out"; then
        ok "check counts data rows, ignoring comments and blanks"
    else
        bad "check counts data rows, ignoring comments and blanks (status=$status, out=$out)"
    fi
}

# --- runner -----------------------------------------------------------------
test_rejects_unknown_flag
test_rejects_missing_table
test_rejects_three_columns
test_rejects_six_columns
test_rejects_empty_status_column
test_rejects_unknown_type
test_rejects_unknown_status
test_rejects_container_type_without_noaudit
test_rejects_empty_table
test_hash_inside_value_is_not_a_comment
test_indented_comment_is_a_comment
test_key_with_spaces_parses
test_check_counts_rows

echo
echo "$pass passed, $fail failed, $skipped skipped"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Make it executable and run it to verify it fails**

```bash
chmod +x test/test_macos_defaults.sh
./test/test_macos_defaults.sh
```

Expected: every test FAILs, because `scripts/macos-defaults.sh` does not exist yet.

- [ ] **Step 3: Write the script**

Create `scripts/macos-defaults.sh`:

```bash
#!/bin/bash
# Declarative macOS defaults: check/audit/apply/accept the table in ./macos-defaults.
# Spec: docs/superpowers/specs/2026-08-25-macos-defaults-declarative-design.md
set -euf -o pipefail

DOTS="$(cd "$(dirname "$0")/.." && pwd)"
# Overridable so the test suite can point at a sandboxed table.
TABLE="${MACOS_DEFAULTS_TABLE:-$DOTS/macos-defaults}"
TAB=$'\t'

dry_run=0
mode=audit
filter_domain=""
filter_key=""
failures=0

usage() {
    echo "usage: $0 [--dry-run] [check|audit|apply|accept] [domain [key]]" >&2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            dry_run=1
            shift
            ;;
        check | audit | apply | accept)
            mode="$1"
            shift
            filter_domain="${1:-}"
            if [ $# -gt 0 ]; then shift; fi
            filter_key="${1:-}"
            if [ $# -gt 0 ]; then shift; fi
            if [ $# -gt 0 ]; then
                usage
                exit 2
            fi
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

t_domain=()
t_key=()
t_type=()
t_value=()
t_status=()

# Splits on tabs into the global ROW, preserving empty fields. `IFS=$'\t' read`
# cannot be used here: bash classes tab as IFS whitespace, so it collapses runs
# of tabs and drops a leading one, shifting every field left without an error.
split_row() {
    local rest="$1"
    ROW=()
    while :; do
        case "$rest" in
            *"$TAB"*)
                ROW+=("${rest%%"$TAB"*}")
                rest="${rest#*"$TAB"}"
                ;;
            *)
                ROW+=("$rest")
                break
                ;;
        esac
    done
}

parse_table() {
    local lineno=0 line trimmed status i
    if [ ! -f "$TABLE" ]; then
        echo "error: table not found at $TABLE" >&2
        exit 1
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        trimmed="${line#"${line%%[![:space:]]*}"}"
        case "$trimmed" in
            "" | "#"*) continue ;;
        esac
        split_row "$line"
        if [ "${#ROW[@]}" -lt 4 ] || [ "${#ROW[@]}" -gt 5 ]; then
            echo "error: $TABLE line $lineno: expected 4 or 5 tab-separated columns, got ${#ROW[@]}" >&2
            exit 1
        fi
        i=0
        while [ "$i" -lt 4 ]; do
            if [ -z "${ROW[$i]}" ]; then
                echo "error: $TABLE line $lineno: column $((i + 1)) is empty" >&2
                exit 1
            fi
            i=$((i + 1))
        done
        status=""
        if [ "${#ROW[@]}" = 5 ]; then
            status="${ROW[4]}"
            if [ -z "$status" ]; then
                echo "error: $TABLE line $lineno: status column is empty; omit it instead" >&2
                exit 1
            fi
        fi
        case "${ROW[2]}" in
            bool | int | float | string | raw) ;;
            array | dict | dict-add | date | data)
                case "$status" in
                    noaudit=*) ;;
                    *)
                        echo "error: $TABLE line $lineno: type '${ROW[2]}' cannot be compared; it needs a noaudit= status" >&2
                        exit 1
                        ;;
                esac
                ;;
            *)
                echo "error: $TABLE line $lineno: unknown type '${ROW[2]}'" >&2
                exit 1
                ;;
        esac
        case "$status" in
            "" | noaudit=tcc | noaudit=unset | noaudit=complex | os=?* | host=?*) ;;
            *)
                echo "error: $TABLE line $lineno: unknown status '$status'" >&2
                exit 1
                ;;
        esac
        t_domain+=("${ROW[0]}")
        t_key+=("${ROW[1]}")
        t_type+=("${ROW[2]}")
        t_value+=("${ROW[3]}")
        t_status+=("$status")
    done <"$TABLE"
    if [ "${#t_domain[@]}" -eq 0 ]; then
        echo "error: $TABLE has no rows" >&2
        exit 1
    fi
}

row_selected() {
    local i="$1"
    if [ -n "$filter_domain" ] && [ "${t_domain[$i]}" != "$filter_domain" ]; then
        return 1
    fi
    if [ -n "$filter_key" ] && [ "${t_key[$i]}" != "$filter_key" ]; then
        return 1
    fi
    return 0
}

main() {
    local i n
    parse_table
    n="${#t_domain[@]}"
    if [ "$mode" = check ]; then
        if [ "$n" = 1 ]; then
            echo "ok: 1 row in $TABLE"
        else
            echo "ok: $n rows in $TABLE"
        fi
        return 0
    fi
    i=0
    while [ "$i" -lt "$n" ]; do
        if row_selected "$i"; then
            case "$mode" in
                audit) audit_row "$i" ;;
                apply) apply_row "$i" ;;
            esac
        fi
        i=$((i + 1))
    done
    if [ "$failures" -gt 0 ]; then
        exit 1
    fi
}

main
```

- [ ] **Step 4: Make it executable and run the tests**

```bash
chmod +x scripts/macos-defaults.sh
./test/test_macos_defaults.sh
```

Expected: all 13 tests PASS on both macOS and Linux. `check` never reaches `audit_row`/`apply_row`, which do not exist yet, so this is a complete slice.

- [ ] **Step 5: Verify the parser rejects the exact shapes `deploy.sh` would mishandle**

```bash
printf 'com.example.app\tGreeting\tstring\thello # world\n' > /tmp/t1
MACOS_DEFAULTS_TABLE=/tmp/t1 ./scripts/macos-defaults.sh check
```

Expected: `ok: 1 row in /tmp/t1`. Confirm the value was not truncated at the `#` by adding a temporary `echo "${t_value[0]}"` if you want to see it, then remove it.

- [ ] **Step 6: Commit**

```bash
git add scripts/macos-defaults.sh test/test_macos_defaults.sh
git commit -m "Add macos-defaults table parser and check mode

Parses the tab-delimited table and validates it, with no machine access
yet. Two departures from deploy.sh's parser, both tested: a # only starts
a comment at the start of a line, and rows are split by parameter
expansion rather than IFS=\$'\\t' read, which collapses tab runs."
```

---

### Task 2: `audit` mode

Adds the comparison engine. This is the mode the whole change exists for, so its correctness bar is the highest in the plan: the four normalization rules below are each a way the naive `[ "$want" = "$live" ]` gets it wrong.

**Files:**
- Modify: `scripts/macos-defaults.sh` (add helpers before `main`; add the condition check inside `main`'s loop)
- Modify: `test/test_macos_defaults.sh` (add tests, extend the runner)

**Interfaces:**
- Consumes: `parse_table`, the `t_*` arrays, `row_selected`, and the `failures` counter from Task 1.
- Produces: `defaults_read <domain> <key>` (echoes the live value, exit 1 if the key is absent), `defaults_read_type <domain> <key>` (echoes a plist type name with `Type is ` stripped, exit 1 if absent), `table_type_of <plist-type>` (maps `boolean`→`bool`, `integer`→`int`, `dictionary`→`dict`, else passthrough), `normalize <type> <value>`, `condition_matches <status>`, `audit_row <index>`. Task 3 reuses `defaults_read` and `normalize`; Task 4 reuses `defaults_read` and `defaults_read_type`.

**Deviation from the spec, deliberate:** the spec calls `os=` and `host=` "parsed but unused". A parser that accepts a token and then ignores its meaning would silently apply a `os=Linux` row on Darwin. This task implements the condition instead, copying `deploy.sh`'s `condition_matches` and its shared `scripts/host-id.sh`. Ten lines, one test, and the reserved vocabulary stops being a lie.

- [ ] **Step 1: Write the failing tests**

Append to `test/test_macos_defaults.sh`, above the runner block:

```bash
# A row whose condition does not match is skipped before any `defaults` call,
# so this case needs no Darwin gate.
test_audit_skips_unmatched_condition() {
    sandbox
    row NSGlobalDomain SomeKey bool true os=NoSuchOS > "$TABLE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^skip: " <<<"$out"; then
        ok "unmatched os condition is skipped"
    else
        bad "unmatched os condition is skipped (status=$status, out=$out)"
    fi
}

test_audit_ok_when_value_matches() {
    darwin_only "audit reports ok when the live value matches" || return 0
    sandbox
    defaults write "$DOMAIN" Flag -bool true
    row "$DOMAIN" Flag bool true > "$TABLE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^ok: " <<<"$out"; then
        ok "audit reports ok when the live value matches"
    else
        bad "audit reports ok when the live value matches (status=$status, out=$out)"
    fi
}

# `defaults` stores booleans as 0/1 but the table keeps them readable as
# true/false, so every bool comparison depends on normalizing both sides.
test_audit_normalizes_bools() {
    darwin_only "audit normalizes true against a stored 1" || return 0
    sandbox
    defaults write "$DOMAIN" Flag -bool true
    row "$DOMAIN" Flag bool YES > "$TABLE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^ok: " <<<"$out"; then
        ok "audit normalizes true/YES/1 to the same value"
    else
        bad "audit normalizes true/YES/1 to the same value (status=$status, out=$out)"
    fi
}

test_audit_reports_drift() {
    darwin_only "audit reports drift with both values" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    row "$DOMAIN" Count int 7 > "$TABLE"
    mdefaults audit
    if [ "$status" = 1 ] && grep -q "^drift: .*want=7 live=3" <<<"$out"; then
        ok "audit reports drift with want and live"
    else
        bad "audit reports drift with want and live (status=$status, out=$out)"
    fi
}

# An absent key and a mismatched key need different fixes, so they get
# different labels; conflating them made the design probe unreadable.
test_audit_reports_missing() {
    darwin_only "audit reports an absent key as missing" || return 0
    sandbox
    defaults write "$DOMAIN" Other -int 1
    row "$DOMAIN" Count int 7 > "$TABLE"
    mdefaults audit
    if [ "$status" = 1 ] && grep -q "^missing: " <<<"$out" && ! grep -q "^drift: " <<<"$out"; then
        ok "audit reports an absent key as missing, not drift"
    else
        bad "audit reports an absent key as missing, not drift (status=$status, out=$out)"
    fi
}

test_audit_reports_type_drift() {
    darwin_only "audit reports a changed storage type as drift" || return 0
    sandbox
    defaults write "$DOMAIN" Count -string 7
    row "$DOMAIN" Count int 7 > "$TABLE"
    mdefaults audit
    if [ "$status" = 1 ] && grep -q "^drift: .*type want=int live=string" <<<"$out"; then
        ok "audit reports a changed storage type as drift"
    else
        bad "audit reports a changed storage type as drift (status=$status, out=$out)"
    fi
}

# noaudit rows must never influence the exit code, or every audit on a machine
# with Safari settings would exit non-zero forever.
test_audit_skips_noaudit_rows_without_failing() {
    darwin_only "audit skips noaudit rows and still exits 0" || return 0
    sandbox
    row "$DOMAIN" Missing bool true noaudit=tcc > "$TABLE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^skip: .*(tcc)" <<<"$out"; then
        ok "audit skips noaudit rows and still exits 0"
    else
        bad "audit skips noaudit rows and still exits 0 (status=$status, out=$out)"
    fi
}

test_audit_filters_by_domain_and_key() {
    darwin_only "audit honors the domain and key filter" || return 0
    sandbox
    defaults write "$DOMAIN" First -bool true
    defaults write "$DOMAIN" Second -bool true
    {
        row "$DOMAIN" First bool true
        row "$DOMAIN" Second bool true
    } > "$TABLE"
    mdefaults audit "$DOMAIN" Second
    if [ "$status" = 0 ] && grep -q "Second" <<<"$out" && ! grep -q "First" <<<"$out"; then
        ok "audit honors the domain and key filter"
    else
        bad "audit honors the domain and key filter (status=$status, out=$out)"
    fi
}
```

Add to the runner block, before the summary lines:

```bash
test_audit_skips_unmatched_condition
test_audit_ok_when_value_matches
test_audit_normalizes_bools
test_audit_reports_drift
test_audit_reports_missing
test_audit_reports_type_drift
test_audit_skips_noaudit_rows_without_failing
test_audit_filters_by_domain_and_key
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
./test/test_macos_defaults.sh
```

Expected: the 13 Task 1 tests still PASS. The 8 new ones FAIL — on macOS because `audit_row` is undefined, on Linux the condition test FAILs and the other 7 report SKIP.

- [ ] **Step 3: Add the helpers**

In `scripts/macos-defaults.sh`, insert after `row_selected` and before `main`:

```bash
source "$DOTS/scripts/host-id.sh"
os="$(os_id)"
host="$(host_id)"

condition_matches() {
    case "$1" in
        "" | noaudit=*) return 0 ;;
        os=*) [ "${1#os=}" = "$os" ] ;;
        host=*) [ "${1#host=}" = "$host" ] ;;
        *) return 1 ;;
    esac
}

defaults_read() {
    local domain="$1" key="$2"
    case "$domain" in
        currentHost:*) defaults -currentHost read "${domain#currentHost:}" "$key" 2>/dev/null ;;
        *) defaults read "$domain" "$key" 2>/dev/null ;;
    esac
}

defaults_read_type() {
    local domain="$1" key="$2" out
    case "$domain" in
        currentHost:*)
            out="$(defaults -currentHost read-type "${domain#currentHost:}" "$key" 2>/dev/null)" || return 1
            ;;
        *)
            out="$(defaults read-type "$domain" "$key" 2>/dev/null)" || return 1
            ;;
    esac
    printf '%s\n' "${out#Type is }"
}

table_type_of() {
    case "$1" in
        boolean) printf 'bool\n' ;;
        integer) printf 'int\n' ;;
        dictionary) printf 'dict\n' ;;
        *) printf '%s\n' "$1" ;;
    esac
}

normalize() {
    case "$1" in
        bool)
            case "$2" in
                true | TRUE | True | YES | Yes | yes | 1) printf '1\n' ;;
                false | FALSE | False | NO | No | no | 0) printf '0\n' ;;
                *) printf '%s\n' "$2" ;;
            esac
            ;;
        *) printf '%s\n' "$2" ;;
    esac
}

audit_row() {
    local i="$1"
    local domain="${t_domain[$i]}" key="${t_key[$i]}" type="${t_type[$i]}"
    local value="${t_value[$i]}" status="${t_status[$i]}"
    local live want live_type

    case "$status" in
        noaudit=*)
            echo "skip: $domain $key (${status#noaudit=})"
            return 0
            ;;
    esac

    if ! live="$(defaults_read "$domain" "$key")"; then
        echo "missing: $domain $key"
        failures=$((failures + 1))
        return 0
    fi

    # A `raw` row is written with no type flag, so `defaults` infers the stored
    # type and the table has no claim to assert against it.
    if [ "$type" != raw ]; then
        if live_type="$(defaults_read_type "$domain" "$key")"; then
            live_type="$(table_type_of "$live_type")"
            if [ "$live_type" != "$type" ]; then
                echo "drift: $domain $key type want=$type live=$live_type"
                failures=$((failures + 1))
                return 0
            fi
        fi
    fi

    want="$(normalize "$type" "$value")"
    live="$(normalize "$type" "$live")"
    if [ "$want" = "$live" ]; then
        echo "ok: $domain $key"
    else
        echo "drift: $domain $key want=$want live=$live"
        failures=$((failures + 1))
    fi
}
```

- [ ] **Step 4: Wire the condition check into `main`**

Replace the dispatch block inside `main`'s while loop with:

```bash
        if row_selected "$i"; then
            if ! condition_matches "${t_status[$i]}"; then
                echo "skip: ${t_domain[$i]} ${t_key[$i]} (${t_status[$i]})"
            else
                case "$mode" in
                    audit) audit_row "$i" ;;
                    apply) apply_row "$i" ;;
                esac
            fi
        fi
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
./test/test_macos_defaults.sh
```

Expected on macOS: 21 passed, 0 failed. Expected on Linux: 14 passed, 0 failed, 7 skipped.

- [ ] **Step 6: Commit**

```bash
git add scripts/macos-defaults.sh test/test_macos_defaults.sh
git commit -m "Add audit mode to macos-defaults

Compares each row against the live machine. Four rules the naive string
compare gets wrong, each with a test: booleans normalize (defaults stores
0/1, the table reads true/false), a changed storage type is drift, an
absent key is missing rather than drift, and noaudit rows never reach the
exit code.

os= and host= conditions are implemented rather than merely parsed. The
spec reserved them as unused, but a status the parser accepts and then
ignores would apply an os=Linux row on Darwin."
```

---

### Task 3: `apply` mode, `--dry-run`, and container writes

**Files:**
- Modify: `scripts/macos-defaults.sh`
- Modify: `test/test_macos_defaults.sh`

**Interfaces:**
- Consumes: `defaults_read`, `normalize` from Task 2; `dry_run` from Task 1.
- Produces: `needs_sudo <domain>` (true only when the domain is an absolute path whose plist exists and is not writable), `write_row <domain> <key> <type> <value>`, `apply_row <index>`.

- [ ] **Step 1: Write the failing tests**

Append to `test/test_macos_defaults.sh`, above the runner block:

```bash
test_apply_writes_missing_key() {
    darwin_only "apply writes a key that is absent" || return 0
    sandbox
    row "$DOMAIN" Count int 7 > "$TABLE"
    mdefaults apply
    if [ "$status" = 0 ] && [ "$(defaults read "$DOMAIN" Count)" = 7 ] \
        && grep -q "^write: " <<<"$out"; then
        ok "apply writes a key that is absent"
    else
        bad "apply writes a key that is absent (status=$status, out=$out)"
    fi
}

test_apply_is_idempotent() {
    darwin_only "a second apply is a no-op reported as ok" || return 0
    sandbox
    row "$DOMAIN" Count int 7 > "$TABLE"
    mdefaults apply
    mdefaults apply
    if [ "$status" = 0 ] && grep -q "^ok: " <<<"$out" && ! grep -q "^write: " <<<"$out"; then
        ok "a second apply is a no-op reported as ok"
    else
        bad "a second apply is a no-op reported as ok (status=$status, out=$out)"
    fi
}

test_dry_run_reports_would_write() {
    darwin_only "dry-run prefixes its decisions with would:" || return 0
    sandbox
    row "$DOMAIN" Count int 7 > "$TABLE"
    mdefaults --dry-run apply
    if [ "$status" = 0 ] && grep -q "^would: write: " <<<"$out"; then
        ok "dry-run prefixes its decisions with would:"
    else
        bad "dry-run prefixes its decisions with would: (status=$status, out=$out)"
    fi
}

test_dry_run_changes_nothing() {
    darwin_only "dry-run creates no plist" || return 0
    sandbox
    row "$DOMAIN" Count int 7 > "$TABLE"
    mdefaults --dry-run apply
    if [ "$status" = 0 ] && [ ! -e "$DOMAIN.plist" ]; then
        ok "dry-run creates no plist"
    else
        bad "dry-run creates no plist (status=$status, out=$out)"
    fi
}

# audit cannot tell whether a noaudit row needs writing, so apply always writes
# one. Without this, the 44 TCC rows would never be applied on a fresh Mac.
test_apply_writes_noaudit_rows() {
    darwin_only "apply writes noaudit rows unconditionally" || return 0
    sandbox
    row "$DOMAIN" Count int 7 noaudit=unset > "$TABLE"
    mdefaults apply
    if [ "$status" = 0 ] && [ "$(defaults read "$DOMAIN" Count)" = 7 ]; then
        ok "apply writes noaudit rows unconditionally"
    else
        bad "apply writes noaudit rows unconditionally (status=$status, out=$out)"
    fi
}

# An array value cannot be expressed as a type/value pair, so container rows
# carry a literal argument tail and are the only rows that get eval'd.
test_apply_writes_container_value() {
    darwin_only "apply writes an array row through its literal argument tail" || return 0
    sandbox
    row "$DOMAIN" Langs array '"en" "fr"' noaudit=complex > "$TABLE"
    mdefaults apply
    if [ "$status" = 0 ] && [ "$(defaults read "$DOMAIN" Langs | tr -d '\n ')" = "(en,fr)" ]; then
        ok "apply writes an array row through its literal argument tail"
    else
        bad "apply writes an array row through its literal argument tail (status=$status, out=$out)"
    fi
}

test_apply_skips_unmatched_condition() {
    sandbox
    row NSGlobalDomain SomeKey bool true os=NoSuchOS > "$TABLE"
    mdefaults apply
    if [ "$status" = 0 ] && grep -q "^skip: " <<<"$out"; then
        ok "apply skips an unmatched condition"
    else
        bad "apply skips an unmatched condition (status=$status, out=$out)"
    fi
}
```

Add to the runner block:

```bash
test_apply_writes_missing_key
test_apply_is_idempotent
test_dry_run_reports_would_write
test_dry_run_changes_nothing
test_apply_writes_noaudit_rows
test_apply_writes_container_value
test_apply_skips_unmatched_condition
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
./test/test_macos_defaults.sh
```

Expected: the 7 new tests FAIL on macOS (`apply_row` undefined); on Linux 6 SKIP and `test_apply_skips_unmatched_condition` FAILs.

- [ ] **Step 3: Add the writer**

In `scripts/macos-defaults.sh`, insert after `audit_row`:

```bash
# Decided from the plist's writability rather than the path prefix: the test
# suite uses absolute-path domains under mktemp, which are writable and must
# not reach for sudo.
needs_sudo() {
    local domain="$1"
    case "$domain" in
        /*) ;;
        *) return 1 ;;
    esac
    [ -e "$domain.plist" ] && [ ! -w "$domain.plist" ]
}

write_row() {
    local domain="$1" key="$2" type="$3" value="$4"
    local host_flag="" target="$domain" sudo_cmd=""

    case "$domain" in
        currentHost:*)
            host_flag="-currentHost"
            target="${domain#currentHost:}"
            ;;
    esac
    if needs_sudo "$target"; then
        sudo_cmd="sudo"
    fi

    case "$type" in
        array | dict | dict-add | date | data)
            # Container values carry their own quoted argument tail, which only
            # the shell can re-split. Scalar rows never take this branch.
            eval "$sudo_cmd defaults $host_flag write \"\$target\" \"\$key\" -$type $value"
            ;;
        raw)
            $sudo_cmd defaults $host_flag write "$target" "$key" "$value"
            ;;
        *)
            $sudo_cmd defaults $host_flag write "$target" "$key" "-$type" "$value"
            ;;
    esac
}

apply_row() {
    local i="$1"
    local domain="${t_domain[$i]}" key="${t_key[$i]}" type="${t_type[$i]}"
    local value="${t_value[$i]}" status="${t_status[$i]}"
    local prefix="" live

    if [ "$dry_run" = 1 ]; then
        prefix="would: "
    fi

    case "$status" in
        noaudit=*) ;;
        *)
            if live="$(defaults_read "$domain" "$key")"; then
                if [ "$(normalize "$type" "$live")" = "$(normalize "$type" "$value")" ]; then
                    echo "ok: $domain $key"
                    return 0
                fi
            fi
            ;;
    esac

    echo "${prefix}write: $domain $key = $value"
    if [ "$dry_run" = 1 ]; then
        return 0
    fi
    write_row "$domain" "$key" "$type" "$value"
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
./test/test_macos_defaults.sh
```

Expected on macOS: 28 passed, 0 failed. On Linux: 15 passed, 0 failed, 13 skipped.

- [ ] **Step 5: Confirm apply never prompts for a password in the sandbox**

```bash
./test/test_macos_defaults.sh
```

Expected: the run completes without a `Password:` prompt. If one appears, `needs_sudo` is matching on the path prefix rather than writability.

- [ ] **Step 6: Commit**

```bash
git add scripts/macos-defaults.sh test/test_macos_defaults.sh
git commit -m "Add apply mode to macos-defaults

Writes only rows whose live value differs, except noaudit rows, which are
always written since audit cannot tell whether they need it.

sudo is chosen from the plist's writability, not the path prefix, so the
sandboxed tests never prompt. Container rows carry a literal argument tail
and are the only ones eval'd; an array value has no type/value form."
```

---

### Task 4: `accept` mode

Rewrites table rows from what is live. This is also the seeding tool Task 6 uses, so it has to preserve every comment and blank line in the file.

**Files:**
- Modify: `scripts/macos-defaults.sh`
- Modify: `test/test_macos_defaults.sh`

**Interfaces:**
- Consumes: `defaults_read`, `defaults_read_type`, `table_type_of`, `normalize`, `row_selected`, the `t_*` arrays.

**Deviation from the spec, deliberate:** the spec writes the signature as `accept [domain key ...]`. The filter is `[domain [key]]` instead — one optional domain, one optional key — which also lets `accept <domain>` take every drifting row in a domain. A list of pairs would need an array, and expanding an empty array under `set -u` is an error in bash 3.2.
- Produces: `run_accept` (rewrites `$TABLE` in place), called from `main` instead of the per-row loop.

- [ ] **Step 1: Write the failing tests**

Append to `test/test_macos_defaults.sh`, above the runner block:

```bash
test_accept_updates_a_drifting_value() {
    darwin_only "accept rewrites a drifting row to the live value" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    row "$DOMAIN" Count int 7 > "$TABLE"
    mdefaults accept
    if [ "$status" = 0 ] && grep -q "	int	3$" "$TABLE"; then
        ok "accept rewrites a drifting row to the live value"
    else
        bad "accept rewrites a drifting row to the live value (status=$status, table=$(cat "$TABLE"))"
    fi
}

# The comments carried over from .macos are the most valuable thing in the
# table, and accept rewrites the file wholesale.
test_accept_preserves_comments_and_blanks() {
    darwin_only "accept preserves comments and blank lines" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    {
        printf '# a banner\n'
        printf '\n'
        printf '# why this setting exists\n'
        row "$DOMAIN" Count int 7
    } > "$TABLE"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(head -1 "$TABLE")" = "# a banner" ] \
        && [ "$(sed -n 3p "$TABLE")" = "# why this setting exists" ] \
        && [ -z "$(sed -n 2p "$TABLE")" ]; then
        ok "accept preserves comments and blank lines"
    else
        bad "accept preserves comments and blank lines (status=$status, table=$(cat "$TABLE"))"
    fi
}

test_accept_leaves_matching_rows_alone() {
    darwin_only "accept leaves a matching row byte-identical" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 7
    row "$DOMAIN" Count int 7 > "$TABLE"
    before="$(cksum < "$TABLE")"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(cksum < "$TABLE")" = "$before" ]; then
        ok "accept leaves a matching row byte-identical"
    else
        bad "accept leaves a matching row byte-identical (status=$status, out=$out)"
    fi
}

# The 9 noaudit=unset rows exist because their key was absent at seed time. Once
# a key becomes readable the marker is stale, and only accept can clear it.
test_accept_promotes_a_readable_unset_row() {
    darwin_only "accept clears noaudit=unset once the key reads" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    row "$DOMAIN" Count int 7 noaudit=unset > "$TABLE"
    mdefaults accept
    if [ "$status" = 0 ] && ! grep -q "noaudit=unset" "$TABLE" && grep -q "	int	3$" "$TABLE"; then
        ok "accept clears noaudit=unset once the key reads"
    else
        bad "accept clears noaudit=unset once the key reads (status=$status, table=$(cat "$TABLE"))"
    fi
}

test_accept_updates_the_type_when_it_drifts() {
    darwin_only "accept rewrites the type column too" || return 0
    sandbox
    defaults write "$DOMAIN" Count -string seven
    row "$DOMAIN" Count int 7 > "$TABLE"
    mdefaults accept
    if [ "$status" = 0 ] && grep -q "	string	seven$" "$TABLE"; then
        ok "accept rewrites the type column too"
    else
        bad "accept rewrites the type column too (status=$status, table=$(cat "$TABLE"))"
    fi
}

test_accept_honors_the_filter() {
    darwin_only "accept honors the domain and key filter" || return 0
    sandbox
    defaults write "$DOMAIN" First -int 1
    defaults write "$DOMAIN" Second -int 2
    {
        row "$DOMAIN" First int 9
        row "$DOMAIN" Second int 9
    } > "$TABLE"
    mdefaults accept "$DOMAIN" Second
    if [ "$status" = 0 ] && grep -q "First	int	9$" "$TABLE" && grep -q "Second	int	2$" "$TABLE"; then
        ok "accept honors the domain and key filter"
    else
        bad "accept honors the domain and key filter (status=$status, table=$(cat "$TABLE"))"
    fi
}
```

Add to the runner block:

```bash
test_accept_updates_a_drifting_value
test_accept_preserves_comments_and_blanks
test_accept_leaves_matching_rows_alone
test_accept_promotes_a_readable_unset_row
test_accept_updates_the_type_when_it_drifts
test_accept_honors_the_filter
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
./test/test_macos_defaults.sh
```

Expected: 6 new tests FAIL on macOS, SKIP on Linux.

- [ ] **Step 3: Add `run_accept`**

In `scripts/macos-defaults.sh`, insert after `apply_row`:

```bash
run_accept() {
    local i n idx live live_type new_status tmp line trimmed
    local new_row=()

    n="${#t_domain[@]}"
    i=0
    while [ "$i" -lt "$n" ]; do
        new_row[$i]=""
        if row_selected "$i" && condition_matches "${t_status[$i]}"; then
            if live="$(defaults_read "${t_domain[$i]}" "${t_key[$i]}")"; then
                new_status="${t_status[$i]}"
                # The marker only recorded that the key was unreadable at seed
                # time; it just read, so it no longer describes anything.
                if [ "$new_status" = "noaudit=unset" ]; then
                    new_status=""
                fi
                live_type="${t_type[$i]}"
                if [ "$live_type" != raw ] && [ "$new_status" = "" ]; then
                    if live_type="$(defaults_read_type "${t_domain[$i]}" "${t_key[$i]}")"; then
                        live_type="$(table_type_of "$live_type")"
                    else
                        live_type="${t_type[$i]}"
                    fi
                fi
                if [ "$live_type" != "${t_type[$i]}" ] \
                    || [ "$(normalize "$live_type" "$live")" != "$(normalize "${t_type[$i]}" "${t_value[$i]}")" ] \
                    || [ "$new_status" != "${t_status[$i]}" ]; then
                    new_row[$i]="${t_domain[$i]}$TAB${t_key[$i]}$TAB$live_type$TAB$live"
                    if [ -n "$new_status" ]; then
                        new_row[$i]="${new_row[$i]}$TAB$new_status"
                    fi
                    echo "accept: ${t_domain[$i]} ${t_key[$i]} = $live"
                fi
            fi
        fi
        i=$((i + 1))
    done

    tmp="$(mktemp "${TMPDIR:-/tmp}/macos-defaults.XXXXXX")"
    idx=0
    while IFS= read -r line || [ -n "$line" ]; do
        trimmed="${line#"${line%%[![:space:]]*}"}"
        case "$trimmed" in
            "" | "#"*)
                printf '%s\n' "$line" >>"$tmp"
                continue
                ;;
        esac
        if [ -n "${new_row[$idx]}" ]; then
            printf '%s\n' "${new_row[$idx]}" >>"$tmp"
        else
            printf '%s\n' "$line" >>"$tmp"
        fi
        idx=$((idx + 1))
    done <"$TABLE"

    if [ "$dry_run" = 1 ]; then
        rm -f "$tmp"
        return 0
    fi
    mv "$tmp" "$TABLE"
}
```

- [ ] **Step 4: Dispatch `accept` from `main`**

In `main`, immediately after the `check` block, add:

```bash
    if [ "$mode" = accept ]; then
        run_accept
        return 0
    fi
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
./test/test_macos_defaults.sh
```

Expected on macOS: 34 passed, 0 failed. On Linux: 15 passed, 0 failed, 19 skipped.

- [ ] **Step 6: Commit**

```bash
git add scripts/macos-defaults.sh test/test_macos_defaults.sh
git commit -m "Add accept mode to macos-defaults

Rewrites a row's value and type from what is live, and clears a
noaudit=unset marker once the key reads. Rewriting the file wholesale means
comments and blank lines have to survive intact, which is tested: those
comments are the why carried over from .macos."
```

---

### Task 5: Generate the table from `.macos`

Transcribes 218 rows mechanically. The generator is committed rather than run and discarded so the transcription is reviewable, following the `scripts/migrate-to-home.sh` precedent.

**Files:**
- Create: `scripts/migrate-macos-defaults.sh`
- Create: `macos-defaults`

**Interfaces:**
- Consumes: `scripts/macos-defaults.sh check` for validation.
- Produces: `scripts/migrate-macos-defaults.sh [--remainder]`. Default mode prints the table to stdout. `--remainder` prints the lines of `.macos` that did *not* become table rows, which Task 7 uses to rewrite `.macos`.

- [ ] **Step 1: Write the generator**

Create `scripts/migrate-macos-defaults.sh`:

```bash
#!/bin/bash
# One-shot: split .macos into the macos-defaults table (default) and the
# imperative lines that stay behind (--remainder). Committed so the 218-row
# transcription can be reviewed rather than trusted.
set -euf -o pipefail

DOTS="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$DOTS/.macos"
TAB=$'\t'
mode=table

if [ $# -gt 0 ]; then
    case "$1" in
        --remainder) mode=remainder ;;
        *)
            echo "usage: $0 [--remainder]" >&2
            exit 2
            ;;
    esac
fi

pending=()

flush_pending() {
    local p
    if [ "${#pending[@]}" -gt 0 ]; then
        for p in "${pending[@]}"; do
            printf '%s\n' "$p"
        done
    fi
    pending=()
}

quote_tail() {
    local out="" a
    for a in "$@"; do
        out="$out${out:+ }$(printf '%q' "$a")"
    done
    printf '%s' "$out"
}

# Absent from the live machine for two different reasons that need different
# markers: a whole domain that will not read is TCC, a readable domain missing
# one key is simply unset.
classify() {
    local domain="$1" key="$2" host_flag=""
    case "$domain" in
        currentHost:*)
            host_flag="-currentHost"
            domain="${domain#currentHost:}"
            ;;
    esac
    # `command` is required: this runs inside the `defaults` shim below, and a
    # bare call would re-enter it instead of reaching the binary.
    if command defaults $host_flag read "$domain" "$key" >/dev/null 2>&1; then
        printf ''
        return 0
    fi
    if command defaults $host_flag read "$domain" >/dev/null 2>&1; then
        printf 'noaudit=unset'
    else
        printf 'noaudit=tcc'
    fi
}

emit() {
    local host="$1" domain="$2" key="$3" type="$4" value="$5" status
    if [ "$mode" = remainder ]; then
        pending=()
        return 0
    fi
    if [ "$host" = currentHost ]; then
        domain="currentHost:$domain"
    fi
    # Continuation lines in .macos are tab-indented; a surviving tab would add a
    # phantom column.
    value="${value//$TAB/ }"
    case "$type" in
        array | dict | dict-add | date | data) status="noaudit=complex" ;;
        *) status="$(classify "$domain" "$key")" ;;
    esac
    flush_pending
    if [ -n "$status" ]; then
        printf '%s\n' "$domain$TAB$key$TAB$type$TAB$value$TAB$status"
    else
        printf '%s\n' "$domain$TAB$key$TAB$type$TAB$value"
    fi
}

defaults() {
    local host=""
    if [ "$1" = "-currentHost" ]; then
        host=currentHost
        shift
    fi
    if [ "$1" != write ]; then
        return 0
    fi
    shift
    local domain="$1" key="$2"
    shift 2
    case "$1" in
        -bool | -boolean) emit "$host" "$domain" "$key" bool "$2" ;;
        -int | -integer) emit "$host" "$domain" "$key" int "$2" ;;
        -float) emit "$host" "$domain" "$key" float "$2" ;;
        -string) emit "$host" "$domain" "$key" string "$2" ;;
        -date) emit "$host" "$domain" "$key" date "$2" ;;
        -data) emit "$host" "$domain" "$key" data "$2" ;;
        -array | -array-add)
            shift
            emit "$host" "$domain" "$key" array "$(quote_tail "$@")"
            ;;
        -dict)
            shift
            emit "$host" "$domain" "$key" dict "$(quote_tail "$@")"
            ;;
        -dict-add)
            shift
            emit "$host" "$domain" "$key" dict-add "$(quote_tail "$@")"
            ;;
        # An untyped value is handed to `defaults` to parse as a plist fragment,
        # which is what `AdminHostInfo HostName` and `mouse.scaling -1` rely on.
        *) emit "$host" "$domain" "$key" raw "$1" ;;
    esac
}

sudo() { "$@"; }

while IFS= read -r line || [ -n "$line" ]; do
    while [ "${line%\\}" != "$line" ]; do
        line="${line%\\}"
        IFS= read -r next || break
        line="$line${next#"${next%%[![:space:]]*}"}"
    done
    trimmed="${line#"${line%%[![:space:]]*}"}"
    case "$trimmed" in
        "" | "#"*)
            pending+=("$line")
            continue
            ;;
        "defaults write "* | "defaults -currentHost write "* | "sudo defaults write "*)
            eval "$trimmed"
            ;;
        *)
            if [ "$mode" = remainder ]; then
                flush_pending
                printf '%s\n' "$line"
            else
                pending=()
            fi
            ;;
    esac
done <"$SOURCE"
```

- [ ] **Step 2: Make it executable and generate the table**

```bash
chmod +x scripts/migrate-macos-defaults.sh
./scripts/migrate-macos-defaults.sh > macos-defaults
```

- [ ] **Step 3: Verify no `defaults write` line was dropped**

```bash
declared=$(grep -cE '^[[:space:]]*(sudo )?defaults (-currentHost )?write ' .macos)
rows=$(grep -cvE '^[[:space:]]*(#|$)' macos-defaults)
echo "declared=$declared rows=$rows"
[ "$declared" = "$rows" ] && echo "no rows dropped"
```

Expected: `declared=218 rows=218 / no rows dropped`. If the counts differ, a `defaults write` form is unhandled; find it by diffing the domain/key pairs rather than guessing.

- [ ] **Step 4: Verify the table parses**

```bash
./scripts/macos-defaults.sh check
```

Expected: `ok: 218 rows in <repo>/macos-defaults`. A failure here names the offending line; the likely causes are a tab that survived a continuation join or a container row that missed its `noaudit=complex`.

- [ ] **Step 5: Verify the marker counts match the design probe**

```bash
for r in tcc unset complex; do printf '%-8s %s\n' "$r" "$(grep -c "noaudit=$r$" macos-defaults)"; done
grep -cvE '^[[:space:]]*(#|$)' macos-defaults
```

Expected: `tcc 44`, `unset 5`, `complex 11`, total 218, leaving 158 rows with no status. A material difference means the machine changed since the probe, which is worth reading before continuing rather than accepting silently.

- [ ] **Step 6: Read the generated table**

Skim `macos-defaults` end to end. Confirm each row's comment still sits above the right row and that no comment belonging to an imperative line (the `PlistBuddy` block, `chflags`, `nvram`) came across. Fix anything misplaced by hand; the generator's job was the rows, not editorial judgment.

- [ ] **Step 7: Commit**

```bash
git add scripts/migrate-macos-defaults.sh macos-defaults
git commit -m "Generate the macos-defaults table from .macos

218 rows transcribed mechanically, with each setting's comment carried
across. Container types get noaudit=complex; keys that will not read get
noaudit=tcc when the whole domain is unreadable and noaudit=unset when only
the key is absent.

.macos is untouched here, so the two files declare the same settings until
the next commit strips it."
```

---

### Task 6: Seed from the live machine and resolve the four drifts

Machine-specific and run once. Its test is `audit` exiting 0.

**Files:**
- Modify: `macos-defaults`
- Modify: `docs/superpowers/specs/2026-08-25-macos-defaults-declarative-design.md` (record the TCC write finding)

**Interfaces:**
- Consumes: `audit`, `apply`, `accept` from Tasks 2-4.
- Produces: a table whose `audit` exits 0 on this machine.

- [ ] **Step 1: Capture the baseline audit**

```bash
./scripts/macos-defaults.sh audit > /tmp/audit-before.txt || true
for label in ok drift missing skip; do printf '%-8s %s\n' "$label" "$(grep -c "^$label:" /tmp/audit-before.txt)"; done
```

Expected: `ok 154`, `drift 4`, `missing 0`, `skip 60`. `missing` should be zero because Task 5 already marked every unreadable key.

- [ ] **Step 2: Confirm the four drifts are the ones the spec predicted**

```bash
grep '^drift:' /tmp/audit-before.txt
```

Expected, in some order:

```
drift: NSGlobalDomain AppleLocale want=en_US@currency=USD live=en_US@currency=usd
drift: com.apple.ActivityMonitor ShowCategory want=0 live=100
drift: com.apple.ActivityMonitor OpenMainWindow want=1 live=0
drift: .GlobalPreferences com.apple.mouse.scaling want=-1 live=3
```

A fifth drift is new information, not a bug. Read it and decide before continuing.

- [ ] **Step 3: Accept the three the machine wins**

```bash
./scripts/macos-defaults.sh accept NSGlobalDomain AppleLocale
./scripts/macos-defaults.sh accept com.apple.ActivityMonitor ShowCategory
./scripts/macos-defaults.sh accept com.apple.ActivityMonitor OpenMainWindow
git diff macos-defaults
```

Expected: exactly three changed rows, each taking the live value.

- [ ] **Step 4: Reapply the one the table wins**

Mouse acceleration is the setting this whole change exists to catch, so the table wins rather than the machine.

```bash
./scripts/macos-defaults.sh apply .GlobalPreferences com.apple.mouse.scaling
defaults read .GlobalPreferences com.apple.mouse.scaling
```

Expected: `write:` on the apply, then `-1` from the read.

- [ ] **Step 5: Verify audit is green**

```bash
./scripts/macos-defaults.sh audit > /tmp/audit-after.txt; echo "exit=$?"
for label in ok drift missing skip; do printf '%-8s %s\n' "$label" "$(grep -c "^$label:" /tmp/audit-after.txt)"; done
```

Expected: `exit=0`, `ok 158`, `drift 0`, `missing 0`, `skip 60`.

- [ ] **Step 6: Ask the owner before probing TCC writes**

The spec's one open risk: reads to `com.apple.Safari` definitely fail under TCC, but whether `defaults write` still lands is unknown. If writes fail too, 35 Safari settings have not applied on a fresh Mac in years.

Answering it means writing to a real Safari preference. **Stop and ask before running this.** With approval:

```bash
defaults read com.apple.Safari AlwaysRestoreSessionAtLaunch; echo "read exit=$?"
defaults write com.apple.Safari AlwaysRestoreSessionAtLaunch -bool true; echo "write exit=$?"
defaults read com.apple.Safari AlwaysRestoreSessionAtLaunch; echo "read-back exit=$?"
```

Three outcomes, each with a different consequence:

| Result | Meaning | Action |
|---|---|---|
| write exits non-zero | `.macos` has not applied Safari settings for years | Record it in the spec; consider dropping the 35 rows or documenting the FDA requirement |
| write exits 0, read-back still fails | The write went somewhere unreadable from this shell | Record it; the rows stay `noaudit=tcc` and apply keeps attempting them |
| write exits 0, read-back succeeds | TCC blocks the domain only until something touches it | Re-run `classify` for the Safari rows; some may promote out of `noaudit=tcc` |

- [ ] **Step 7: Record the finding in the spec**

Replace the spec's "Open risk" section with what Step 6 actually showed, including the commands and their exit codes. An open risk that has been answered should stop reading as open.

- [ ] **Step 8: Commit**

```bash
git add macos-defaults docs/superpowers/specs/2026-08-25-macos-defaults-declarative-design.md
git commit -m "Seed macos-defaults from the live machine

Three drifting rows take the machine's value: AppleLocale (macOS
canonicalized the currency code) and two Activity Monitor keys the app
rewrites itself. The fourth, .GlobalPreferences com.apple.mouse.scaling,
goes the other way — the table disables mouse acceleration and the machine
had turned it back on, which is the drift this change exists to catch.

audit now exits 0: 158 ok, 60 skipped."
```

---

### Task 7: Strip `.macos`, wire the Makefile, update the docs

**Files:**
- Modify: `.macos`
- Modify: `Makefile`
- Modify: `.editorconfig`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: `scripts/migrate-macos-defaults.sh --remainder`, `scripts/macos-defaults.sh check`.
- Produces: `make macos-audit|macos-apply|macos-accept|check-macos-defaults`; `check-macos-defaults` joins `preflight`.

- [ ] **Step 1: Rewrite `.macos` as the remainder**

```bash
./scripts/migrate-macos-defaults.sh --remainder > /tmp/macos.remainder
wc -l /tmp/macos.remainder
```

Expected: roughly 45 lines. Read it before moving it into place; it should contain the System Settings quit, the sudo keepalive, `nvram`, `systemsetup`, the nine `PlistBuddy` calls, both `chflags`, `lsregister`, the Dock `find -delete`, `tmutil`, the `killall` loop, and the closing echo.

```bash
cp /tmp/macos.remainder .macos
```

- [ ] **Step 2: Restore the shebang and add a pointer**

`--remainder` drops the shebang along with the leading comments. Put it back and say where the settings went, since the next reader will look here first:

```bash
#!/usr/bin/env bash

# ~/.macos — the imperative remainder. Every `defaults write` that used to live
# here is now a row in ./macos-defaults; run `make macos-audit` to compare them
# against the machine. What is left cannot be expressed as a domain/key/value:
# nvram, systemsetup, PlistBuddy, chflags, and the app restarts.
```

- [ ] **Step 3: Tidy the remainder by hand**

Remove any section banner whose settings all moved to the table, and any comment left without a statement under it. This is a ~45 line file; read the whole thing.

- [ ] **Step 4: Verify `.macos` is still valid shell**

```bash
bash -n .macos && echo "syntax ok"
grep -c 'defaults write' .macos
```

Expected: `syntax ok`, and `0` uncommented `defaults write` lines. Commented-out examples may remain; check with `grep -n 'defaults write' .macos` that every hit starts with `#`.

- [ ] **Step 5: Add the Makefile targets**

Replace the existing `macos:` target with:

```make
macos-audit:
	@./scripts/macos-defaults.sh audit

macos-apply:
	./scripts/macos-defaults.sh apply

macos-accept:
	./scripts/macos-defaults.sh accept

check-macos-defaults:
	@./scripts/macos-defaults.sh check

macos: macos-apply
	sh .macos
	osascript -e 'tell app "loginwindow" to «event aevtrrst»'
```

Add `./test/test_macos_defaults.sh` to the `test:` target, append `check-macos-defaults` to `preflight:`, and add the four new target names to `.PHONY`.

- [ ] **Step 6: Add the `.editorconfig` stanza**

```ini
[macos-defaults]
# Columns are tab-separated data, not indentation.
indent_style = unset
```

- [ ] **Step 7: Update `CLAUDE.md`**

Under Commands, after the `deploy.sh` line:

```markdown
- `./scripts/macos-defaults.sh check|audit|apply|accept [--dry-run] [domain [key]]` — the `macos-defaults` table. `make macos-audit` reports drift and needs no sudo; `make macos-apply` writes; `make macos-accept` rewrites rows to match the machine. `make macos` = apply plus the imperative remainder in `.macos` plus a restart.
```

Under Architecture, after the `manifest` + `deploy.sh` bullet:

```markdown
- **`macos-defaults` + `scripts/macos-defaults.sh`** — tab-delimited (keys contain spaces, so this one is not whitespace-columned like `manifest`): domain, key, type, value, optional status. A `noaudit=tcc|unset|complex` status means apply writes the row but audit cannot check it — Safari and Mail live in TCC-protected containers no shell can read, and `array`/`dict` values have no comparable form. `.macos` keeps only what has no domain/key/value shape. Design and probe numbers: `docs/superpowers/specs/2026-08-25-macos-defaults-declarative-design.md`.
```

- [ ] **Step 8: Run the full gate**

```bash
make preflight
```

Expected: `test_deploy.sh`, `test_shell.sh`, and `test_macos_defaults.sh` all pass, and every `check-*` target passes including `check-macos-defaults`. If `check-editorconfig` reports `macos-defaults`, the trailing-whitespace or final-newline rule was violated by the generator.

- [ ] **Step 9: Verify the whole thing end to end**

```bash
./scripts/macos-defaults.sh audit; echo "audit exit=$?"
./scripts/macos-defaults.sh --dry-run apply | grep -c '^would:'
```

Expected: audit exits 0, and dry-run proposes writes only for the 60 `noaudit` rows (which apply always writes) and nothing else.

- [ ] **Step 10: Commit**

```bash
git add .macos Makefile .editorconfig CLAUDE.md
git commit -m "Retire the defaults section of .macos

.macos drops to its imperative remainder: nvram, systemsetup, PlistBuddy,
chflags, lsregister, tmutil and the app restarts. Everything with a
domain/key/value shape now lives in macos-defaults.

make macos-audit is the one meant for casual use and needs no sudo; root
owned plists under /Library/Preferences are world-readable, so only apply
ever reaches for it. check-macos-defaults joins preflight, so CI picks it
up on both legs without an ci.yml edit."
```

---

## Verification Summary

| Claim | How it is checked | Where |
|---|---|---|
| The parser handles what `deploy.sh`'s would not | `#` inside a value, key with spaces, empty trailing column | Task 1 Step 4 |
| Comparison is not a naive string equality | bool normalization, type drift, missing vs drift | Task 2 Step 5 |
| Apply never prompts for a password in tests | Full suite runs with no `Password:` prompt | Task 3 Step 5 |
| Accept preserves the commentary carried from `.macos` | Comment and blank-line placement asserted | Task 4 Step 5 |
| No setting was lost in transcription | 218 declared = 218 rows; marker counts match the probe | Task 5 Steps 3 and 5 |
| The table describes this machine | `audit` exits 0 | Task 6 Step 5 |
| `.macos` still runs | `bash -n`, zero uncommented `defaults write` | Task 7 Step 4 |
| CI covers all of it on both platforms | `make preflight` | Task 7 Step 8 |
