#!/bin/bash
# Tests for scripts/macos-defaults.sh. Parsing the `defaults write` lines runs
# on any platform; anything that shells out to `defaults` is Darwin-only and
# skipped elsewhere.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-macos-defaults.XXXXXX")"
BASE="$(cd "$BASE" && pwd)"
trap 'rm -rf "$BASE"' EXIT

source "$ROOT/scripts/host-id.sh"
THIS_HOST="$(host_id)"

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
    SOURCE="$SB/macos"
    DOMAIN="$SB/com.example.test"
}

mdefaults() {
    set +e
    out="$(MACOS_DEFAULTS_SOURCE="$SOURCE" "$ROOT/scripts/macos-defaults.sh" "$@" 2>&1)"
    status=$?
    set -e
}

# Quote one argument the way .macos spells it: bare when plain, double quoted
# otherwise. ${HOME} stays inside double quotes so the shell expands it.
q() {
    case "$1" in
        *[!A-Za-z0-9_./:@+=,-]*) printf '"%s"' "$1" ;;
        *) printf '%s' "$1" ;;
    esac
}

# Emit one `defaults write` line: domain, key, type, value, optional marker.
# A container type's value is passed through verbatim as its argument tail.
setting() {
    local domain="$1" key="$2" type="$3" value="$4" marker="${5:-}" out
    out="defaults write $(q "$domain") $(q "$key")"
    case "$type" in
        raw) out="$out $(q "$value")" ;;
        array | dict | dict-add) out="$out -$type $value" ;;
        *) out="$out -$type $(q "$value")" ;;
    esac
    if [ -n "$marker" ]; then
        out="$out # $marker"
    fi
    printf '%s\n' "$out"
}

darwin_only() {
    if [ "$(uname)" != "Darwin" ]; then
        note "$1 (not Darwin)"
        return 1
    fi
    return 0
}

# --- parsing ----------------------------------------------------------------

test_rejects_unknown_flag() {
    sandbox
    setting NSGlobalDomain SomeKey bool true > "$SOURCE"
    mdefaults --bogus
    if [ "$status" = 2 ] && grep -q "usage:" <<<"$out"; then
        ok "unknown flag exits 2 with usage"
    else
        bad "unknown flag exits 2 with usage (status=$status, out=$out)"
    fi
}

test_rejects_missing_source() {
    sandbox
    mdefaults check
    if [ "$status" = 1 ] && grep -q "source not found" <<<"$out"; then
        ok "missing source exits 1"
    else
        bad "missing source exits 1 (status=$status, out=$out)"
    fi
}

test_rejects_a_write_with_no_value() {
    sandbox
    printf 'defaults write NSGlobalDomain SomeKey\n' > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "line 1" <<<"$out"; then
        ok "a write with no value exits 1 naming the line"
    else
        bad "a write with no value exits 1 naming the line (status=$status, out=$out)"
    fi
}

test_rejects_a_write_with_a_stray_argument() {
    sandbox
    printf 'defaults write NSGlobalDomain SomeKey -int 1 2\n' > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "line 1" <<<"$out"; then
        ok "a write with a stray argument exits 1 naming the line"
    else
        bad "a write with a stray argument exits 1 naming the line (status=$status, out=$out)"
    fi
}

test_rejects_unknown_type_flag() {
    sandbox
    printf 'defaults write NSGlobalDomain SomeKey -number 4\n' > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "unknown type flag" <<<"$out"; then
        ok "unknown type flag exits 1"
    else
        bad "unknown type flag exits 1 (status=$status, out=$out)"
    fi
}

# `defaults write .GlobalPreferences com.apple.mouse.scaling -1` is a real
# line: a leading minus followed by a digit is a value, not a flag.
test_negative_untyped_value_is_a_value() {
    sandbox
    printf 'defaults write NSGlobalDomain Scale -1\n' > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "a negative untyped value parses as a raw value"
    else
        bad "a negative untyped value parses as a raw value (status=$status, out=$out)"
    fi
}

# A line copied from macos-defaults.com often ends in `&& killall Dock`. audit
# and check are read-only, so anything the shell would run besides the write
# is refused before the eval, and nothing after the write ever executes.
test_rejects_a_trailing_command_and_does_not_run_it() {
    sandbox
    printf 'defaults write NSGlobalDomain SomeKey -bool true && touch "%s/ran"\n' "$SB" > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "line 1" <<<"$out" && [ ! -e "$SB/ran" ]; then
        ok "a trailing && command is rejected and not run"
    else
        bad "a trailing && command is rejected and not run (status=$status, out=$out)"
    fi
}

test_rejects_command_substitution_inside_quotes() {
    sandbox
    printf 'defaults write NSGlobalDomain SomeKey -string "$(touch %s/ran)"\n' "$SB" > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "line 1" <<<"$out" && [ ! -e "$SB/ran" ]; then
        ok "a \$(...) inside quotes is rejected and not run"
    else
        bad "a \$(...) inside quotes is rejected and not run (status=$status, out=$out)"
    fi
}

test_rejects_semicolons_pipes_and_backticks() {
    local bad_line failed=0
    for bad_line in \
        'defaults write NSGlobalDomain SomeKey -bool true; echo hi' \
        'defaults write NSGlobalDomain SomeKey -bool true | cat' \
        'defaults write NSGlobalDomain SomeKey -string `hostname`' \
        'defaults write NSGlobalDomain SomeKey -string $PATH' \
        'defaults write NSGlobalDomain SomeKey -string *.plist' \
        'defaults write NSGlobalDomain SomeKey -bool true > out'; do
        sandbox
        printf '%s\n' "$bad_line" > "$SOURCE"
        mdefaults check
        if [ "$status" != 1 ]; then
            failed=1
            echo "  not rejected: $bad_line"
        fi
    done
    if [ "$failed" = 0 ]; then
        ok "semicolons, pipes, backticks, expansions, globs and redirects are rejected"
    else
        bad "semicolons, pipes, backticks, expansions, globs and redirects are rejected"
    fi
}

