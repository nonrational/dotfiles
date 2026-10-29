#!/bin/bash
# setup.sh: bring this machine to the state the repo describes. One file: a
# step runner with guards, a first-run flag, checkpoints that halt for a
# human, --dry-run, and OS dispatch, followed by the steps themselves.
# Re-runnable: every step skips when its guard holds, three checkpoints halt
# for a human, and the two destructive steps run only when this script had to
# clone.
# Spec: docs/superpowers/specs/2026-09-25-setup-script-design.md
#
#   curl -sS https://nonration.al/setup.sh | bash
#   ./setup.sh [--dry-run]
set -euf -o pipefail

SETUP_REPO_URL="${SETUP_REPO_URL:-https://github.com/nonrational/dotfiles}"
SETUP_CLONE_DIR="${SETUP_CLONE_DIR:-$HOME/.dotfiles}"
# Set to test an unmerged branch; empty clones the default branch.
SETUP_BRANCH="${SETUP_BRANCH:-}"
SETUP_BREW="${SETUP_BREW:-/opt/homebrew/bin/brew}"
SETUP_BREW_BASH="${SETUP_BREW_BASH:-/opt/homebrew/bin/bash}"
SETUP_ETC_SHELLS="${SETUP_ETC_SHELLS:-/etc/shells}"
SETUP_FIRST_RUN="${SETUP_FIRST_RUN:-0}"
# Records whether this run applied the macos-defaults table, so the reboot follows an apply and only an apply.
SETUP_MACOS_APPLIED=0

# Under `curl | bash` there is no file on disk, so there is no checkout to
# run from. Clone, mark the first run, and exec the on-disk copy; everything
# after this runs from a checkout.
setup_self_bootstrap() {
    local here=""
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    if [ -n "$here" ] && [ -f "$here/scripts/host-id.sh" ]; then
        SETUP_ROOT="$here"
        return 0
    fi
    case " $* " in
        *" --dry-run "*)
            echo "would: clone $SETUP_REPO_URL -> $SETUP_CLONE_DIR"
            exit 0
            ;;
    esac
    if [ "$(uname)" = Darwin ] && ! xcode-select -p >/dev/null 2>&1; then
        xcode-select --install >/dev/null 2>&1 || true
        echo
        echo "checkpoint 1: finish the Command Line Tools installer."
        echo "re-run: curl -sS https://nonration.al/setup.sh | bash"
        exit 1
    fi
    if [ ! -d "$SETUP_CLONE_DIR/.git" ]; then
        git clone ${SETUP_BRANCH:+--branch "$SETUP_BRANCH"} "$SETUP_REPO_URL" "$SETUP_CLONE_DIR" \
            || { echo "failed: clone" >&2; exit 2; }
        # A marker, not just the env flag: a step failing before the
        # first-run steps must not lose them on the re-run.
        touch "$SETUP_CLONE_DIR/.git/setup-first-run"
        export SETUP_FIRST_RUN=1
    fi
    if [ ! -x "$SETUP_CLONE_DIR/setup.sh" ]; then
        echo "error: $SETUP_CLONE_DIR has no setup.sh; run git -C $SETUP_CLONE_DIR pull, then re-run" >&2
        exit 2
    fi
    exec "$SETUP_CLONE_DIR/setup.sh" "$@"
}

# --- harness: step runner, checkpoints, dispatch ----------------------------

SETUP_DRY_RUN=0
# Counts the would: lines so a dry run can say how much is pending.
SETUP_PENDING=0

# step <name> <guard> <run>: skip when the guard exits 0; otherwise run, or
# under --dry-run say what would run. Guards and runs are function names.
step() {
    local name="$1" guard="$2" run="$3"
    if "$guard"; then
        echo "skip: $name"
        return 0
    fi
    if [ "$SETUP_DRY_RUN" = 1 ]; then
        echo "would: $name"
        SETUP_PENDING=$((SETUP_PENDING + 1))
        return 0
    fi
    echo "run: $name"
    "$run" || { echo "failed: $name" >&2; exit 2; }
}

