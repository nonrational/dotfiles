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

# --- setup.sh --------------------------------------------------------------

# A sandbox repo: the real setup.sh and lib, a stub deploy.sh whose audit
# result is $STUB_DEPLOY_AUDIT (0/1), a stub scripts/macos-defaults.sh whose
# audit result is $STUB_MACOS_AUDIT (0/1), a stub macos-bootstrap.sh, a
# karabiner dir, one declared submodule, and a .git dir so the checkout
# detection holds.
setup_repo() {
    REPO="$SB/repo"
    mkdir -p "$REPO/scripts" "$REPO/karabiner" "$REPO/.git" "$REPO/etc/sub"
    cp "$ROOT/setup.sh" "$REPO/setup.sh"
    cp "$ROOT/scripts/setup-lib.sh" "$ROOT/scripts/host-id.sh" "$REPO/scripts/"
    printf '[submodule "sub"]\n\tpath = etc/sub\n\turl = x\n' > "$REPO/.gitmodules"
    printf '#!/bin/bash\necho "deploy.sh $*" >> "%s"\n[ "$1" = audit ] && exit "${STUB_DEPLOY_AUDIT:-1}"\nexit 0\n' "$LOG" > "$REPO/deploy.sh"
    printf '#!/bin/bash\necho "macos-defaults.sh $*" >> "%s"\n[ "$1" = audit ] && exit "${STUB_MACOS_AUDIT:-1}"\nexit 0\n' "$LOG" > "$REPO/scripts/macos-defaults.sh"
    printf '#!/bin/bash\necho "macos-bootstrap.sh" >> "%s"\n' "$LOG" > "$REPO/scripts/macos-bootstrap.sh"
    chmod +x "$REPO/deploy.sh" "$REPO/scripts/macos-defaults.sh" "$REPO/scripts/macos-bootstrap.sh"
    printf '#!/bin/bash\n[ "$1" = shellenv ] && exit 0\n' > "$SB/brew"; chmod +x "$SB/brew"
    printf '#!/bin/bash\n' > "$SB/bash"; chmod +x "$SB/bash"
    echo "$SB/bash" > "$SB/shells"
}

# Stubs describing a fully converged Mac; tests knock out one at a time.
converged_mac() {
    stub uname Darwin
    stub xcode-select
    stub make
    stub dscl "UserShell: $SB/bash"
    stub launchctl "org.nonrational.clipboard-bridge"
    stub gh
    stub osascript
    echo x > "$REPO/etc/sub/file"
    mkdir -p "$FAKEHOME/.config" "$FAKEHOME/.sublime3/.git" "$FAKEHOME/Library/Application Support" "$FAKEHOME/Library/Preferences/ByHost"
    ln -s "$REPO/karabiner" "$FAKEHOME/.config/karabiner"
    ln -s "$FAKEHOME/.sublime3" "$FAKEHOME/Library/Application Support/Sublime Text"
    : > "$FAKEHOME/Library/Preferences/ByHost/com.apple.loginwindow.ABC.plist"
    export STUB_DEPLOY_AUDIT=0
    export STUB_MACOS_AUDIT=0
}

setup_run() {
    set +e
    out="$(HOME="$FAKEHOME" PATH="$SB/bin:$PATH" SETUP_BREW="$SB/brew" SETUP_BREW_BASH="$SB/bash" \
        SETUP_ETC_SHELLS="$SB/shells" "$REPO/setup.sh" "$@" 2>&1 </dev/null)"
    status=$?
    set -e
}

# The make targets, in the order setup.sh must call them on a Mac that has
# nothing yet (first run, deploy audit failing, every guard false).
MAC_ORDER="brew-install brew-bundle set-shell init-submodules deploy link-karabiner clipboard-bridge link-sublime restore-preferences macos-reset-dock macos-disable-restore-apps-on-login macos-doctor macos-apply"

