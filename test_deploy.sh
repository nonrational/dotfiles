#!/bin/bash
# Tests for deploy.sh. Each test runs against a sandboxed repo copy and a
# fake $HOME under mktemp, so nothing here touches the real home directory.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-deploy.XXXXXX")"
BASE="$(cd "$BASE" && pwd)"
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

# --- runner -----------------------------------------------------------------
test_rejects_unknown_flag
test_rejects_missing_manifest
test_rejects_malformed_line
test_rejects_extra_columns
test_rejects_unknown_condition
test_rejects_missing_source
test_rejects_empty_manifest
test_apply_creates_missing_link
test_apply_is_idempotent
test_apply_creates_parent_dirs
test_apply_relinks_wrong_symlink
test_apply_skips_unmatched_condition
test_apply_matches_os_and_host
test_apply_backs_up_regular_file
test_apply_backs_up_directory
test_apply_refuses_second_backup
test_dry_run_reports_would_link
test_dry_run_changes_nothing

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
