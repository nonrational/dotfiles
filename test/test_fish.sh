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
REAL_UNAME="$(command -v uname)"

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

test_starship_absent() {
  # Only starship.fish is linked, so the guard is tested without 00-path.fish
  # adding Homebrew (and its starship) to PATH.
  local h
  h="$(mktemp -d "$BASE/home.XXXXXX")"
  mkdir -p "$h/.config/fish/conf.d"
  ln -s "$FISHDIR/conf.d/starship.fish" "$h/.config/fish/conf.d/starship.fish"
  set +e
  got="$(HOME="$h" PATH="/usr/bin:/bin" "$FISH_BIN" -ic 'type fish_prompt' 2>&1)"
  set -e
  if [[ "$got" != *starship* ]]; then
    ok "fish_prompt is fish's own when starship is absent"
  else
    bad "fish_prompt is fish's own when starship is absent (got: $got)"
  fi
  set +e
  got="$(HOME="$h" PATH="/usr/bin:/bin" "$FISH_BIN" -ic 'exit' 2>&1)"
  status=$?
  set -e
  if [ -z "$got" ] && [ "$status" -eq 0 ]; then
    ok "startup without starship prints nothing"
  else
    bad "startup without starship prints nothing (status $status, got: $got)"
  fi
}

test_starship_loads_under_minimal_path() {
  if [ ! -x /opt/homebrew/bin/starship ]; then
    skip "starship under minimal PATH (/opt/homebrew/bin/starship absent)"
    return
  fi
  run_fish "/usr/bin:/bin" 'functions fish_prompt'
  if [[ "$got" == *starship* ]]; then
    ok "starship prompt loads under a minimal GUI PATH"
  else
    bad "starship prompt loads under a minimal GUI PATH (got: $got)"
  fi
}

# A stub starship answers only the two calls the init script and prompt make,
# so the test exercises the wiring in conf.d/starship.fish without the real binary.
test_starship_present() {
  local h
  h="$(fake_fish_home)"
  cat >"$h/bin/starship" <<'STUB'
#!/bin/sh
case "$1 $2" in
  "init fish") echo 'function fish_prompt; echo STUB; end' ;;
  "prompt "*|"prompt ") echo STUB ;;
esac
STUB
  chmod +x "$h/bin/starship"
  set +e
  got="$(HOME="$h" PATH="$h/bin:/usr/bin:/bin" "$FISH_BIN" -ic 'fish_prompt' 2>&1)"
  set -e
  if [[ "$got" == *STUB* ]]; then
    ok "starship prompt is installed when starship is on PATH"
  else
    bad "starship prompt is installed when starship is on PATH (got: $got)"
  fi
}

test_starship_toml_valid() {
  local sb out err rc
  if ! command -v starship >/dev/null 2>&1; then
    skip "starship.toml validity (starship not installed)"
    return
  fi
  # A missing file silently falls back to starship's defaults, so require it first.
  if [ ! -f "$ROOT/home/.config/starship.toml" ]; then
    bad "starship.toml renders a prompt (home/.config/starship.toml missing)"
    return
  fi
  # A fresh repo keeps the git modules independent of this checkout's state.
  sb="$(mktemp -d "$BASE/sb.XXXXXX")"
  git -C "$sb" init -q
  # starship exits 0 and prints a default prompt when the TOML is invalid,
  # reporting the error on stderr, so stderr must be empty to prove validity.
  set +e
  out="$(cd "$sb" && STARSHIP_CONFIG="$ROOT/home/.config/starship.toml" starship prompt 2>"$BASE/starship.err")"
  rc=$?
  set -e
  err="$(cat "$BASE/starship.err")"
  if [ "$rc" -eq 0 ] && [ -n "$out" ] && [ -z "$err" ]; then
    ok "starship.toml renders a prompt without errors"
  else
    bad "starship.toml renders a prompt without errors (status $rc, stderr: $err)"
  fi
}

# stub_uname <home> <name>: a uname that reports <name> for `-n` and defers to
# the real one otherwise, so darwin.fish's `test (uname) = Darwin` still works.
stub_uname() {
  cat >"$1/bin/uname" <<STUB
#!/bin/sh
if [ "\$1" = "-n" ]; then echo $2; else exec $REAL_UNAME "\$@"; fi
STUB
  chmod +x "$1/bin/uname"
}