test_mac_runs_every_target_in_order_on_first_run() {
    sandbox; setup_repo
    rm "$SB/brew"
    stub uname Darwin; stub xcode-select; stub make; stub dscl "UserShell: /bin/zsh"; stub launchctl; stub gh; stub osascript
    export STUB_DEPLOY_AUDIT=1 STUB_FAIL='gh auth status'
    SETUP_FIRST_RUN=1 setup_run
    unset STUB_FAIL
    local targets
    targets="$(grep '^make -C' "$LOG" | awk '{print $4}' | tr '\n' ' ' | sed 's/ $//')"
    if [ "$status" -eq 0 ] && [ "$targets" = "$MAC_ORDER" ] && grep -q '^gh auth login$' "$LOG" \
        && grep -q '^macos-bootstrap.sh$' "$LOG" && grep -q '^osascript' "$LOG"; then
        ok "first run on a bare Mac calls every target in order, then bootstrap and reboot"
    else
        bad "mac order: status=$status targets=[$targets] out=$out"
    fi
}

test_mac_converged_is_all_skips() {
    sandbox; setup_repo; converged_mac
    setup_run
    if [ "$status" -eq 0 ] && ! grep -q '^make -C .* \(brew-install\|set-shell\|init-submodules\|deploy\|link-karabiner\|clipboard-bridge\|link-sublime\|macos-disable-restore-apps-on-login\)$' "$LOG" \
        && ! grep -q '^gh auth login' "$LOG" && ! grep -q 'restore-preferences\|macos-reset-dock' "$LOG" \
        && ! grep -q 'macos-apply' "$LOG" && ! grep -q '^osascript' "$LOG" \
        && echo "$out" | grep -q '^skip: restore-preferences (first run only)$'; then
        ok "a converged Mac skips every guarded target and the first-run steps"
    else
        bad "converged: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_mac_dry_run_runs_nothing() {
    sandbox; setup_repo
    stub uname Darwin; stub xcode-select; stub make; stub dscl "UserShell: /bin/zsh"; stub launchctl; stub gh; stub osascript
    export STUB_DEPLOY_AUDIT=1 STUB_MACOS_AUDIT=1
    setup_run --dry-run
    if [ "$status" -eq 0 ] && ! grep -q '^make' "$LOG" && ! grep -q '^osascript' "$LOG" \
        && echo "$out" | grep -q '^would: deploy$' && echo "$out" | grep -q '^would: reboot$'; then
        ok "--dry-run reports every pending step and calls no target"
    else
        bad "dry-run: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_missing_clt_is_checkpoint_1() {
    sandbox; setup_repo
    stub uname Darwin; stub xcode-select; stub make
    STUB_FAIL='xcode-select -p' setup_run
    if [ "$status" -eq 1 ] && echo "$out" | grep -q '^checkpoint 1: ' && grep -q '^xcode-select --install' "$LOG" && ! grep -q '^make' "$LOG"; then
        ok "missing Command Line Tools halts at checkpoint 1 before any target"
    else
        bad "clt: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_doctor_failure_is_checkpoint_2() {
    sandbox; setup_repo; converged_mac
    STUB_FAIL="make -C $REPO macos-doctor" setup_run
    if [ "$status" -eq 1 ] && echo "$out" | grep -q '^checkpoint 2: .*Full Disk Access' && ! grep -q 'macos-apply' "$LOG"; then
        ok "a failing macos-doctor halts at checkpoint 2 before apply"
    else
        bad "doctor: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_failed_step_stops_run() {
    sandbox; setup_repo; converged_mac
    export STUB_DEPLOY_AUDIT=1
    STUB_EXIT=2 STUB_FAIL="make -C $REPO deploy" setup_run
    if [ "$status" -ne 0 ] && [ "$status" -ne 1 ] && ! grep -q 'link-karabiner\|macos-doctor' "$LOG"; then
        ok "a failing step stops the run with its own exit code, not the checkpoint's"
    else
        bad "failed step: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_linux_runs_only_submodules_and_deploy() {
    sandbox; setup_repo
    stub uname Linux; stub make
    export STUB_DEPLOY_AUDIT=1
    SETUP_FIRST_RUN=1 setup_run
    local targets
    targets="$(grep '^make -C' "$LOG" | awk '{print $4}' | tr '\n' ' ' | sed 's/ $//')"
    if [ "$status" -eq 0 ] && [ "$targets" = "init-submodules deploy" ]; then
        ok "Linux runs init-submodules and deploy and nothing else"
    else
        bad "linux: status=$status targets=[$targets] out=$out"
    fi
}