# Appending can never converge: every apply would add the elements again.
test_rejects_array_add() {
    sandbox
    printf 'defaults write com.apple.dock persistent-apps -array-add "{tile-type=spacer-tile;}"\n' > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "array-add" <<<"$out"; then
        ok "-array-add exits 1"
    else
        bad "-array-add exits 1 (status=$status, out=$out)"
    fi
}

# A container row can also be per-host; the derived complex status must not
# overwrite the host marker.
test_host_marker_survives_on_a_container_row() {
    sandbox
    {
        setting com.example.d Langs array '"en" "fr"' host=nosuchhost
        setting com.example.d Langs array '"de"' host=anotherhost
    } > "$SOURCE"
    mdefaults --dry-run apply
    if [ "$status" = 0 ] && [ "$(grep -c '^skip: ' <<<"$out")" = 2 ] && ! grep -q '^would: ' <<<"$out"; then
        ok "a host marker on a container row scopes it and allows a sibling"
    else
        bad "a host marker on a container row scopes it and allows a sibling (status=$status, out=$out)"
    fi
}

test_two_markers_on_one_line_parse() {
    sandbox
    setting NSGlobalDomain SomeKey bool true "noaudit=unset host=nosuchhost" > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^skip: .*(host=nosuchhost)" <<<"$out"; then
        ok "a line may carry both a noaudit and a host marker"
    else
        bad "a line may carry both a noaudit and a host marker (status=$status, out=$out)"
    fi
}

# `# noaudit=unset because ...` used to parse as prose, silently dropping the
# marker and then losing the whole comment on accept.
test_rejects_a_marker_mixed_with_prose() {
    sandbox
    printf 'defaults write NSGlobalDomain SomeKey -bool true # noaudit=unset because the app clears it\n' > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "only key=value" <<<"$out"; then
        ok "a marker mixed with prose exits 1"
    else
        bad "a marker mixed with prose exits 1 (status=$status, out=$out)"
    fi
}

# Backslash-newline joins lines verbatim in the shell; stripping the next
# line's indentation would fuse `"a"` and `"b"` into one word.
test_continuation_lines_keep_their_whitespace() {
    darwin_only "a continued array keeps its elements apart" || return 0
    sandbox
    {
        printf 'defaults write %s Langs -array "en"\\\n' "$(q "$DOMAIN")"
        printf '\t"fr"\n'
    } > "$SOURCE"
    mdefaults apply
    if [ "$status" = 0 ] && [ "$(defaults read "$DOMAIN" Langs | tr -d '\n ')" = "(en,fr)" ]; then
        ok "a continued array keeps its elements apart"
    else
        bad "a continued array keeps its elements apart (status=$status, out=$out, live=$(defaults read "$DOMAIN" Langs 2>&1 | tr -d '\n'))"
    fi
}

# The shell discards a backslash inside a comment, so a comment ending in one
# must not swallow the line after it.
test_comment_ending_in_backslash_does_not_join() {
    sandbox
    {
        printf '# a path like C:\\\n'
        setting NSGlobalDomain FirstKey bool true
        setting NSGlobalDomain SecondKey bool true
    } > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "2 rows" <<<"$out"; then
        ok "a comment ending in a backslash does not swallow the next line"
    else
        bad "a comment ending in a backslash does not swallow the next line (status=$status, out=$out)"
    fi
}

test_rejects_unknown_marker() {
    sandbox
    setting NSGlobalDomain SomeKey bool true arch=arm64 > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "unknown marker" <<<"$out"; then
        ok "unknown marker exits 1"
    else
        bad "unknown marker exits 1 (status=$status, out=$out)"
    fi
}

# Whether a domain reads is decided at audit time, so a written-down tcc
# marker would only ever be stale.
test_rejects_tcc_marker() {
    sandbox
    setting com.apple.Safari SomeKey bool true noaudit=tcc > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "derived" <<<"$out"; then
        ok "a noaudit=tcc marker exits 1"
    else
        bad "a noaudit=tcc marker exits 1 (status=$status, out=$out)"
    fi
}

# A typed scalar can always be compared, so marking one complex would hide a
# drift forever.
test_rejects_complex_marker_on_a_typed_scalar() {
    sandbox
    setting NSGlobalDomain SomeKey bool true noaudit=complex > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "noaudit=complex" <<<"$out"; then
        ok "noaudit=complex on a typed scalar exits 1"
    else
        bad "noaudit=complex on a typed scalar exits 1 (status=$status, out=$out)"
    fi
}

# `com.apple.Safari ProxiesInBookmarksBar "()"` writes an empty array with no
# type flag; the marker is how that line says audit cannot compare it.
test_accepts_complex_marker_on_a_raw_value() {
    sandbox
    setting com.apple.Safari ProxiesInBookmarksBar raw "()" noaudit=complex > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "noaudit=complex on a raw value parses"
    else
        bad "noaudit=complex on a raw value parses (status=$status, out=$out)"
    fi
}

test_rejects_unset_marker_on_a_container() {
    sandbox
    setting com.example.d Langs array '"en" "fr"' noaudit=unset > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "container" <<<"$out"; then
        ok "noaudit=unset on a container exits 1"
    else
        bad "noaudit=unset on a container exits 1 (status=$status, out=$out)"
    fi
}

# Two lines for the same domain+key fight over the same write, so apply can
# never converge once they carry different values. dict-add is exempt: it
# legitimately repeats a domain+key, one line per dict entry.
test_rejects_duplicate_domain_and_key() {
    sandbox
    {
        setting com.example.d Count int 1
        setting com.example.d Count int 2
    } > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "duplicate" <<<"$out" && grep -q "line 2" <<<"$out"; then
        ok "duplicate domain+key exits 1 naming the second line"
    else
        bad "duplicate domain+key exits 1 naming the second line (status=$status, out=$out)"
    fi
}

test_allows_repeated_dict_add_domain_and_key() {
    sandbox
    {
        setting com.example.d Prefs dict-add '"a" 1'
        setting com.example.d Prefs dict-add '"b" 2'
    } > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "2 rows" <<<"$out"; then
        ok "repeated dict-add domain+key is allowed"
    else
        bad "repeated dict-add domain+key is allowed (status=$status, out=$out)"
    fi
}

