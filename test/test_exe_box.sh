#!/bin/bash
# Tests for scripts/new-exe-box.sh. Everything runs under a mktemp sandbox with
# stub commands on PATH, so no test touches the real $HOME, op, or exe.dev.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-exe-box.XXXXXX")"
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


# An ssh stub that logs each call, saves whatever arrived on stdin for the
# call that ran `gh auth login`, and fails `<host> true` the first
# $STUB_SSH_NOT_READY times (one counter across the existence probe and the
# wait loop). The default 0 answers at once, which takes the reuse path.
# $STUB_NEW_FAIL makes `exe.dev new` print that text on stdout and exit 1.
stub_ssh() {
    cat > "$SB/bin/ssh" <<EOS
#!/bin/bash
echo "ssh \$*" >> "$LOG"
case "\$*" in
    *" true")
        n=\$(cat "$SB/notready" 2>/dev/null || echo 0)
        if [ "\$n" -lt "\${STUB_SSH_NOT_READY:-0}" ]; then echo \$((n + 1)) > "$SB/notready"; exit 255; fi
        ;;
    *"exe.dev new"*)
        if [ -n "\${STUB_NEW_FAIL:-}" ]; then printf '%s\n' "\$STUB_NEW_FAIL"; exit 1; fi
        ;;
    *"gh auth login"*) cat > "$SB/token.stdin" ;;
esac
exit 0
EOS
    chmod +x "$SB/bin/ssh"
}

exe_box() {
    set +e
    out="$(HOME="$FAKEHOME" PATH="$SB/bin:$PATH" EXE_BOX_POLL=0 EXE_BOX_WAIT="${EXE_BOX_WAIT:-5}" \
        EXE_BOX_REPO_URL="https://example.invalid/repo" \
        EXE_BOX_GH_TOKEN_REF="op://Vault/item/token" "$ROOT/scripts/new-exe-box.sh" "$@" 2>&1)"
    status=$?
    set -e
}

INSTALL_CMD='{ git -C ~/.dotfiles pull --ff-only || git clone https://example.invalid/repo ~/.dotfiles; } && ~/.dotfiles/install.sh && ~/.claude/sync-plugins.sh'

test_exe_box_creates_waits_injects_and_installs() {
    sandbox; stub_ssh; stub op "tok-123"
    STUB_SSH_NOT_READY=2 exe_box mybox
    if [ "$status" -eq 0 ] \
        && grep -q '^ssh .*exe.dev new --name mybox --json$' "$LOG" \
        && [ "$(grep -c '^ssh .*mybox.exe.xyz true$' "$LOG")" -eq 3 ] \
        && grep -q '^op read op://Vault/item/token$' "$LOG" \
        && grep -q '^ssh .*mybox.exe.xyz gh auth login --with-token && gh auth setup-git$' "$LOG" \
        && grep -qxF "ssh -o StrictHostKeyChecking=accept-new mybox.exe.xyz $INSTALL_CMD" "$LOG" \
        && [ "$(tail -2 <<<"$out" | head -1)" = "ready: mybox.exe.xyz https://mybox.exe.xyz/" ] \
        && [ "$(tail -1 <<<"$out")" = "optional: ssh mybox.exe.xyz ~/bin/setup-review-watcher" ]; then
        ok "new-exe-box creates the VM, waits for ssh, injects the token, installs, prints the URL"
    else
        bad "exe-box flow: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_exe_box_reuses_existing_box() {
    sandbox; stub_ssh; stub op "tok-123"
    exe_box mybox
    if [ "$status" -eq 0 ] \
        && echo "$out" | grep -q 'using existing mybox.exe.xyz' \
        && ! grep -q 'exe.dev new' "$LOG" \
        && grep -qF "$INSTALL_CMD" "$LOG"; then
        ok "new-exe-box reuses a box that already answers and still installs"
    else
        bad "reuse: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_bad_token_ref_creates_nothing() {
    sandbox; stub_ssh; stub op
    STUB_FAIL="op read" exe_box mybox
    if [ "$status" -ne 0 ] && ! grep -q '^ssh' "$LOG"; then
        ok "an unreadable token reference fails before any ssh call"
    else
        bad "bad token ref: status=$status out=$out log=$(cat "$LOG")"
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
    if [ "$status" -eq 1 ] && echo "$out" | grep -q 'did not answer within 1s' \
        && ! grep -q 'gh auth' "$LOG"; then
        ok "a box that never answers ssh fails with a timeout without sending the secret"
    else
        bad "timeout: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_exe_box_new_failure_is_reported() {
    sandbox; stub_ssh; stub op "tok-123"
    STUB_SSH_NOT_READY=1000000 STUB_NEW_FAIL='{"error":"name taken"}' exe_box mybox
    if [ "$status" -eq 1 ] && echo "$out" | grep -q 'name taken' && ! grep -q 'gh auth' "$LOG"; then
        ok "a failed exe.dev new prints its output and stops before the secret"
    else
        bad "new failure: status=$status out=$out log=$(cat "$LOG")"
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

test_exe_box_creates_waits_injects_and_installs
test_exe_box_reuses_existing_box
test_bad_token_ref_creates_nothing
test_token_goes_over_stdin_only
test_exe_box_times_out_waiting
test_exe_box_new_failure_is_reported
test_exe_box_requires_name

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