# Piped runs: `cat setup.sh | bash` from outside any checkout.
pipe_run() {
    set +e
    out="$(cd "$SB" && cat "$ROOT/setup.sh" | HOME="$FAKEHOME" PATH="$SB/bin:$PATH" \
        SETUP_REPO_URL="https://example.invalid/dotfiles" bash -s -- "$@" 2>&1)"
    status=$?
    set -e
}

# A git stub whose clone creates a fake checkout with a setup.sh that reports
# how it was exec'd.
stub_git_clone() {
    cat > "$SB/bin/git" <<EOF
#!/bin/bash
echo "git \$*" >> "$LOG"
if [ "\$1" = clone ]; then
    mkdir -p "\$3/.git"
    cat > "\$3/setup.sh" <<'INNER'
#!/bin/bash
echo "exec-ed first_run=\${SETUP_FIRST_RUN:-0} args=\$*"
INNER
    chmod +x "\$3/setup.sh"
fi
EOF
    chmod +x "$SB/bin/git"
}

test_pipe_clones_and_execs_as_first_run() {
    sandbox; stub uname Linux; stub_git_clone
    pipe_run
    if [ "$status" -eq 0 ] && grep -q "^git clone https://example.invalid/dotfiles $FAKEHOME/.dotfiles$" "$LOG" \
        && echo "$out" | grep -q '^exec-ed first_run=1 args=$'; then
        ok "piped from outside a checkout, setup.sh clones and execs the clone as a first run"
    else
        bad "pipe clone: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_pipe_reuses_existing_clone() {
    sandbox; stub uname Linux; stub_git_clone
    mkdir -p "$FAKEHOME/.dotfiles/.git"
    printf '#!/bin/bash\necho "exec-ed first_run=${SETUP_FIRST_RUN:-0} args=$*"\n' > "$FAKEHOME/.dotfiles/setup.sh"
    chmod +x "$FAKEHOME/.dotfiles/setup.sh"
    pipe_run
    if [ "$status" -eq 0 ] && ! grep -q '^git clone' "$LOG" && echo "$out" | grep -q '^exec-ed first_run=0 args=$'; then
        ok "piped with ~/.dotfiles present, setup.sh execs it without marking a first run"
    else
        bad "pipe reuse: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_pipe_dry_run_does_not_clone() {
    sandbox; stub uname Linux; stub_git_clone
    pipe_run --dry-run
    if [ "$status" -eq 0 ] && ! grep -q '^git clone' "$LOG" && echo "$out" | grep -q '^would: clone https://example.invalid/dotfiles'; then
        ok "piped --dry-run reports the clone and does nothing"
    else
        bad "pipe dry-run: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_pipe_on_mac_without_clt_is_checkpoint_1() {
    sandbox; stub uname Darwin; stub xcode-select; stub_git_clone
    STUB_FAIL='xcode-select -p' pipe_run
    if [ "$status" -eq 1 ] && echo "$out" | grep -q '^checkpoint 1: ' && ! grep -q '^git clone' "$LOG"; then
        ok "piped on a Mac without Command Line Tools halts at checkpoint 1 before cloning"
    else
        bad "pipe clt: status=$status out=$out log=$(cat "$LOG")"
    fi
}

# --- new-exe-box.sh --------------------------------------------------------

# An ssh stub that logs each call, saves whatever arrived on stdin for the
# call that ran `gh auth login`, and fails `<host> true` the first
# $STUB_SSH_NOT_READY times so the wait loop has something to wait for.
stub_ssh() {
    cat > "$SB/bin/ssh" <<EOF
#!/bin/bash
echo "ssh \$*" >> "$LOG"
case "\$*" in
    *" true")
        n=\$(cat "$SB/notready" 2>/dev/null || echo 0)
        if [ "\$n" -lt "\${STUB_SSH_NOT_READY:-0}" ]; then echo \$((n + 1)) > "$SB/notready"; exit 255; fi
        ;;
    *"gh auth login"*) cat > "$SB/token.stdin" ;;