# first_run_step <name> <run>: runs only when the self-clone marked this run
# as the first on the machine. There is no guard: these steps are the
# destructive ones, and the clone is the only evidence they are wanted.
first_run_step() {
    local name="$1" run="$2"
    if [ "$SETUP_FIRST_RUN" != 1 ] && [ ! -e "$SETUP_ROOT/.git/setup-first-run" ]; then
        echo "skip: $name (first run only)"
        return 0
    fi
    if [ "$SETUP_DRY_RUN" = 1 ]; then
        echo "would: $name"
        SETUP_PENDING=$((SETUP_PENDING + 1))
        return 0
    fi
    echo "run: $name"
    "$run" || { echo "failed: $name" >&2; exit 2; }
}

# checkpoint <n> <message...>: halt for a human. Exit 1 so a wrapper can tell
# "halted" (1) from "converged" (0) and from a failed step's own nonzero exit.
checkpoint() {
    local n="$1"
    shift
    echo
    echo "checkpoint $n: $*"
    echo "re-run $0 when done."
    exit 1
}

setup_usage() {
    echo "usage: setup.sh [--dry-run]"
}

run_setup() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run) SETUP_DRY_RUN=1 ;;
            -h | --help) setup_usage; exit 0 ;;
            *) setup_usage >&2; exit 2 ;;
        esac
    done
    # Under `curl | bash` stdin is the script itself. Give sudo and gh their
    # prompts back when there is a terminal to give; CI has none, so skip.
    if [ ! -t 0 ] && [ "$SETUP_DRY_RUN" != 1 ] && ( : </dev/tty ) 2>/dev/null; then
        exec </dev/tty
    fi
    case "$(os_id)" in
        Darwin) setup_darwin ;;
        Linux) setup_linux ;;
        *)
            echo "error: unsupported OS $(os_id)" >&2
            exit 2
            ;;
    esac
    echo
    if [ "$SETUP_DRY_RUN" = 1 ]; then
        echo "setup: dry run ($(os_id)), $SETUP_PENDING would run"
    else
        echo "setup: converged ($(os_id))"
    fi
}

# --- steps ------------------------------------------------------------------

mk() {
    make -C "$SETUP_ROOT" "$@"
}

# --- guards: exit 0 when the step's end state already holds -----------------

have_clt() { xcode-select -p >/dev/null 2>&1; }
have_brew() { [ -x "$SETUP_BREW" ]; }
shell_is_brew() {
    grep -qx "$SETUP_BREW_BASH" "$SETUP_ETC_SHELLS" 2>/dev/null \
        && [ "$(dscl . -read ~ UserShell 2>/dev/null | awk '{print $2}')" = "$SETUP_BREW_BASH" ]
}
submodules_present() {
    # `submodule status` lists only paths with a gitlink, so a stale
    # .gitmodules entry drops out; a leading '-' marks an uninitialized one.
    local out
    out="$(git -C "$SETUP_ROOT" submodule status 2>/dev/null)" || return 1
    ! grep -q '^-' <<<"$out"
}
deployed() { "$SETUP_ROOT/deploy.sh" audit >/dev/null 2>&1; }
karabiner_linked() { [ "$(readlink "$HOME/.config/karabiner" 2>/dev/null)" = "$SETUP_ROOT/karabiner" ]; }
# No pipe: under pipefail a SIGPIPE'd launchctl would read as not loaded.
bridge_loaded() { launchctl list org.nonrational.clipboard-bridge >/dev/null 2>&1; }
gh_authed() { gh auth status >/dev/null 2>&1; }
sublime_linked() {
    [ -d "$HOME/.sublime3/.git" ] \
        && [ "$(readlink "$HOME/Library/Application Support/Sublime Text" 2>/dev/null)" = "$HOME/.sublime3" ]
}
restore_disabled() {
    [ -d "$HOME/Library/Preferences/ByHost" ] \
        && [ -z "$(find "$HOME/Library/Preferences/ByHost" -name 'com.apple.loginwindow*' ! -size 0 2>/dev/null)" ]
}
# Guards macos-apply: the table's own audit, run after doctor so FDA is
# granted. A converged Mac skips it instead of applying every run.
macos_converged() { "$SETUP_ROOT/scripts/macos-defaults.sh" audit >/dev/null 2>&1; }
# Guards reboot: only this run's own apply should trigger it, not a stale
# "not converged" reading left over from a prior failed run. Under --dry-run
# apply_macos never runs and so never sets the flag, so fall back to the same
# audit apply's own guard previews against, keeping the two would: lines in
# step.
macos_not_applied() {
    if [ "$SETUP_DRY_RUN" = 1 ]; then
        macos_converged
    else
        [ "$SETUP_MACOS_APPLIED" != 1 ]
    fi
}
never() { return 1; }

