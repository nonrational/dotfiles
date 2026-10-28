# fzf's key bindings, matching ~/.fzf.bash: Ctrl-R history (in place of fish's
# own pager), Ctrl-T files, Alt-C cd. `fzf --fish` needs fzf 0.48 or later.
status is-interactive; and command -q fzf; or return

fzf --fish | source
