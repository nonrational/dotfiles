#!/bin/bash
# setup-lib.sh: the harness behind setup.sh. A step runner with guards, a
# first-run gate, checkpoints that halt for a human, --dry-run, and OS
# dispatch. Sourced by a setup.sh that sets SETUP_ROOT and defines
# setup_darwin and setup_linux; never executed directly. Vendored downstream
# beside deploy.sh, so nothing here names a repo or any of its targets.
# Spec: docs/superpowers/specs/2026-09-25-setup-script-design.md

: "${SETUP_ROOT:?setup-lib.sh: the sourcing script must set SETUP_ROOT}"
. "$SETUP_ROOT/scripts/host-id.sh"

SETUP_DRY_RUN=0
SETUP_FIRST_RUN="${SETUP_FIRST_RUN:-0}"

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
        return 0
    fi
    echo "run: $name"
    "$run"
}

# first_run_step <name> <run>: runs only when the self-clone marked this run
# as the first on the machine. There is no guard: these steps are the
# destructive ones, and the clone is the only evidence they are wanted.
first_run_step() {
    local name="$1" run="$2"
    if [ "$SETUP_FIRST_RUN" != 1 ]; then
        echo "skip: $name (first run only)"
        return 0
    fi
    if [ "$SETUP_DRY_RUN" = 1 ]; then
        echo "would: $name"
        return 0
    fi
    echo "run: $name"
    "$run"
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
            exit 1
            ;;
    esac
    echo
    echo "setup: converged ($(os_id))"
}
