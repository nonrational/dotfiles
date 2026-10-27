#!/bin/bash
# Tests for home/.config/fish: every fish file parses, and (in later cases) the
# interactive config behaves under a controlled PATH. Each case runs fish with
# a fake HOME whose .config/fish is a real directory holding per-entry links
# into the repo, so nothing here reads or writes the real ~/.config/fish
# (test_config_parses is the exception: it reads the repo files directly). fish
# is invoked by absolute path, resolved before PATH is narrowed, because the
# shell looks up a command using the temporarily assigned PATH.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FISHDIR="$ROOT/home/.config/fish"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-fish.XXXXXX")"
BASE="$(cd "$BASE" && pwd)"
trap 'rm -rf "$BASE"' EXIT

pass=0
fail=0
ok()   { pass=$((pass + 1)); echo "PASS: $1"; }
bad()  { fail=$((fail + 1)); echo "FAIL: $1"; }
skip() { echo "SKIP: $1"; }

if ! command -v fish >/dev/null 2>&1; then
  skip "fish tests (fish not installed)"
  echo "0 passed, 0 failed"
  exit 0
fi
FISH_BIN="$(command -v fish)"

# fake_fish_home: print the path of a fresh throwaway HOME with .config/fish
# holding links to the repo's tracked entries, and an empty bin/ for stub
# commands. .config/fish is a real directory so runtime files (fish_variables,
# universal variables from `set -U`) land in the throwaway HOME, not the checkout.
fake_fish_home() {
  local h e
  h="$(mktemp -d "$BASE/home.XXXXXX")"
  mkdir -p "$h/.config/fish" "$h/bin"
  for e in config.fish conf.d functions completions; do
    if [ -e "$FISHDIR/$e" ]; then ln -s "$FISHDIR/$e" "$h/.config/fish/$e"; fi
  done
  echo "$h"
}

# run_fish <PATH> <cmd>: run `fish -ic <cmd>` under a fresh fake HOME with PATH
# set as given. Output lands in $got, exit code in $status.
run_fish() {
  local h
  h="$(fake_fish_home)"
  set +e
  got="$(env -u XDG_CONFIG_HOME HOME="$h" PATH="$1" "$FISH_BIN" -ic "$2" 2>&1)"
  status=$?
  set -e
}

test_config_parses() {
  local f count=0 failed=0
  while IFS= read -r f; do
    count=$((count + 1))
    if ! "$FISH_BIN" --no-execute "$f" 2>"$BASE/err"; then
      failed=1
      bad "fish --no-execute ${f#"$ROOT"/} ($(cat "$BASE/err"))"
    fi
  done < <(find "$FISHDIR" -name '*.fish' 2>/dev/null | sort)
  if [ "$count" -eq 0 ]; then
    bad "fish files parse (no *.fish files under home/.config/fish)"
  elif [ "$failed" -eq 0 ]; then
    ok "all $count fish files parse"
  fi
}

test_runtime_state_stays_out_of_repo() {
  # The owner's live ~/.config/fish links into the checkout, so fish_variables
  # may already exist here; assert this run leaves it unchanged rather than absent.
  local before after h
  before="$(cksum "$FISHDIR/fish_variables" 2>/dev/null || echo absent)"
  h="$(fake_fish_home)"
  set +e
  env -u XDG_CONFIG_HOME HOME="$h" PATH="$PATH" "$FISH_BIN" -ic 'set -U isolation_probe 1' >/dev/null 2>&1
  set -e
  after="$(cksum "$FISHDIR/fish_variables" 2>/dev/null || echo absent)"
  if [ "$before" = "$after" ] && [ -f "$h/.config/fish/fish_variables" ]; then
    ok "fish runtime state lands in the fake HOME, not the repo"
  else
    bad "fish runtime state lands in the fake HOME, not the repo (repo before: $before, after: $after)"
  fi
}

test_path_order() {
  run_fish "/usr/bin:/bin" 'echo $PATH[1]'
  if [ "$got" = "./bin" ]; then
    ok "./bin is first on PATH"
  else
    bad "./bin is first on PATH (got: $got)"
  fi
  if [ -d /opt/homebrew/bin ]; then
    run_fish "/usr/bin:/bin" 'contains -i /opt/homebrew/bin $PATH; and contains -i /usr/bin $PATH'
    local brew usr
    brew="$(echo "$got" | sed -n 1p)"
    usr="$(echo "$got" | sed -n 2p)"
    if [ -n "$brew" ] && [ -n "$usr" ] && [ "$brew" -lt "$usr" ]; then
      ok "/opt/homebrew/bin precedes /usr/bin"
    else
      bad "/opt/homebrew/bin precedes /usr/bin (got: $got)"
    fi
  else
    skip "/opt/homebrew/bin ordering (directory absent)"
  fi
}

test_functions_defined() {
  run_fish "$PATH" 'functions -q prpg reset_known_host'
  if [ "$status" -eq 0 ]; then ok "prpg and reset_known_host defined"; else bad "prpg and reset_known_host defined (got: $got)"; fi
  if [ "$(uname)" = Darwin ]; then
    run_fish "$PATH" 'functions -q scutil_set_hostname'
    if [ "$status" -eq 0 ]; then ok "scutil_set_hostname defined"; else bad "scutil_set_hostname defined (got: $got)"; fi
  fi
}

test_prpg_length() {
  run_fish "$PATH" 'prpg 20'
  if [ "${#got}" -eq 20 ] && [[ "$got" != *[/+=]* ]]; then
    ok "prpg 20 prints 20 characters without /+="
  else
    bad "prpg 20 prints 20 characters without /+= (got: $got)"
  fi
}

test_aliases() {
  local a
  run_fish "$PATH" 'alias'
  for a in ll la l rm df du grep hist psa cdate; do
    if echo "$got" | grep -qE "^alias $a "; then ok "alias $a defined"; else bad "alias $a defined"; fi
  done
}

test_editor_exports() {
  if [ "$(uname)" != Darwin ]; then
    skip "EDITOR/VISUAL exports (Darwin only)"
    return
  fi
  run_fish "$PATH" 'echo $EDITOR; echo $VISUAL'
  if [ "$got" = "$(printf 'subl -w -n\nsubl -w -n')" ]; then
    ok "EDITOR and VISUAL are subl -w -n"
  else
    bad "EDITOR and VISUAL are subl -w -n (got: $got)"
  fi
}

test_config_parses
test_runtime_state_stays_out_of_repo
test_path_order
test_functions_defined
test_prpg_length
test_aliases
test_editor_exports

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