# Two lines for one setting under different hosts is the point of the marker:
# the same key wanting different values per machine.
test_accepts_same_key_under_different_hosts() {
    sandbox
    {
        setting com.apple.dock tilesize int 36 host=other
        setting com.apple.dock tilesize int 48 host=another
    } > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "2 rows" <<<"$out"; then
        ok "same key under different hosts parses"
    else
        bad "same key under different hosts parses (status=$status, out=$out)"
    fi
}

# Same host means both lines apply on the same machine, so apply writes both
# and whichever loses drifts forever with no way to converge.
test_rejects_same_key_under_the_same_host() {
    sandbox
    {
        setting com.apple.dock tilesize int 36 host=other
        setting com.apple.dock tilesize int 48 host=other
    } > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "duplicate" <<<"$out"; then
        ok "same key under the same host exits 1"
    else
        bad "same key under the same host exits 1 (status=$status, out=$out)"
    fi
}

test_rejects_a_source_with_no_writes() {
    sandbox
    printf '#!/usr/bin/env bash\n# comments only\nsudo nvram SystemAudioVolume=" "\n' > "$SOURCE"
    mdefaults check
    if [ "$status" = 1 ] && grep -q "no defaults write lines" <<<"$out"; then
        ok "a source with no defaults write lines exits 1"
    else
        bad "a source with no defaults write lines exits 1 (status=$status, out=$out)"
    fi
}

# .macos keeps a commented-out multi-line spotlight write; it must contribute
# nothing, continuation lines included.
test_commented_out_write_is_ignored() {
    sandbox
    {
        printf '# defaults write com.apple.spotlight orderedItems -array \\\n'
        printf '# \t'"'"'{"enabled" = 1;"name" = "APPLICATIONS";}'"'"' \\\n'
        printf '# \t'"'"'{"enabled" = 0;"name" = "MUSIC";}'"'"'\n'
        setting NSGlobalDomain SomeKey bool true
    } > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "a commented-out write is ignored"
    else
        bad "a commented-out write is ignored (status=$status, out=$out)"
    fi
}

# Everything that is not a `defaults write` stays imperative and is not a
# row: nvram, PlistBuddy, killall, the sudo keep-alive loop.
test_non_defaults_lines_are_ignored_and_not_run() {
    sandbox
    {
        printf 'sudo nvram SystemAudioVolume=" "\n'
        printf 'killall Finder\n'
        printf 'touch "%s/ran"\n' "$SB"
        setting NSGlobalDomain SomeKey bool true
    } > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out" && [ ! -e "$SB/ran" ]; then
        ok "non-defaults lines are neither rows nor executed"
    else
        bad "non-defaults lines are neither rows nor executed (status=$status, out=$out)"
    fi
}

# `defaults delete` and `defaults read` lines are not desired state; treating
# them as rows would either misparse or invent a setting.
test_rejects_a_non_write_defaults_line_that_looks_like_one() {
    sandbox
    printf 'defaults write NSGlobalDomain SomeKey -bool true\nsudo defaults delete NSGlobalDomain Other\n' > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "a defaults delete line is not a row"
    else
        bad "a defaults delete line is not a row (status=$status, out=$out)"
    fi
}

test_hash_inside_a_quoted_value_is_not_a_marker() {
    sandbox
    setting com.example.app Greeting string "hello # host=x" > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "a # inside a quoted value does not start a marker"
    else
        bad "a # inside a quoted value does not start a marker (status=$status, out=$out)"
    fi
}

# A prose comment after a write is a comment to bash and nothing to the
# parser; only `key=value` is a marker.
test_prose_trailing_comment_is_not_a_marker() {
    sandbox
    printf 'defaults write NSGlobalDomain SomeKey -bool true # see mths.be/macos\n' > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "a prose trailing comment is not a marker"
    else
        bad "a prose trailing comment is not a marker (status=$status, out=$out)"
    fi
}

# `com.apple.print.PrintingPrefs "Quit When Finished"` is a real line.
test_key_with_spaces_parses() {
    sandbox
    setting com.apple.print.PrintingPrefs "Quit When Finished" bool true > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "a quoted key containing spaces parses"
    else
        bad "a quoted key containing spaces parses (status=$status, out=$out)"
    fi
}

test_continuation_lines_join_into_one_row() {
    sandbox
    {
        printf 'defaults write com.apple.finder FXInfoPanesExpanded -dict \\\n'
        printf '\tGeneral -bool true \\\n'
        printf '\tOpenWith -bool true\n'
    } > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "continuation lines join into one row"
    else
        bad "continuation lines join into one row (status=$status, out=$out)"
    fi
}

# `sudo defaults write /Library/Preferences/...` lines parse through a sudo
# shim; if the shim were missing this would prompt for a password or fail.
test_sudo_prefix_parses_without_sudo() {
    sandbox
    printf 'sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool true\n' > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "a sudo-prefixed write parses without invoking sudo"
    else
        bad "a sudo-prefixed write parses without invoking sudo (status=$status, out=$out)"
    fi
}

test_current_host_flag_parses() {
    sandbox
    printf 'defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1\n' > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "1 row" <<<"$out"; then
        ok "a -currentHost write parses"
    else
        bad "a -currentHost write parses (status=$status, out=$out)"
    fi
}

test_check_counts_rows() {
    sandbox
    {
        printf '#!/usr/bin/env bash\n# a banner\n'
        setting NSGlobalDomain FirstKey bool true
        printf '\nosascript -e '"'"'tell application "System Settings" to quit'"'"'\n'
        setting com.apple.Safari SecondKey bool true
    } > "$SOURCE"
    mdefaults check
    if [ "$status" = 0 ] && grep -q "2 rows" <<<"$out"; then
        ok "check counts write lines, ignoring comments, blanks and other commands"
    else
        bad "check counts write lines, ignoring comments, blanks and other commands (status=$status, out=$out)"
    fi
}

# A row whose host does not match is skipped before any `defaults` call, so
# this case needs no Darwin gate.
test_audit_skips_unmatched_host() {
    sandbox
    setting NSGlobalDomain SomeKey bool true host=nosuchhost > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^skip: " <<<"$out"; then
        ok "unmatched host is skipped"
    else
        bad "unmatched host is skipped (status=$status, out=$out)"
    fi
}

