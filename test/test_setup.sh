#!/bin/bash
# Tests for setup.sh, scripts/setup-lib.sh, and the make targets they call.
# Everything runs under a mktemp sandbox with stub commands on PATH, so no
# test touches the real $HOME, brew, gh, or exe.dev.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-setup.XXXXXX")"
BASE="$(cd "$BASE" && pwd)"
trap 'rm -rf "$BASE"' EXIT

pass=0
fail=0
sb_count=0

ok()  { pass=$((pass + 1)); echo "PASS: $1"; }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

# Fresh sandbox: $FAKEHOME is $HOME, $SB/bin holds stubs, $SB/calls.log records
# every stub invocation as "<name> <args>".
sandbox() {
    sb_count=$((sb_count + 1))
    SB="$BASE/$sb_count"
    FAKEHOME="$SB/home"
    LOG="$SB/calls.log"
    mkdir -p "$FAKEHOME" "$SB/bin"
    : > "$LOG"
}

# stub <name> [stdout]: a command on PATH that logs its invocation, prints the
# given stdout, and exits $STUB_EXIT (default 1) when "<name> <args...>" starts
# with any '|'-separated entry of $STUB_FAIL (e.g. STUB_FAIL='make -C /r
# macos-doctor|gh auth status').
stub() {
    cat > "$SB/bin/$1" <<EOF
#!/bin/bash
me="\$(basename "\$0")"
call="\$me \$*"
echo "\$call" >> "$LOG"
IFS='|'
for f in \${STUB_FAIL:-}; do
    case "\$call" in "\$f"*) exit "\${STUB_EXIT:-1}" ;; esac
done
printf '%s\n' '${2:-}'
EOF
    chmod +x "$SB/bin/$1"
}

# Run make in the real repo with the sandbox HOME and stubs first on PATH.
mk() {
    set +e
    out="$(cd "$ROOT" && HOME="$FAKEHOME" PATH="$SB/bin:$PATH" make "$@" 2>&1)"
    status=$?
    set -e
}

test_link_karabiner_is_idempotent() {
    sandbox
    mk link-karabiner
    mk link-karabiner
    if [ "$status" -eq 0 ] && [ "$(readlink "$FAKEHOME/.config/karabiner")" = "$ROOT/karabiner" ]; then
        ok "link-karabiner runs twice and leaves the link pointing at the repo"
    else
        bad "link-karabiner second run: status=$status out=$out"
    fi
}

test_link_karabiner_refuses_real_directory() {
    sandbox
    mkdir -p "$FAKEHOME/.config/karabiner"
    mk link-karabiner
    if [ "$status" -ne 0 ] && echo "$out" | grep -q "not a symlink" && [ -d "$FAKEHOME/.config/karabiner" ]; then
        ok "link-karabiner refuses to replace a real directory"
    else
        bad "link-karabiner real dir: status=$status out=$out"
    fi
}

test_link_sublime_skips_existing_clone() {
    sandbox
    stub git
    mkdir -p "$FAKEHOME/.sublime3/.git" "$FAKEHOME/Library/Application Support"
    mk link-sublime
    mk link-sublime
    if [ "$status" -eq 0 ] && ! grep -q '^git clone' "$LOG" \
        && [ "$(readlink "$FAKEHOME/Library/Application Support/Sublime Text")" = "$FAKEHOME/.sublime3" ]; then
        ok "link-sublime skips the clone when ~/.sublime3 exists and links once"
    else
        bad "link-sublime existing: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_link_sublime_refuses_real_directory() {
    sandbox
    stub git
    mkdir -p "$FAKEHOME/.sublime3/.git" "$FAKEHOME/Library/Application Support/Sublime Text"
    mk link-sublime
    if [ "$status" -ne 0 ] && echo "$out" | grep -q "not a symlink" && [ -d "$FAKEHOME/Library/Application Support/Sublime Text" ]; then
        ok "link-sublime refuses to replace a real directory"
    else
        bad "link-sublime real dir: status=$status out=$out"
    fi
}

