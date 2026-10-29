#!/bin/bash
# new-exe-box.sh <name>: create (or reuse) an exe.dev VM and bring it up as an
# @nonreagent host in one go. Waits for ssh, hands @nonreagent's GitHub token
# from 1Password to gh over ssh stdin (never as an argument, never through
# exe.dev's --env or setup-script), then clones or pulls nonreagent/dotfiles
# and runs its install.sh and sync-plugins.sh. Runs from the Mac: it needs the
# human's exe.dev ssh key and an unlocked `op`.
# Spec: docs/superpowers/specs/2026-10-29-exe-box-design.md
set -euf -o pipefail

name="${1:-}"
[ -n "$name" ] || { echo "usage: new-exe-box.sh <name>" >&2; exit 2; }

EXE_BOX_REPO_URL="${EXE_BOX_REPO_URL:-https://github.com/nonreagent/dotfiles}"
EXE_BOX_GH_TOKEN_REF="${EXE_BOX_GH_TOKEN_REF:-op://Private/nonreagent-github/token}"
EXE_BOX_WAIT="${EXE_BOX_WAIT:-300}"
EXE_BOX_POLL="${EXE_BOX_POLL:-5}"

host="$name.exe.xyz"
# accept-new: a fresh box has an unknown host key, and a non-interactive ssh
# would otherwise hang on the prompt (exe.dev's own skill file warns of this).
ssh_opts="-o StrictHostKeyChecking=accept-new"

# Read the token before creating anything: a bad reference should cost a
# retry, not a half-provisioned VM. Empty stdin would also send gh into its
# interactive device flow.
token="$(op read "$EXE_BOX_GH_TOKEN_REF")"
[ -n "$token" ] || { echo "error: $EXE_BOX_GH_TOKEN_REF is empty" >&2; exit 1; }

# An existing box skips creation and the wait, so a re-run converges it.
# shellcheck disable=SC2086
if ssh $ssh_opts -o ConnectTimeout=5 "$host" true 2>/dev/null; then
    echo "using existing $host"
else
    echo "creating $name"
    # exe.dev reports errors (duplicate name, lobby) on stdout, so keep both
    # streams and show them on failure.
    # shellcheck disable=SC2086
    if ! new_out="$(ssh $ssh_opts exe.dev new --name "$name" --json 2>&1)"; then
        echo "error: exe.dev new failed for $name:" >&2
        printf '%s\n' "$new_out" >&2
        exit 1
    fi

    echo "waiting for $host"
    deadline=$(( $(date +%s) + EXE_BOX_WAIT ))
    # shellcheck disable=SC2086
    until ssh $ssh_opts -o ConnectTimeout=5 "$host" true 2>/dev/null; do
        if [ "$(date +%s)" -ge "$deadline" ]; then
            echo "error: $host did not answer within ${EXE_BOX_WAIT}s" >&2
            exit 1
        fi
        sleep "$EXE_BOX_POLL"
    done
fi

echo "authenticating gh as @nonreagent"
# shellcheck disable=SC2086
printf '%s\n' "$token" | ssh $ssh_opts "$host" 'gh auth login --with-token && gh auth setup-git'

echo "installing dotfiles on $host"
# Pull first so a re-run converges on current main. A pull that fails on an
# existing clone falls into `git clone` on a non-empty directory, which fails
# and stops the chain.
# The URL is quoted for the remote shell.
repo_q="$(printf '%q' "$EXE_BOX_REPO_URL")"
# shellcheck disable=SC2086
ssh $ssh_opts "$host" "{ git -C ~/.dotfiles pull --ff-only || git clone $repo_q ~/.dotfiles; } && ~/.dotfiles/install.sh && ~/.claude/sync-plugins.sh"

echo "ready: $host https://$host/"
echo "optional: ssh $host ~/bin/setup-review-watcher"