# A summary whose numbers do not add up to the row count is worse than none,
# and skipped-by-host is the common case on a machine the row excludes.
test_audit_summary_counts_condition_skips() {
    sandbox
    {
        setting NSGlobalDomain FirstKey bool true host=nosuchhost
        setting NSGlobalDomain SecondKey bool true host=nosuchhost
    } > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "2 skipped" <<<"$out" \
        && grep -q "condition 2" <<<"$out"; then
        ok "audit summary counts host-mismatched skips"
    else
        bad "audit summary counts host-mismatched skips (status=$status, out=$out)"
    fi
}

# --- audit ------------------------------------------------------------------

test_audit_ok_when_value_matches() {
    darwin_only "audit reports ok when the live value matches" || return 0
    sandbox
    defaults write "$DOMAIN" Flag -bool true
    setting "$DOMAIN" Flag bool true > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^ok: " <<<"$out"; then
        ok "audit reports ok when the live value matches"
    else
        bad "audit reports ok when the live value matches (status=$status, out=$out)"
    fi
}

# `defaults` stores booleans as 0/1 and .macos writes at least one as YES, so
# every bool comparison depends on normalizing both sides.
test_audit_normalizes_bools() {
    darwin_only "audit normalizes true against a stored 1" || return 0
    sandbox
    defaults write "$DOMAIN" Flag -bool true
    setting "$DOMAIN" Flag bool YES > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^ok: " <<<"$out"; then
        ok "audit normalizes true/YES/1 to the same value"
    else
        bad "audit normalizes true/YES/1 to the same value (status=$status, out=$out)"
    fi
}

test_audit_compares_a_quoted_value_intact() {
    darwin_only "audit compares a quoted value containing # and spaces" || return 0
    sandbox
    defaults write "$DOMAIN" Greeting -string "hello # world"
    setting "$DOMAIN" Greeting string "hello # world" > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^ok: " <<<"$out"; then
        ok "audit compares a quoted value containing # and spaces"
    else
        bad "audit compares a quoted value containing # and spaces (status=$status, out=$out)"
    fi
}

# The table version turned tabs into spaces because tab was its delimiter.
# A line here is bash, so a tab inside quotes is part of the value.
test_audit_keeps_a_tab_inside_a_value() {
    darwin_only "audit compares a value containing a tab byte-exact" || return 0
    sandbox
    defaults write "$DOMAIN" Weird -string "a	b"
    printf 'defaults write %s Weird -string "a\tb"\n' "$(q "$DOMAIN")" > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^ok: " <<<"$out"; then
        ok "audit compares a value containing a tab byte-exact"
    else
        bad "audit compares a value containing a tab byte-exact (status=$status, out=$out)"
    fi
}

test_audit_reports_drift() {
    darwin_only "audit reports drift with both values" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    setting "$DOMAIN" Count int 7 > "$SOURCE"
    mdefaults audit
    if [ "$status" = 1 ] && grep -q "^drift: .*want=7 live=3" <<<"$out"; then
        ok "audit reports drift with want and live"
    else
        bad "audit reports drift with want and live (status=$status, out=$out)"
    fi
}

# An absent key and a mismatched key need different fixes, so they get
# different labels.
test_audit_reports_missing() {
    darwin_only "audit reports an absent key as missing" || return 0
    sandbox
    defaults write "$DOMAIN" Other -int 1
    setting "$DOMAIN" Count int 7 > "$SOURCE"
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
    setting "$DOMAIN" Count int 7 > "$SOURCE"
    mdefaults audit
    if [ "$status" = 1 ] && grep -q "^drift: .*type want=int live=string" <<<"$out"; then
        ok "audit reports a changed storage type as drift"
    else
        bad "audit reports a changed storage type as drift (status=$status, out=$out)"
    fi
}

# A domain that will not read is how TCC denial looks from a shell, and how an
# app that never wrote preferences looks. It must never fail the audit, or
# every run without Full Disk Access would exit non-zero forever.
test_audit_skips_an_unreadable_domain_without_failing() {
    darwin_only "audit skips a row whose domain will not read" || return 0
    sandbox
    setting "$DOMAIN" Missing bool true > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^skip: .*(unreadable domain)" <<<"$out" \
        && ! grep -q "^missing: " <<<"$out"; then
        ok "audit skips a row whose domain will not read"
    else
        bad "audit skips a row whose domain will not read (status=$status, out=$out)"
    fi
}

# The unset marker exists for a key that never reads back even after apply.
test_audit_skips_an_unset_marked_absent_key() {
    darwin_only "audit skips a noaudit=unset key that is absent" || return 0
    sandbox
    defaults write "$DOMAIN" Other -int 1
    setting "$DOMAIN" Count int 7 noaudit=unset > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^skip: .*(unset)" <<<"$out"; then
        ok "audit skips a noaudit=unset key that is absent"
    else
        bad "audit skips a noaudit=unset key that is absent (status=$status, out=$out)"
    fi
}

# The marker records why a key may be absent, not a decision to ignore it.
test_audit_checks_an_unset_marked_key_that_reads() {
    darwin_only "audit checks a noaudit=unset key once it reads" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    setting "$DOMAIN" Count int 7 noaudit=unset > "$SOURCE"
    mdefaults audit
    if [ "$status" = 1 ] && grep -q "^drift: " <<<"$out" && ! grep -q "^skip: " <<<"$out"; then
        ok "audit checks a noaudit=unset key once it reads"
    else
        bad "audit checks a noaudit=unset key once it reads (status=$status, out=$out)"
    fi
}

# complex is derived from the type: no amount of access makes a container
# value comparable against a scalar.
test_audit_always_skips_a_readable_container() {
    darwin_only "audit skips a readable container row" || return 0
    sandbox
    defaults write "$DOMAIN" Langs -array en fr
    setting "$DOMAIN" Langs array '"en" "fr"' > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^skip: .*(complex)" <<<"$out"; then
        ok "audit skips a readable container row"
    else
        bad "audit skips a readable container row (status=$status, out=$out)"
    fi
}