test_local_hook() {
  local h
  h="$(fake_fish_home)"
  mkdir -p "$h/hookdir" "$h/.local"
  cat >"$h/.local/config.fish" <<HOOK
set -gx LOCAL_HOOK_RAN 1
fish_add_path --move --path $h/hookdir
HOOK
  set +e
  got="$(HOME="$h" PATH="/usr/bin:/bin" "$FISH_BIN" -ic 'echo $LOCAL_HOOK_RAN; echo $PATH[1]' 2>&1)"
  set -e
  if [ "$got" = "$(printf '1\n./bin')" ]; then
    ok "local hook is sourced and ./bin stays first on PATH"
  else
    bad "local hook is sourced and ./bin stays first on PATH (got: $got)"
  fi
  run_fish "/usr/bin:/bin" 'exit'
  if [ -z "$got" ] && [ "$status" -eq 0 ]; then
    ok "absent local config prints nothing"
  else
    bad "absent local config prints nothing (status $status, got: $got)"
  fi
}

test_host_file_inert() {
  local h
  h="$(fake_fish_home)"
  stub_uname "$h" otherhost
  set +e
  got="$(HOME="$h" PATH="$h/bin:/usr/bin:/bin" SSH_AUTH_SOCK=sentinel "$FISH_BIN" -ic 'echo $SSH_AUTH_SOCK' 2>&1)"
  set -e
  if [ "$got" = sentinel ]; then
    ok "host file leaves SSH_AUTH_SOCK alone on another host"
  else
    bad "host file leaves SSH_AUTH_SOCK alone on another host (got: $got)"
  fi
  h="$(fake_fish_home)"
  stub_uname "$h" nyx.lan
  set +e
  got="$(HOME="$h" PATH="$h/bin:/usr/bin:/bin" SSH_AUTH_SOCK=sentinel "$FISH_BIN" -ic 'echo $SSH_AUTH_SOCK; functions aws' 2>&1)"
  set -e
  if [[ "$got" == *"/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"* ]] && [[ "$got" == *"op plugin run"* ]]; then
    ok "host file sets the 1Password agent socket and aws alias on nyx"
  else
    bad "host file sets the 1Password agent socket and aws alias on nyx (got: $got)"
  fi
}

test_op_completion_guarded() {
  local h
  # Only config.fish is linked, so conf.d/00-path.fish cannot put a Homebrew
  # op on PATH and the case holds on a Mac that has op installed.
  h="$(fake_fish_home)"
  rm "$h/.config/fish/conf.d" "$h/.config/fish/functions" "$h/.config/fish/completions" 2>/dev/null || true
  set +e
  got="$(env -u XDG_CONFIG_HOME HOME="$h" PATH="/usr/bin:/bin" "$FISH_BIN" -ic 'exit' 2>&1)"
  status=$?
  set -e
  if [ -z "$got" ] && [ "$status" -eq 0 ]; then
    ok "startup without op prints nothing"
  else
    bad "startup without op prints nothing (status $status, got: $got)"
  fi
  h="$(fake_fish_home)"
  cat >"$h/bin/op" <<'STUB'
#!/bin/sh
if [ "$1 $2" = "completion fish" ]; then echo 'set -g OP_COMPLETION_LOADED 1'; fi
STUB
  chmod +x "$h/bin/op"
  set +e
  got="$(HOME="$h" PATH="$h/bin:/usr/bin:/bin" "$FISH_BIN" -ic 'echo $OP_COMPLETION_LOADED' 2>&1)"
  set -e
  if [ "$got" = 1 ]; then
    ok "op completion loads when op is on PATH"
  else
    bad "op completion loads when op is on PATH (got: $got)"
  fi
}

test_config_parses
test_runtime_state_stays_out_of_repo
test_path_order
test_functions_defined
test_prpg_length
test_aliases
test_editor_exports
test_starship_absent
test_starship_loads_under_minimal_path
test_starship_present
test_starship_toml_valid
test_local_hook
test_host_file_inert
test_op_completion_guarded

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
