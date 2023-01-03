# on macos, iterm and tmux will source this for every new window or pane.
# screen will *not* source this on new screen creation (ctrl+a,c)

BASH_REPORT_MISSING_SOURCES=false

source_if_exists() {
  if [[ -s "$1" ]]; then
    source "$1"
  elif $BASH_REPORT_MISSING_SOURCES; then
    echo "Skipping $1"
  fi
}

prepend_path_if_exists() {
  [ -d "$1" ] && export PATH="$1:$PATH"
}

# don't bother adding paths if it'll do no good.
# this is to make cross-platform support cleaner.
prepend_path_if_exists "/opt/homebrew/bin" # apple silicon homebrew
prepend_path_if_exists "$HOME/.local/bin"
prepend_path_if_exists "$HOME/bin"

# always prefer the current directory's bin
export PATH="./bin:$PATH"

export HOMEBREW_ROOT="$(brew --prefix)"

source_if_exists "${HOMEBREW_ROOT}/opt/asdf/libexec/asdf.sh"
source_if_exists "${HOMEBREW_ROOT}/etc/profile.d/autojump.sh"
source_if_exists "${HOMEBREW_ROOT}/etc/profile.d/bash_completion.sh"
source_if_exists "${HOMEBREW_ROOT}/etc/bash_completion"
source_if_exists "$HOME/.fzf.bash"

source_if_exists "$HOME/.bashrc"