test_audit_skips_a_raw_value_marked_complex() {
    darwin_only "audit skips a raw value marked complex" || return 0
    sandbox
    defaults write "$DOMAIN" Proxies "()"
    setting "$DOMAIN" Proxies raw "()" noaudit=complex > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^skip: .*(complex)" <<<"$out"; then
        ok "audit skips a raw value marked complex"
    else
        bad "audit skips a raw value marked complex (status=$status, out=$out)"
    fi
}

test_audit_filters_by_domain_and_key() {
    darwin_only "audit honors the domain and key filter" || return 0
    sandbox
    defaults write "$DOMAIN" First -bool true
    defaults write "$DOMAIN" Second -bool true
    {
        setting "$DOMAIN" First bool true
        setting "$DOMAIN" Second bool true
    } > "$SOURCE"
    mdefaults audit "$DOMAIN" Second
    if [ "$status" = 0 ] && grep -q "Second" <<<"$out" && ! grep -q "First" <<<"$out"; then
        ok "audit honors the domain and key filter"
    else
        bad "audit honors the domain and key filter (status=$status, out=$out)"
    fi
}

# .macos writes ${HOME} inside double quotes; the parser has to keep it as a
# token or these rows report drift on every machine, including the one that
# wrote them.
test_audit_expands_the_home_token() {
    darwin_only "audit expands \${HOME} before comparing" || return 0
    sandbox
    defaults write "$DOMAIN" Where -string "$HOME/Desktop"
    setting "$DOMAIN" Where string '${HOME}/Desktop' > "$SOURCE"
    mdefaults audit
    if [ "$status" = 0 ] && grep -q "^ok: " <<<"$out"; then
        ok "audit expands \${HOME} before comparing"
    else
        bad "audit expands \${HOME} before comparing (status=$status, out=$out)"
    fi
}

# --- apply ------------------------------------------------------------------

test_apply_writes_missing_key() {
    darwin_only "apply writes a key that is absent" || return 0
    sandbox
    setting "$DOMAIN" Count int 7 > "$SOURCE"
    mdefaults apply
    if [ "$status" = 0 ] && [ "$(defaults read "$DOMAIN" Count)" = 7 ] \
        && grep -q "^write: " <<<"$out"; then
        ok "apply writes a key that is absent"
    else
        bad "apply writes a key that is absent (status=$status, out=$out)"
    fi
}

# apply is the delta: a matching row is reported ok and left alone.
test_apply_is_idempotent() {
    darwin_only "a second apply is a no-op reported as ok" || return 0
    sandbox
    setting "$DOMAIN" Count int 7 > "$SOURCE"
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
    setting "$DOMAIN" Count int 7 > "$SOURCE"
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
    setting "$DOMAIN" Count int 7 > "$SOURCE"
    mdefaults --dry-run apply
    if [ "$status" = 0 ] && [ ! -e "$DOMAIN.plist" ]; then
        ok "dry-run creates no plist"
    else
        bad "dry-run creates no plist (status=$status, out=$out)"
    fi
}

# audit cannot tell whether a marked row needs writing, so apply always writes
# one. The live value is pre-set to MATCH here: an ordinary row would report
# ok: and skip, so only an unconditional write reports write:.
test_apply_writes_marked_rows_unconditionally() {
    darwin_only "apply writes noaudit rows unconditionally" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 7
    setting "$DOMAIN" Count int 7 noaudit=unset > "$SOURCE"
    mdefaults apply
    if [ "$status" = 0 ] && grep -q "^write: " <<<"$out" && ! grep -q "^ok: " <<<"$out" \
        && [ "$(defaults read "$DOMAIN" Count)" = 7 ]; then
        ok "apply writes noaudit rows unconditionally"
    else
        bad "apply writes noaudit rows unconditionally (status=$status, out=$out)"
    fi
}

# An array value cannot be expressed as a type/value pair, so container rows
# carry a literal argument tail and are the only rows that get eval'd on write.
test_apply_writes_container_value() {
    darwin_only "apply writes an array row through its literal argument tail" || return 0
    sandbox
    setting "$DOMAIN" Langs array '"en" "fr"' > "$SOURCE"
    mdefaults apply
    if [ "$status" = 0 ] && [ "$(defaults read "$DOMAIN" Langs | tr -d '\n ')" = "(en,fr)" ]; then
        ok "apply writes an array row through its literal argument tail"
    else
        bad "apply writes an array row through its literal argument tail (status=$status, out=$out)"
    fi
}

test_apply_writes_a_continued_dict() {
    darwin_only "apply writes a dict spread over continuation lines" || return 0
    sandbox
    {
        printf 'defaults write %s Panes -dict \\\n' "$(q "$DOMAIN")"
        printf '\tGeneral -bool true \\\n'
        printf '\tOpenWith -bool false\n'
    } > "$SOURCE"
    mdefaults apply
    if [ "$status" = 0 ] && [ "$(defaults read "$DOMAIN" Panes | tr -d '\n ;')" = "{General=1OpenWith=0}" ]; then
        ok "apply writes a dict spread over continuation lines"
    else
        bad "apply writes a dict spread over continuation lines (status=$status, out=$out, live=$(defaults read "$DOMAIN" Panes 2>&1 | tr -d '\n'))"
    fi
}

# A date is one argument to `defaults` even when it contains spaces, so its
# stored argument tail has to keep it as one word.
test_apply_writes_a_date_with_spaces() {
    darwin_only "apply writes a -date value containing spaces" || return 0
    sandbox
    printf 'defaults write %s When -date "2024-01-02 03:04:05 +0000"\n' "$(q "$DOMAIN")" > "$SOURCE"
    mdefaults apply
    if [ "$status" = 0 ] && [ "$(defaults read-type "$DOMAIN" When)" = "Type is date" ]; then
        ok "apply writes a -date value containing spaces"
    else
        bad "apply writes a -date value containing spaces (status=$status, out=$out)"
    fi
}

test_apply_skips_unmatched_host() {
    sandbox
    setting NSGlobalDomain SomeKey bool true host=nosuchhost > "$SOURCE"
    mdefaults apply
    if [ "$status" = 0 ] && grep -q "^skip: " <<<"$out"; then
        ok "apply skips an unmatched host"
    else
        bad "apply skips an unmatched host (status=$status, out=$out)"
    fi
}

