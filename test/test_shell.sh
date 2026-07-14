#!/bin/bash
# Smoke tests for the shell rc files. Each shell's entry point is sourced inside
# a throwaway $HOME whose rc files are symlinks back to the repo, so nothing here
# touches the real home directory. We assert the entry point sources with exit 0
# and that a few sentinel functions/aliases are defined afterward -- enough to
# catch a syntax error or a rename that would silently drop config at next login.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-shell.XXXXXX")"
BASE="$(cd "$BASE" && pwd)"
trap 'rm -rf "$BASE"' EXIT

# rc files a login/interactive shell may pull in; linked into every fake HOME so
# the source chain ($HOME/.bashrc, $HOME/.bashrc.$(uname), ...) resolves.
RC_FILES=(.bash_profile .bashrc .bashrc.Darwin .bashrc.Linux .zshrc .zprofile .profile)

pass=0
fail=0

ok()   { pass=$((pass + 1)); echo "PASS: $1"; }
bad()  { fail=$((fail + 1)); echo "FAIL: $1"; }
skip() { echo "SKIP: $1"; }

# Print the path to a fresh fake $HOME with the repo's rc files linked in.
fake_home() {
    local h f
    h="$(mktemp -d "$BASE/home.XXXXXX")"
    for f in "${RC_FILES[@]}"; do
        if [ -e "$ROOT/$f" ]; then
            ln -s "$ROOT/$f" "$h/$f"
        fi
    done
    printf '%s' "$h"
}

# smoke <label> <shell> <entry-rc> <sentinel>...
# Source $entry in $shell under a fake HOME; pass iff the source exits 0 and
# every sentinel ("type NAME") resolves. Skip cleanly if $shell isn't installed.
smoke() {
    local label="$1" shell="$2" entry="$3"
    shift 3
    if ! command -v "$shell" >/dev/null 2>&1; then
        skip "$label ($shell not installed)"
        return
    fi
    # bash only registers aliases for `type` when alias expansion is on, which
    # is off by default in a non-interactive shell; zsh has no such switch.
    local script="" name
    [ "$shell" = bash ] && script="shopt -s expand_aliases;"
    script+=" source \"\$HOME/$entry\" || exit 8;"
    for name in "$@"; do
        script+=" type $name >/dev/null 2>&1 || { echo 'undefined: $name' >&2; exit 9; };"
    done
    local h out status
    h="$(fake_home)"
    set +e
    out="$(HOME="$h" "$shell" -c "$script" 2>&1)"
    status=$?
    set -e
    if [ "$status" -eq 0 ]; then
        ok "$label"
    else
        bad "$label (exit $status): $out"
    fi
}

smoke "bash: .bash_profile sources and defines helpers" \
      bash .bash_profile source_if_exists prpg ll
smoke "zsh: .zshrc sources and defines helpers" \
      zsh .zshrc ll puma-dev-ln

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
