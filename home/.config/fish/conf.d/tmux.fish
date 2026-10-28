# Hand tmux this pane's directory label (see @window-label in ~/.tmux.conf).
# tmux reads the cwd from the OS, which resolves symlinks (~/bin shows as
# bin.Darwin) and spells home as the username; $PWD has neither problem, and
# setting the option redraws the status line without tmux's 500ms rename delay.
status is-interactive; and set -q TMUX; or return

function __tmux_dir_label --on-variable PWD
    set -l label (path basename -- $PWD)
    test "$PWD" = "$HOME"; and set label '~'
    tmux set -p @dir_label $label 2>/dev/null
end

__tmux_dir_label