test_apply_expands_the_home_token() {
    darwin_only "apply writes the expanded \${HOME} path" || return 0
    sandbox
    setting "$DOMAIN" Where string '${HOME}/Desktop' > "$SOURCE"
    mdefaults apply
    if [ "$status" = 0 ] && [ "$(defaults read "$DOMAIN" Where)" = "$HOME/Desktop" ]; then
        ok "apply writes the expanded \${HOME} path"
    else
        bad "apply writes the expanded \${HOME} path (status=$status, out=$out)"
    fi
}

# audit reports type drift, so apply must be able to resolve one. Otherwise
# audit reports drift, apply reports ok and writes nothing, and audit reports
# the same drift again: a loop with no exit but accept.
test_apply_rewrites_a_type_drifted_row() {
    darwin_only "apply rewrites a row whose stored type drifted" || return 0
    sandbox
    defaults write "$DOMAIN" Count -bool true
    setting "$DOMAIN" Count int 1 > "$SOURCE"
    mdefaults apply
    if [ "$status" = 0 ] && grep -q "^write: " <<<"$out" \
        && [ "$(defaults read-type "$DOMAIN" Count)" = "Type is integer" ]; then
        ok "apply rewrites a row whose stored type drifted"
    else
        bad "apply rewrites a row whose stored type drifted (status=$status, out=$out)"
    fi
}

# --- accept -----------------------------------------------------------------

test_accept_updates_a_drifting_value() {
    darwin_only "accept rewrites a drifting line to the live value" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    setting "$DOMAIN" Count int 7 > "$SOURCE"
    mdefaults accept
    if [ "$status" = 0 ] && grep -q " -int 3$" "$SOURCE"; then
        ok "accept rewrites a drifting line to the live value"
    else
        bad "accept rewrites a drifting line to the live value (status=$status, source=$(cat "$SOURCE"))"
    fi
}

# .macos is a script full of commentary and imperative lines; accept replaces
# exactly the drifting line and leaves every other byte alone.
test_accept_preserves_everything_else() {
    darwin_only "accept preserves every line but the one it rewrites" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    defaults write "$DOMAIN" Flag -bool true
    {
        printf '#!/usr/bin/env bash\n# a banner\n\n'
        printf 'sudo -v\n'
        printf '# why this setting exists\n'
        setting "$DOMAIN" Count int 7
        printf '\n'
        setting "$DOMAIN" Flag bool true
        printf 'killall Finder\n'
    } > "$SOURCE"
    cp "$SOURCE" "$SB/before"
    mdefaults accept
    if [ "$status" = 0 ] \
        && [ "$(diff "$SB/before" "$SOURCE" | grep -c '^[<>]')" = 2 ] \
        && [ "$(sed -n 6p "$SOURCE")" = "$(setting "$DOMAIN" Count int 3)" ] \
        && [ "$(wc -l < "$SOURCE")" -eq 9 ]; then
        ok "accept preserves every line but the one it rewrites"
    else
        bad "accept preserves every line but the one it rewrites (status=$status, diff=$(diff "$SB/before" "$SOURCE"))"
    fi
}

test_accept_leaves_matching_lines_alone() {
    darwin_only "accept leaves a matching line byte-identical" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 7
    setting "$DOMAIN" Count int 7 > "$SOURCE"
    before="$(cksum < "$SOURCE")"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(cksum < "$SOURCE")" = "$before" ]; then
        ok "accept leaves a matching line byte-identical"
    else
        bad "accept leaves a matching line byte-identical (status=$status, out=$out)"
    fi
}

test_accept_keeps_the_executable_bit() {
    darwin_only "accept keeps the source executable" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    setting "$DOMAIN" Count int 7 > "$SOURCE"
    chmod 755 "$SOURCE"
    mdefaults accept
    if [ "$status" = 0 ] && [ -x "$SOURCE" ]; then
        ok "accept keeps the source executable"
    else
        bad "accept keeps the source executable (status=$status, out=$out)"
    fi
}

# The unset marker exists because a key was absent when written. Once it
# reads the marker is stale, and only accept can clear it.
test_accept_clears_a_readable_unset_marker() {
    darwin_only "accept clears noaudit=unset once the key reads" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    setting "$DOMAIN" Count int 7 noaudit=unset > "$SOURCE"
    mdefaults accept
    if [ "$status" = 0 ] && ! grep -q "noaudit=unset" "$SOURCE" && grep -q " -int 3$" "$SOURCE"; then
        ok "accept clears noaudit=unset once the key reads"
    else
        bad "accept clears noaudit=unset once the key reads (status=$status, source=$(cat "$SOURCE"))"
    fi
}

test_accept_keeps_a_host_marker() {
    darwin_only "accept keeps a matching host marker on a rewritten line" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    setting "$DOMAIN" Count int 7 "host=$THIS_HOST" > "$SOURCE"
    mdefaults accept
    if [ "$status" = 0 ] && grep -q " -int 3 # host=$THIS_HOST$" "$SOURCE"; then
        ok "accept keeps a matching host marker on a rewritten line"
    else
        bad "accept keeps a matching host marker on a rewritten line (status=$status, source=$(cat "$SOURCE"))"
    fi
}

test_accept_clears_unset_but_keeps_host() {
    darwin_only "accept clears noaudit=unset and keeps the host marker" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    setting "$DOMAIN" Count int 7 "noaudit=unset host=$THIS_HOST" > "$SOURCE"
    mdefaults accept
    if [ "$status" = 0 ] && grep -q " -int 3 # host=$THIS_HOST$" "$SOURCE"; then
        ok "accept clears noaudit=unset and keeps the host marker"
    else
        bad "accept clears noaudit=unset and keeps the host marker (status=$status, source=$(cat "$SOURCE"))"
    fi
}

test_accept_preserves_a_prose_trailing_comment() {
    darwin_only "accept keeps a prose trailing comment" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    printf 'defaults write %s Count -int 7 # see mths.be/macos\n' "$(q "$DOMAIN")" > "$SOURCE"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(cat "$SOURCE")" = "defaults write $(q "$DOMAIN") Count -int 3 # see mths.be/macos" ]; then
        ok "accept keeps a prose trailing comment"
    else
        bad "accept keeps a prose trailing comment (status=$status, source=$(cat "$SOURCE"))"
    fi
}

