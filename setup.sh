#!/bin/bash
# setup.sh: bring this machine to the state the repo describes. Re-runnable:
# every step skips when its guard holds, three checkpoints halt for a human,
# and the two destructive steps run only when this script had to clone.
# Spec: docs/superpowers/specs/2026-09-25-setup-script-design.md
#
#   curl -fsSL https://raw.githubusercontent.com/nonrational/dotfiles/main/setup.sh | bash
#   ./setup.sh [--dry-run]
set -euf -o pipefail

SETUP_REPO_URL="${SETUP_REPO_URL:-https://github.com/nonrational/dotfiles}"
SETUP_CLONE_DIR="${SETUP_CLONE_DIR:-$HOME/.dotfiles}"
SETUP_BREW="${SETUP_BREW:-/opt/homebrew/bin/brew}"
SETUP_BREW_BASH="${SETUP_BREW_BASH:-/opt/homebrew/bin/bash}"
SETUP_ETC_SHELLS="${SETUP_ETC_SHELLS:-/etc/shells}"
# Records whether this run applied the macos-defaults table, so the reboot follows an apply and only an apply.
SETUP_MACOS_APPLIED=0

# Under `curl | bash` there is no file on disk and no lib to source, so this
# part cannot live in setup-lib.sh. Clone, mark the first run, and exec the
# on-disk copy; everything after this runs from a checkout.
setup_self_bootstrap() {
    local here=""
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    if [ -n "$here" ] && [ -f "$here/scripts/setup-lib.sh" ]; then
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
        echo "re-run the curl command when done."
        exit 1
    fi
    if [ ! -d "$SETUP_CLONE_DIR/.git" ]; then
        git clone "$SETUP_REPO_URL" "$SETUP_CLONE_DIR"
        export SETUP_FIRST_RUN=1
    fi
    exec "$SETUP_CLONE_DIR/setup.sh" "$@"
}

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
    local path
    while read -r path; do
        [ -n "$(ls -A "$SETUP_ROOT/$path" 2>/dev/null)" ] || return 1
    done < <(git config -f "$SETUP_ROOT/.gitmodules" --get-regexp '\.path$' | awk '{print $2}')
    return 0
}
deployed() { "$SETUP_ROOT/deploy.sh" audit >/dev/null 2>&1; }
karabiner_linked() { [ "$(readlink "$HOME/.config/karabiner" 2>/dev/null)" = "$SETUP_ROOT/karabiner" ]; }
bridge_loaded() { launchctl list 2>/dev/null | grep -q org.nonrational.clipboard-bridge; }
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
reset_dock() { mk macos-reset-dock; }
disable_restore() { mk macos-disable-restore-apps-on-login; }
doctor_or_halt() {
    mk macos-doctor \
        || checkpoint 2 "grant Full Disk Access to this terminal (System Settings > Privacy & Security), then restart the terminal."
}
apply_macos() {
    mk macos-apply
    "$SETUP_ROOT/scripts/macos-bootstrap.sh"
    SETUP_MACOS_APPLIED=1
}
reboot_mac() {
    echo "checkpoint 3: rebooting. Run $0 once more afterwards; it should report every step as skip."
    osascript -e 'tell app "loginwindow" to «event aevtrrst»'
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
    # shellcheck source=scripts/setup-lib.sh
    . "$SETUP_ROOT/scripts/setup-lib.sh"
    run_setup "$@"
}

main "$@"