test_brew_install_skips_when_present() {
    sandbox
    stub curl
    printf '#!/bin/bash\n' > "$SB/brew"; chmod +x "$SB/brew"
    mk brew-install BREW="$SB/brew"
    if [ "$status" -eq 0 ] && echo "$out" | grep -q "already installed" && ! grep -q '^curl' "$LOG"; then
        ok "brew-install skips the installer when brew exists"
    else
        bad "brew-install skip: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_set_shell_skips_when_already_set() {
    sandbox
    stub sudo
    stub chsh
    stub dscl "UserShell: $SB/bash"
    printf '#!/bin/bash\n' > "$SB/bash"; chmod +x "$SB/bash"
    echo "$SB/bash" > "$SB/shells"
    mk set-shell BREW_BASH="$SB/bash" SHELLS_FILE="$SB/shells"
    if [ "$status" -eq 0 ] && ! grep -q '^chsh' "$LOG" && ! grep -q '^sudo' "$LOG"; then
        ok "set-shell does nothing when /etc/shells and the login shell already match"
    else
        bad "set-shell skip: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_set_shell_appends_and_changes() {
    sandbox
    stub chsh
    stub dscl "UserShell: /bin/zsh"
    # sudo stub that actually runs its command so `sudo tee -a` appends.
    printf '#!/bin/bash\necho "sudo $*" >> "%s"\nexec "$@"\n' "$LOG" > "$SB/bin/sudo"; chmod +x "$SB/bin/sudo"
    printf '#!/bin/bash\n' > "$SB/bash"; chmod +x "$SB/bash"
    : > "$SB/shells"
    mk set-shell BREW_BASH="$SB/bash" SHELLS_FILE="$SB/shells"
    if [ "$status" -eq 0 ] && grep -qx "$SB/bash" "$SB/shells" && grep -q "^chsh -s $SB/bash" "$LOG"; then
        ok "set-shell appends the shell and runs chsh when they differ"
    else
        bad "set-shell change: status=$status out=$out shells=$(cat "$SB/shells") log=$(cat "$LOG")"
    fi
}

test_set_shell_requires_brew_bash() {
    sandbox
    mk set-shell BREW_BASH="$SB/missing" SHELLS_FILE="$SB/shells"
    if [ "$status" -ne 0 ] && echo "$out" | grep -q "brew-bundle"; then
        ok "set-shell fails with a pointer to brew-bundle when the shell is missing"
    else
        bad "set-shell missing: status=$status out=$out"
    fi
}

# --- setup-lib.sh ----------------------------------------------------------

# A minimal sourcing script: two guards, three runs, and both OS entry points.
lib_fixture() {
    mkdir -p "$SB/repo/scripts"
    cp "$ROOT/scripts/setup-lib.sh" "$SB/repo/scripts/"
    cp "$ROOT/scripts/host-id.sh" "$SB/repo/scripts/"
    cat > "$SB/repo/fixture.sh" <<'EOF'
#!/bin/bash
set -euf -o pipefail
SETUP_ROOT="$(cd "$(dirname "$0")" && pwd)"
. "$SETUP_ROOT/scripts/setup-lib.sh"
holds() { return 0; }
fails() { return 1; }
run_a() { echo "ran a"; }
run_b() { echo "ran b"; }
run_c() { echo "ran c"; }
setup_darwin() {
    step "a" holds run_a
    step "b" fails run_b
    first_run_step "c" run_c
    if [ "${FIXTURE_CHECKPOINT:-0}" = 1 ]; then checkpoint 7 "do the thing"; fi
    echo "after checkpoint"
}
setup_linux() { echo "linux path"; }
run_setup "$@"
EOF
    chmod +x "$SB/repo/fixture.sh"
}

# Run the fixture with a stubbed uname and the sandbox HOME.
fixture() {
    set +e
    out="$(HOME="$FAKEHOME" PATH="$SB/bin:$PATH" "$SB/repo/fixture.sh" "$@" 2>&1 </dev/null)"
    status=$?
    set -e
}

