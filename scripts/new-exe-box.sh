#!/bin/bash
# new-exe-box.sh <name>: create an exe.dev VM and bring it up as an
# @nonreagent host in one go. Creates the box, waits for ssh, hands
# @nonreagent's GitHub token from 1Password to gh over ssh stdin (never as an
# argument, never through exe.dev's --env or setup-script), then runs
# nonreagent/dotfiles' setup.sh on the box. Runs from the Mac: it needs the
# human's exe.dev ssh key and an unlocked `op`.
# Spec: docs/superpowers/specs/2026-09-25-setup-script-design.md
set -euf -o pipefail

name="${1:-}"
[ -n "$name" ] || { echo "usage: new-exe-box.sh <name>" >&2; exit 2; }

EXE_BOX_SETUP_URL="${EXE_BOX_SETUP_URL:-https://raw.githubusercontent.com/nonreagent/dotfiles/main/setup.sh}"
EXE_BOX_GH_TOKEN_REF="${EXE_BOX_GH_TOKEN_REF:-op://Private/nonreagent-github/token}"
EXE_BOX_WAIT="${EXE_BOX_WAIT:-300}"
EXE_BOX_POLL="${EXE_BOX_POLL:-5}"

host="$name.exe.xyz"
# accept-new: a fresh box has an unknown host key, and a non-interactive ssh
# would otherwise hang on the prompt (exe.dev's own skill file warns of this).
ssh_opts="-o StrictHostKeyChecking=accept-new"

echo "creating $name"
# shellcheck disable=SC2086
ssh $ssh_opts exe.dev new --name "$name" --json >/dev/null

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

echo "authenticating gh as @nonreagent"
# shellcheck disable=SC2086
op read "$EXE_BOX_GH_TOKEN_REF" | ssh $ssh_opts "$host" 'gh auth login --with-token && gh auth setup-git'

echo "running setup on $host"
# shellcheck disable=SC2086
ssh $ssh_opts "$host" "curl -fsSL $EXE_BOX_SETUP_URL | bash"

echo "ready: $host https://$host/"