# accept assembles the new file beside the source; the scratch file must be
# gone afterwards, or it lands untracked in the repo root.
test_accept_leaves_no_scratch_file() {
    darwin_only "accept leaves no scratch file beside the source" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    setting "$DOMAIN" Count int 7 > "$SOURCE"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(ls "$SB" | grep -c '^macos')" = 1 ]; then
        ok "accept leaves no scratch file beside the source"
    else
        bad "accept leaves no scratch file beside the source (status=$status, ls=$(ls "$SB" | tr '\n' ' '))"
    fi
}

test_accept_updates_the_type_when_it_drifts() {
    darwin_only "accept rewrites the type flag too" || return 0
    sandbox
    defaults write "$DOMAIN" Count -string seven
    setting "$DOMAIN" Count int 7 > "$SOURCE"
    mdefaults accept
    if [ "$status" = 0 ] && grep -q " -string seven$" "$SOURCE"; then
        ok "accept rewrites the type flag too"
    else
        bad "accept rewrites the type flag too (status=$status, source=$(cat "$SOURCE"))"
    fi
}

test_accept_honors_the_filter() {
    darwin_only "accept honors the domain and key filter" || return 0
    sandbox
    defaults write "$DOMAIN" First -int 1
    defaults write "$DOMAIN" Second -int 2
    {
        setting "$DOMAIN" First int 9
        setting "$DOMAIN" Second int 9
    } > "$SOURCE"
    mdefaults accept "$DOMAIN" Second
    if [ "$status" = 0 ] && grep -q "First -int 9$" "$SOURCE" && grep -q "Second -int 2$" "$SOURCE"; then
        ok "accept honors the domain and key filter"
    else
        bad "accept honors the domain and key filter (status=$status, source=$(cat "$SOURCE"))"
    fi
}

# A container's value is an eval argument tail, and `defaults read` returns a
# multi-line plist dump for an array. Rewriting the line would splice those
# newlines into the script.
test_accept_never_rewrites_a_readable_container() {
    darwin_only "accept leaves a readable container line byte-identical" || return 0
    sandbox
    defaults write "$DOMAIN" Langs -array en fr
    setting "$DOMAIN" Langs array '"en" "fr"' > "$SOURCE"
    before="$(cksum < "$SOURCE")"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(cksum < "$SOURCE")" = "$before" ] \
        && [ "$(wc -l < "$SOURCE")" -eq 1 ]; then
        ok "accept leaves a readable container line byte-identical"
    else
        bad "accept leaves a readable container line byte-identical (status=$status, source=$(cat "$SOURCE"))"
    fi
}

# The unreadable case is what the marker exists for: no value to take, so the
# line must be left exactly as it is.
test_accept_leaves_an_unreadable_row_alone() {
    darwin_only "accept leaves an unreadable row alone" || return 0
    sandbox
    setting "$DOMAIN" Absent int 7 > "$SOURCE"
    before="$(cksum < "$SOURCE")"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(cksum < "$SOURCE")" = "$before" ]; then
        ok "accept leaves an unreadable row alone"
    else
        bad "accept leaves an unreadable row alone (status=$status, source=$(cat "$SOURCE"))"
    fi
}

# Without this, accepting one of these rows would bake the literal home
# directory into .macos and undo the whole point of the token.
test_accept_tokenizes_the_home_path() {
    darwin_only "accept stores \${HOME} rather than the literal path" || return 0
    sandbox
    defaults write "$DOMAIN" Where -string "$HOME/Downloads"
    setting "$DOMAIN" Where string '${HOME}/Desktop' > "$SOURCE"
    mdefaults accept
    if [ "$status" = 0 ] && grep -qF -- '-string "${HOME}/Downloads"' "$SOURCE" && ! grep -q "$HOME" "$SOURCE"; then
        ok "accept stores \${HOME} rather than the literal path"
    else
        bad "accept stores \${HOME} rather than the literal path (status=$status, source=$(cat "$SOURCE"))"
    fi
}

# The token rows are the ones most likely to be accepted spuriously: the line
# holds ${HOME} and the machine holds the expanded path, so an unexpanded
# comparison always reports a change even when nothing drifted.
test_accept_leaves_a_tokenized_matching_row_alone() {
    darwin_only "accept leaves a matching \${HOME} row alone and says nothing" || return 0
    sandbox
    defaults write "$DOMAIN" Where -string "$HOME/Desktop"
    setting "$DOMAIN" Where string '${HOME}/Desktop' > "$SOURCE"
    before="$(cksum < "$SOURCE")"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(cksum < "$SOURCE")" = "$before" ] \
        && ! grep -q "^accept: " <<<"$out"; then
        ok "accept leaves a matching \${HOME} row alone and says nothing"
    else
        bad "accept leaves a matching \${HOME} row alone and says nothing (status=$status, out=$out)"
    fi
}

# Booleans are kept as true/false so the script stays reviewable, but
# `defaults read` returns 0/1.
test_accept_writes_booleans_in_human_form() {
    darwin_only "accept writes a bool as true/false, not 1/0" || return 0
    sandbox
    defaults write "$DOMAIN" Flag -bool true
    setting "$DOMAIN" Flag bool false > "$SOURCE"
    mdefaults accept
    if [ "$status" = 0 ] && grep -q " -bool true$" "$SOURCE" \
        && ! grep -q " -bool 1$" "$SOURCE"; then
        ok "accept writes a bool as true/false, not 1/0"
    else
        bad "accept writes a bool as true/false, not 1/0 (status=$status, source=$(cat "$SOURCE"))"
    fi
}

test_accept_refuses_a_value_containing_a_tab() {
    darwin_only "accept refuses a live value containing a tab" || return 0
    sandbox
    defaults write "$DOMAIN" Weird -string "a	b"
    setting "$DOMAIN" Weird string placeholder > "$SOURCE"
    before="$(cksum < "$SOURCE")"
    mdefaults accept
    if [ "$(cksum < "$SOURCE")" = "$before" ] && grep -q "skipped" <<<"$out"; then
        ok "accept refuses a live value containing a tab"
    else
        bad "accept refuses a live value containing a tab (status=$status, source=$(cat "$SOURCE"))"
    fi
}

