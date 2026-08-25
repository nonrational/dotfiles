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
test_audit_skips_unmatched_condition
test_audit_ok_when_value_matches
test_audit_normalizes_bools
test_audit_reports_drift
test_audit_reports_missing
test_audit_reports_type_drift
test_audit_skips_noaudit_rows_without_failing
test_audit_filters_by_domain_and_key

echo
echo "$pass passed, $fail failed, $skipped skipped"
[ "$fail" -eq 0 ]
