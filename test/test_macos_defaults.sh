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
# one. The live value is pre-set to MATCH the table here: an ordinary row would
# report ok: and skip, so only an unconditional write reports write:.
test_apply_writes_noaudit_rows() {
    darwin_only "apply writes noaudit rows unconditionally" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 7
    row "$DOMAIN" Count int 7 noaudit=unset > "$TABLE"
    mdefaults apply
    if [ "$status" = 0 ] && grep -q "^write: " <<<"$out" && ! grep -q "^ok: " <<<"$out" \
        && [ "$(defaults read "$DOMAIN" Count)" = 7 ]; then
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

# A complex row's value column is an eval argument tail, and `defaults read`
# returns a multi-line plist dump for an array. Rewriting the row splices those
# newlines into the table and breaks every row after it.
test_accept_never_rewrites_a_readable_complex_row() {
    darwin_only "accept leaves a readable complex row byte-identical" || return 0
    sandbox
    defaults write "$DOMAIN" Langs -array en fr
    row "$DOMAIN" Langs array '"en" "fr"' noaudit=complex > "$TABLE"
    before="$(cksum < "$TABLE")"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(cksum < "$TABLE")" = "$before" ] \
        && [ "$(wc -l < "$TABLE")" -eq 1 ]; then
        ok "accept leaves a readable complex row byte-identical"
    else
        bad "accept leaves a readable complex row byte-identical (status=$status, table=$(cat "$TABLE"))"
    fi
}

# The tcc marker records that a domain is unreadable under TCC, which a sandbox
# cannot simulate. A readable key with the marker set is the same code path.
test_accept_never_rewrites_a_tcc_row() {
    darwin_only "accept leaves a noaudit=tcc row untouched even when the key reads" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    row "$DOMAIN" Count int 7 noaudit=tcc > "$TABLE"
    before="$(cksum < "$TABLE")"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(cksum < "$TABLE")" = "$before" ]; then
        ok "accept leaves a noaudit=tcc row untouched even when the key reads"
    else
        bad "accept leaves a noaudit=tcc row untouched even when the key reads (status=$status, table=$(cat "$TABLE"))"
    fi
}

# The table keeps ${HOME} literal so a row is portable; audit has to expand it
# or these two rows report drift on every machine, including the one that wrote them.
test_audit_expands_the_home_token() {
    darwin_only "audit expands \${HOME} before comparing" || return 0
    sandbox
    defaults write "$DOMAIN" Where -string "$HOME/Desktop"
    row "$DOMAIN" Where string '${HOME}/Desktop' > "$TABLE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^ok: " <<<"$out"; then
        ok "audit expands \${HOME} before comparing"
    else
        bad "audit expands \${HOME} before comparing (status=$status, out=$out)"
    fi
}

test_apply_expands_the_home_token() {
    darwin_only "apply writes the expanded \${HOME} path" || return 0
    sandbox
    row "$DOMAIN" Where string '${HOME}/Desktop' > "$TABLE"
    mdefaults apply
    if [ "$status" = 0 ] && [ "$(defaults read "$DOMAIN" Where)" = "$HOME/Desktop" ]; then
        ok "apply writes the expanded \${HOME} path"
    else
        bad "apply writes the expanded \${HOME} path (status=$status, out=$out)"
    fi
}

# Without this, accepting one of these rows would bake the literal home
# directory back into the table and undo the whole point.
test_accept_tokenizes_the_home_path() {
    darwin_only "accept stores \${HOME} rather than the literal path" || return 0
    sandbox
    defaults write "$DOMAIN" Where -string "$HOME/Downloads"
    row "$DOMAIN" Where string '${HOME}/Desktop' > "$TABLE"
    mdefaults accept
    if [ "$status" = 0 ] && grep -q 'Downloads$' "$TABLE" && ! grep -q "$HOME" "$TABLE"; then
        ok "accept stores \${HOME} rather than the literal path"
    else
        bad "accept stores \${HOME} rather than the literal path (status=$status, table=$(cat "$TABLE"))"
    fi
}

# The token rows are the ones most likely to be accepted spuriously: the table
# holds ${HOME} and the machine holds the expanded path, so an unexpanded
# comparison always reports a change even when nothing drifted.
test_accept_leaves_a_tokenized_matching_row_alone() {
    darwin_only "accept leaves a matching \${HOME} row alone and says nothing" || return 0
    sandbox
    defaults write "$DOMAIN" Where -string "$HOME/Desktop"
    row "$DOMAIN" Where string '${HOME}/Desktop' > "$TABLE"
    before="$(cksum < "$TABLE")"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(cksum < "$TABLE")" = "$before" ] \
        && ! grep -q "^accept: " <<<"$out"; then
        ok "accept leaves a matching \${HOME} row alone and says nothing"
    else
        bad "accept leaves a matching \${HOME} row alone and says nothing (status=$status, out=$out)"
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
test_apply_writes_missing_key
test_apply_is_idempotent
test_dry_run_reports_would_write
test_dry_run_changes_nothing
test_apply_writes_noaudit_rows
test_apply_writes_container_value
test_apply_skips_unmatched_condition
test_accept_updates_a_drifting_value
test_accept_preserves_comments_and_blanks
test_accept_leaves_matching_rows_alone
test_accept_promotes_a_readable_unset_row
test_accept_updates_the_type_when_it_drifts
test_accept_honors_the_filter
test_accept_never_rewrites_a_readable_complex_row
test_accept_never_rewrites_a_tcc_row
test_audit_expands_the_home_token
test_apply_expands_the_home_token
test_accept_tokenizes_the_home_path
test_accept_leaves_a_tokenized_matching_row_alone

echo
echo "$pass passed, $fail failed, $skipped skipped"
[ "$fail" -eq 0 ]