# --- runs -------------------------------------------------------------------

clt_checkpoint() {
    xcode-select --install >/dev/null 2>&1 || true
    checkpoint 1 "finish the Command Line Tools installer."
}
brew_install() { mk brew-install; }
brew_bundle() { mk brew-bundle; }
set_shell() { mk set-shell; }
init_submodules() { mk init-submodules; }
deploy() { mk deploy; }
link_karabiner() { mk link-karabiner; }
clipboard_bridge() { mk clipboard-bridge; }
gh_login() { gh auth login; }
link_sublime() { mk link-sublime; }
restore_preferences() { mk restore-preferences; }
# The last first-run step; clearing the marker here ends the first run.
reset_dock() { mk macos-reset-dock && rm -f "$SETUP_ROOT/.git/setup-first-run"; }
disable_restore() { mk macos-disable-restore-apps-on-login; }
doctor_or_halt() {
    mk macos-doctor \
        || checkpoint 2 "grant Full Disk Access to this terminal (System Settings > Privacy & Security), then restart the terminal."
}
apply_macos() {
    # && chain: the caller's || disables errexit inside this function.
    mk macos-apply && "$SETUP_ROOT/scripts/macos-bootstrap.sh" && SETUP_MACOS_APPLIED=1
}
reboot_mac() {
    echo "rebooting. Run $0 once more afterwards; it should report every step as skip."
    osascript -e 'tell app "loginwindow" to «event aevtrrst»' \
        || checkpoint 3 "the reboot request failed (no GUI session?). Restart this Mac by hand, then re-run setup.sh once more."
}

setup_darwin() {
    step "command line tools" have_clt clt_checkpoint
    step "brew-install" have_brew brew_install
    if have_brew; then
        eval "$("$SETUP_BREW" shellenv)"
    fi
    step "brew-bundle" never brew_bundle
    step "set-shell" shell_is_brew set_shell
    step "init-submodules" submodules_present init_submodules
    step "deploy" deployed deploy
    step "link-karabiner" karabiner_linked link_karabiner
    step "clipboard-bridge" bridge_loaded clipboard_bridge
    step "gh auth login" gh_authed gh_login
    step "link-sublime" sublime_linked link_sublime
    first_run_step "restore-preferences" restore_preferences
    first_run_step "macos-reset-dock" reset_dock
    step "macos-disable-restore-apps-on-login" restore_disabled disable_restore
    step "macos-doctor" never doctor_or_halt
    step "macos-apply + macos-bootstrap" macos_converged apply_macos
    step "reboot" macos_not_applied reboot_mac
}

setup_linux() {
    step "init-submodules" submodules_present init_submodules
    step "deploy" deployed deploy
}

main() {
    setup_self_bootstrap "$@"
    # shellcheck source=scripts/host-id.sh
    . "$SETUP_ROOT/scripts/host-id.sh"
    run_setup "$@"
}

main "$@"