test_step_skips_runs_and_reports() {
    sandbox; lib_fixture; stub uname Darwin
    fixture
    if [ "$status" -eq 0 ] && echo "$out" | grep -q '^skip: a$' && echo "$out" | grep -q '^run: b$' \
        && echo "$out" | grep -q '^ran b$' && ! echo "$out" | grep -q 'ran a'; then
        ok "step skips when the guard holds and runs when it fails"
    else
        bad "step: status=$status out=$out"
    fi
}

test_dry_run_would_not_run() {
    sandbox; lib_fixture; stub uname Darwin
    fixture --dry-run
    if [ "$status" -eq 0 ] && echo "$out" | grep -q '^would: b$' && ! echo "$out" | grep -q 'ran b'; then
        ok "--dry-run prints would: and runs nothing"
    else
        bad "dry-run: status=$status out=$out"
    fi
}

test_first_run_step_is_gated() {
    sandbox; lib_fixture; stub uname Darwin
    fixture
    local off="$out"
    SETUP_FIRST_RUN=1 fixture
    if echo "$off" | grep -q '^skip: c (first run only)$' && echo "$out" | grep -q '^ran c$'; then
        ok "first_run_step runs only when SETUP_FIRST_RUN=1"
    else
        bad "first_run: off=$off on=$out"
    fi
}

test_checkpoint_halts_with_exit_1() {
    sandbox; lib_fixture; stub uname Darwin
    FIXTURE_CHECKPOINT=1 fixture
    if [ "$status" -eq 1 ] && echo "$out" | grep -q '^checkpoint 7: do the thing$' \
        && echo "$out" | grep -q '^re-run .*fixture\.sh when done\.$' && ! echo "$out" | grep -q 'after checkpoint'; then
        ok "checkpoint prints its instruction and exits 1 before later steps"
    else
        bad "checkpoint: status=$status out=$out"
    fi
}

test_converged_line_and_linux_dispatch() {
    sandbox; lib_fixture; stub uname Linux
    fixture
    if [ "$status" -eq 0 ] && echo "$out" | grep -q '^linux path$' && echo "$out" | grep -q '^setup: converged (Linux)$'; then
        ok "run_setup dispatches on uname and prints the converged line"
    else
        bad "dispatch: status=$status out=$out"
    fi
}

test_unknown_flag_is_usage_error() {
    sandbox; lib_fixture; stub uname Darwin
    fixture --bogus
    if [ "$status" -eq 2 ] && echo "$out" | grep -q '^usage: setup.sh'; then
        ok "an unknown flag prints usage and exits 2"
    else
        bad "usage: status=$status out=$out"
    fi
}

test_unsupported_os_fails() {
    sandbox; lib_fixture; stub uname Plan9
    fixture
    if [ "$status" -eq 1 ] && echo "$out" | grep -q 'unsupported OS Plan9'; then
        ok "an unsupported OS exits 1 with its name"
    else
        bad "unsupported: status=$status out=$out"
    fi
}

test_run_without_tty_survives() {
    # fixture() already redirects stdin from /dev/null; with no controlling
    # terminal (CI) the /dev/tty reopen must be skipped, not fatal.
    sandbox; lib_fixture; stub uname Linux
    fixture
    if [ "$status" -eq 0 ]; then
        ok "a run with stdin not a tty completes"
    else
        bad "no-tty: status=$status out=$out"
    fi
}

test_link_karabiner_is_idempotent
test_link_karabiner_refuses_real_directory
test_link_sublime_skips_existing_clone
test_link_sublime_refuses_real_directory
test_brew_install_skips_when_present
test_set_shell_skips_when_already_set
test_set_shell_appends_and_changes
test_set_shell_requires_brew_bash
test_step_skips_runs_and_reports
test_dry_run_would_not_run
test_first_run_step_is_gated
test_checkpoint_halts_with_exit_1
test_converged_line_and_linux_dispatch
test_unknown_flag_is_usage_error
test_unsupported_os_fails
test_run_without_tty_survives

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
