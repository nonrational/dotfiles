test (uname) = Darwin; or return

# -w blocks until the tab closes, so tools that shell out to $EDITOR
# (git commit, crontab -e) see the saved file; -n gives those short-lived
# edits a window of their own. VISUAL is set too because some tools read it first.
set -gx EDITNOW 'subl -w'
set -gx EDITOR 'subl -w -n'
set -gx VISUAL 'subl -w -n'
# -i case-insensitive search, -F quit if it fits on one screen, -R pass ANSI
# colors through (git log/diff), -X leave output on screen after quitting
set -gx LESS "$LESS -i -F -R -X"

# BSD tools (ls et al.) only colorize when CLICOLOR is set
set -gx CLICOLOR 1

# /bin/ls pins the BSD ls no matter what PATH shuffling (GNU coreutils) does
alias ls '/bin/ls -F'

# Workaround for Homebrew tmuxinator issue
# https://github.com/Homebrew/homebrew-core/issues/59484
set -e GEM_HOME

# Default 256/1024 open files is too low for dev servers and watchers
ulimit -n 4096
