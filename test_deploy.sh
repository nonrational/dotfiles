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
