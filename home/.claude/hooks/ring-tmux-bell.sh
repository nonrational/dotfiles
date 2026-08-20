#!/usr/bin/env bash
# Stop + Notification hook: sets this pane's tmux window bell flag, so an
# inactive window renders reverse-video in the status bar until you visit it.
# tmux's defaults already do the rendering (monitor-bell on, bell-action any,
# window-status-bell-style reverse), so .tmux.conf needs nothing for this.
#
# Writes BEL to the pane tty rather than /dev/tty: Claude spawns hooks without
# a controlling terminal, so /dev/tty does not resolve.
set -u

# Hooks are handed JSON on stdin. Drain it even though nothing here reads it.
cat >/dev/null

# TMUX_PANE, not the active pane: several sessions may run in sibling panes,
# and each one has to flag the window it actually lives in.
[[ -z "${TMUX:-}" || -z "${TMUX_PANE:-}" ]] && exit 0

pane_tty=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null)
[[ -c "${pane_tty:-}" ]] || exit 0

printf '\a' > "$pane_tty" 2>/dev/null

# Explicit: a failed write must never block the stop.
exit 0