esac
exit 0
EOF
    chmod +x "$SB/bin/ssh"
}

exe_box() {
    set +e
    out="$(HOME="$FAKEHOME" PATH="$SB/bin:$PATH" EXE_BOX_POLL=0 EXE_BOX_WAIT="${EXE_BOX_WAIT:-5}" \
        EXE_BOX_SETUP_URL="https://example.invalid/setup.sh" \
        EXE_BOX_GH_TOKEN_REF="op://Vault/item/token" "$ROOT/scripts/new-exe-box.sh" "$@" 2>&1)"
    status=$?
    set -e
}

test_exe_box_creates_waits_injects_and_runs_setup() {
    sandbox; stub_ssh; stub op "tok-123"
    STUB_SSH_NOT_READY=2 exe_box mybox
    if [ "$status" -eq 0 ] \
        && grep -q '^ssh .*exe.dev new --name mybox --json$' "$LOG" \
        && [ "$(grep -c '^ssh .*mybox.exe.xyz true$' "$LOG")" -eq 3 ] \
        && grep -q '^op read op://Vault/item/token$' "$LOG" \
        && grep -q '^ssh .*mybox.exe.xyz gh auth login --with-token && gh auth setup-git$' "$LOG" \
        && grep -q '^ssh .*mybox.exe.xyz curl -fsSL https://example.invalid/setup.sh | bash$' "$LOG" \
        && [ "$(tail -1 <<<"$out")" = "ready: mybox.exe.xyz https://mybox.exe.xyz/" ]; then
        ok "new-exe-box creates the VM, waits for ssh, injects the token, runs setup, prints the URL"
    else
        bad "exe-box flow: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_token_goes_over_stdin_only() {
    sandbox; stub_ssh; stub op "tok-123"
    exe_box mybox
    if [ "$(cat "$SB/token.stdin")" = "tok-123" ] && ! grep -q 'tok-123' "$LOG" && ! echo "$out" | grep -q 'tok-123'; then
        ok "the token reaches ssh on stdin and appears in no argument or output"
    else
        bad "token: stdin=$(cat "$SB/token.stdin" 2>&1) log=$(cat "$LOG") out=$out"
    fi
}

test_exe_box_times_out_waiting() {
    sandbox; stub_ssh; stub op "tok-123"
    STUB_SSH_NOT_READY=1000000 EXE_BOX_WAIT=1 exe_box mybox
    if [ "$status" -eq 1 ] && echo "$out" | grep -q 'did not answer within 1s' && ! grep -q '^op read' "$LOG"; then
        ok "a box that never answers ssh fails with a timeout before any secret is read"
    else
        bad "timeout: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_exe_box_requires_name() {
    sandbox; stub_ssh; stub op
    exe_box
    if [ "$status" -ne 0 ] && echo "$out" | grep -q 'usage: new-exe-box.sh <name>' && ! grep -q '^ssh' "$LOG"; then
        ok "new-exe-box without a name prints usage and creates nothing"
    else
        bad "usage: status=$status out=$out log=$(cat "$LOG")"
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
test_mac_runs_every_target_in_order_on_first_run
test_mac_converged_is_all_skips
test_mac_dry_run_runs_nothing
test_missing_clt_is_checkpoint_1
test_doctor_failure_is_checkpoint_2
test_failed_step_stops_run
test_linux_runs_only_submodules_and_deploy
test_pipe_clones_and_execs_as_first_run
test_pipe_reuses_existing_clone
test_pipe_dry_run_does_not_clone
test_pipe_on_mac_without_clt_is_checkpoint_1
test_exe_box_creates_waits_injects_and_runs_setup
test_token_goes_over_stdin_only
test_exe_box_times_out_waiting
test_exe_box_requires_name

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
