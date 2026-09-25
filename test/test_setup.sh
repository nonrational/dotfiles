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

test_link_karabiner_is_idempotent
test_link_karabiner_refuses_real_directory
test_link_sublime_skips_existing_clone
test_link_sublime_refuses_real_directory
test_brew_install_skips_when_present
test_set_shell_skips_when_already_set
test_set_shell_appends_and_changes
test_set_shell_requires_brew_bash

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
