# on macos, iterm and tmux will source this for every new window or pane.
# screen will *not* source this on new screen creation (ctrl+a,c)

BASH_REPORT_MISSING=true

prepend_new_path_if_exists() {
  if [ -d "$1" ]; then
    # Pop the path off PATH (with pipes) before prepending it to PATH. ;)
    # This is preferable to no-op'ing if the path already exists, to ensure that system paths
    # don't take precedence in tmux or screen-like environments.
    local CLEAN_PATH=$(echo "${PATH}:" | sed -e "s|$1:||" -e 's|:$||')
    export PATH="$1:$CLEAN_PATH"
  elif $BASH_REPORT_MISSING; then
    echo "$1 not added to PATH"
  fi
}

# don't bother adding paths if it'll do no good.
# this is to make cross-platform support cleaner.
prepend_new_path_if_exists "/opt/homebrew/bin"  # apple silicon homebrew bin
prepend_new_path_if_exists "/opt/homebrew/sbin" # apple silicon homebrew static bin
prepend_new_path_if_exists "$HOME/.local/bin"
prepend_new_path_if_exists "$HOME/bin"
prepend_new_path_if_exists "$HOME/.asdf/shims"

source_if_exists() {
  if [[ -s "$1" ]]; then
    source "$1"
  elif $BASH_REPORT_MISSING; then
    echo "$1 not sourced"
  fi
}

# TODO: move this to darwin, perhaps including the homebrew path addition above
if command -v brew &> /dev/null; then
  export HOMEBREW_ROOT="$(brew --prefix)"
  source_if_exists "${HOMEBREW_ROOT}/etc/profile.d/autojump.sh"
  source_if_exists "${HOMEBREW_ROOT}/etc/profile.d/bash_completion.sh"
fi


source_if_exists "$HOME/.fzf.bash" # fzf --bash > ~/.fzf.bash
source_if_exists "$HOME/.bashrc"

# always prefer the current directory's bin
export PATH="./bin:$PATH"
