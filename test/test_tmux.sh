#!/bin/bash
# Smoke tests for home/.tmux.conf: the file loads in a throwaway server, and the
# copy-mode `y` binding follows pbcopy availability (pipe through pbcopy where
# it exists, plain copy plus the terminal's OSC 52 elsewhere). Each case starts
# its own tmux server on a private socket under a fake HOME, so nothing here
# touches a live session. PATH is set per case, and tmux is invoked by absolute
# path because bash resolves a command with the temporarily assigned PATH.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$ROOT/home/.tmux.conf"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-tmux.XXXXXX")"
BASE="$(cd "$BASE" && pwd)"
trap 'rm -rf "$BASE"' EXIT

pass=0
fail=0
ok()   { pass=$((pass + 1)); echo "PASS: $1"; }
bad()  { fail=$((fail + 1)); echo "FAIL: $1"; }
skip() { echo "SKIP: $1"; }

if ! command -v tmux >/dev/null 2>&1; then
  skip "tmux smoke tests (tmux not installed)"
  echo "0 passed, 0 failed"
  exit 0
fi
TMUX_BIN="$(command -v tmux)"

FAKEHOME="$BASE/home"
mkdir -p "$FAKEHOME" "$BASE/nobin" "$BASE/pbcopybin"
printf '#!/bin/sh\ncat >/dev/null\n' > "$BASE/pbcopybin/pbcopy"
chmod +x "$BASE/pbcopybin/pbcopy"

# y_binding <PATH>: load the config in a fresh server with that PATH, print the
# copy-mode-vi binding for y, stop the server. Output lands in $got, exit in $status.
# TMUX_TMPDIR keeps the socket under $BASE, so the EXIT trap removes it even
# where tmux leaves the dead socket file behind after kill-server.
y_binding() {
  local sock="tmuxtest-$$-$RANDOM"
  set +e
  got="$(HOME="$FAKEHOME" SHELL=/bin/sh PATH="$1" TMUX_TMPDIR="$BASE" "$TMUX_BIN" -L "$sock" -f "$CONF" start-server \; list-keys -T copy-mode-vi y 2>&1)"
  status=$?
  set -e
  TMUX_TMPDIR="$BASE" "$TMUX_BIN" -L "$sock" kill-server 2>/dev/null || true
}

test_config_loads() {
  y_binding "$BASE/nobin"
  if [ "$status" = 0 ] && [ -n "$got" ] && ! grep -qiE 'unknown|error|invalid' <<<"$got"; then
    ok ".tmux.conf loads without errors"
  else
    bad ".tmux.conf loads without errors (status=$status: $got)"
  fi
}

test_y_pipes_to_pbcopy_when_present() {
  y_binding "$BASE/pbcopybin"
  if grep -q 'copy-pipe-and-cancel pbcopy' <<<"$got"; then
    ok "y pipes through pbcopy when pbcopy is on PATH"
  else
    bad "y pipes through pbcopy when pbcopy is on PATH (got: $got)"
  fi
}

test_y_plain_copy_without_pbcopy() {
  y_binding "$BASE/nobin"
  if grep -q 'copy-selection-and-cancel' <<<"$got" && ! grep -q pbcopy <<<"$got"; then
    ok "y is a plain copy-selection-and-cancel without pbcopy"
  else
    bad "y is a plain copy-selection-and-cancel without pbcopy (got: $got)"
  fi
}

test_config_loads
test_y_pipes_to_pbcopy_when_present
test_y_plain_copy_without_pbcopy

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