# The rewritten line is bash, so what accept writes has to survive the shell:
# a value with spaces is quoted, a quoted key stays quoted, and the result
# parses again.
test_accept_quotes_what_the_shell_needs() {
    darwin_only "accept quotes a spaced value and re-parses" || return 0
    sandbox
    defaults write "$DOMAIN" "Quit When Finished" -string "hello world"
    setting "$DOMAIN" "Quit When Finished" string goodbye > "$SOURCE"
    mdefaults accept
    accept_status="$status"
    mdefaults audit
    if [ "$accept_status" = 0 ] && grep -qF '"Quit When Finished" -string "hello world"' "$SOURCE" \
        && [ "$status" = 0 ] && grep -q "^ok: " <<<"$out"; then
        ok "accept quotes a spaced value and re-parses"
    else
        bad "accept quotes a spaced value and re-parses (accept=$accept_status, audit=$status, source=$(cat "$SOURCE"))"
    fi
}

test_accept_preserves_indent_and_sudo_prefix() {
    darwin_only "accept preserves indentation and a sudo prefix" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    printf '    sudo defaults write %s Count -int 7\n' "$(q "$DOMAIN")" > "$SOURCE"
    mdefaults accept
    if [ "$status" = 0 ] && [ "$(cat "$SOURCE")" = "    sudo defaults write $(q "$DOMAIN") Count -int 3" ]; then
        ok "accept preserves indentation and a sudo prefix"
    else
        bad "accept preserves indentation and a sudo prefix (status=$status, source=$(cat "$SOURCE"))"
    fi
}

test_accept_dry_run_changes_nothing() {
    darwin_only "accept --dry-run reports and writes nothing" || return 0
    sandbox
    defaults write "$DOMAIN" Count -int 3
    setting "$DOMAIN" Count int 7 > "$SOURCE"
    before="$(cksum < "$SOURCE")"
    mdefaults --dry-run accept
    if [ "$status" = 0 ] && grep -q "^would: accept: " <<<"$out" && [ "$(cksum < "$SOURCE")" = "$before" ]; then
        ok "accept --dry-run reports and writes nothing"
    else
        bad "accept --dry-run reports and writes nothing (status=$status, out=$out)"
    fi
}

# --- runner -----------------------------------------------------------------
test_rejects_unknown_flag
test_rejects_missing_source
test_rejects_a_write_with_no_value
test_rejects_a_write_with_a_stray_argument
test_rejects_unknown_type_flag
test_negative_untyped_value_is_a_value
test_rejects_a_trailing_command_and_does_not_run_it
test_rejects_command_substitution_inside_quotes
test_rejects_semicolons_pipes_and_backticks
test_rejects_array_add
test_host_marker_survives_on_a_container_row
test_two_markers_on_one_line_parse
test_rejects_a_marker_mixed_with_prose
test_continuation_lines_keep_their_whitespace
test_comment_ending_in_backslash_does_not_join
test_rejects_unknown_marker
test_rejects_tcc_marker
test_rejects_complex_marker_on_a_typed_scalar
test_accepts_complex_marker_on_a_raw_value
test_rejects_unset_marker_on_a_container
test_rejects_duplicate_domain_and_key
test_allows_repeated_dict_add_domain_and_key
test_accepts_same_key_under_different_hosts
test_rejects_same_key_under_the_same_host
test_rejects_a_source_with_no_writes
test_commented_out_write_is_ignored
test_non_defaults_lines_are_ignored_and_not_run
test_rejects_a_non_write_defaults_line_that_looks_like_one
test_hash_inside_a_quoted_value_is_not_a_marker
test_prose_trailing_comment_is_not_a_marker
test_key_with_spaces_parses
test_continuation_lines_join_into_one_row
test_sudo_prefix_parses_without_sudo
test_current_host_flag_parses
test_check_counts_rows
test_audit_skips_unmatched_host
test_audit_summary_counts_condition_skips
test_audit_ok_when_value_matches
test_audit_normalizes_bools
test_audit_compares_a_quoted_value_intact
test_audit_keeps_a_tab_inside_a_value
test_audit_reports_drift
test_audit_reports_missing
test_audit_reports_type_drift
test_audit_skips_an_unreadable_domain_without_failing
test_audit_skips_an_unset_marked_absent_key
test_audit_checks_an_unset_marked_key_that_reads
test_audit_always_skips_a_readable_container
test_audit_skips_a_raw_value_marked_complex
test_audit_filters_by_domain_and_key
test_audit_expands_the_home_token
test_apply_writes_missing_key
test_apply_is_idempotent
test_dry_run_reports_would_write
test_dry_run_changes_nothing
test_apply_writes_marked_rows_unconditionally
test_apply_writes_container_value
test_apply_writes_a_continued_dict
test_apply_writes_a_date_with_spaces
test_apply_skips_unmatched_host
test_apply_expands_the_home_token
test_apply_rewrites_a_type_drifted_row
test_accept_updates_a_drifting_value
test_accept_preserves_everything_else
test_accept_leaves_matching_lines_alone
test_accept_keeps_the_executable_bit
test_accept_clears_a_readable_unset_marker
test_accept_keeps_a_host_marker
test_accept_clears_unset_but_keeps_host
test_accept_preserves_a_prose_trailing_comment
test_accept_leaves_no_scratch_file
test_accept_updates_the_type_when_it_drifts
test_accept_honors_the_filter
test_accept_never_rewrites_a_readable_container
test_accept_leaves_an_unreadable_row_alone
test_accept_tokenizes_the_home_path
test_accept_leaves_a_tokenized_matching_row_alone
test_accept_writes_booleans_in_human_form
test_accept_refuses_a_value_containing_a_tab
test_accept_quotes_what_the_shell_needs
test_accept_preserves_indent_and_sudo_prefix
test_accept_dry_run_changes_nothing

echo
echo "$pass passed, $fail failed, $skipped skipped"
[ "$fail" -eq 0 ]
