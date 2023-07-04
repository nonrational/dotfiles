# on macos, iterm and tmux will source this for every new window or pane.
# screen will *not* source this on new screen creation (ctrl+a,c)

BASH_REPORT_MISSING_SOURCES=true

# Copied from https://github.com/scop/bash-completion/bash_completion
# Fixes https://github.com/Backblaze/B2_Command_Line_Tool/issues/500
_have()
{
    # Completions for system administrator commands are installed as well in
    # case completion is attempted via `sudo command ...'.
    PATH=$PATH:/usr/sbin:/sbin:/usr/local/sbin type $1 &>/dev/null
}

prepend_new_path_if_exists() {
  [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]] && export PATH="$1:$PATH"
}

# don't bother adding paths if it'll do no good.
# this is to make cross-platform support cleaner.
prepend_new_path_if_exists "/opt/homebrew/bin"  # apple silicon homebrew bin
prepend_new_path_if_exists "/opt/homebrew/sbin" # apple silicon homebrew static bin
prepend_new_path_if_exists "$HOME/.local/bin"
prepend_new_path_if_exists "$HOME/bin"

source_if_exists() {
  if [[ -s "$1" ]]; then
    source "$1"
  elif $BASH_REPORT_MISSING_SOURCES; then
    echo "Skipping $1"
  fi
}

# TODO: move this to darwin, perhaps including the homebrew path addition above
if command -v brew &> /dev/null; then
  export HOMEBREW_ROOT="$(brew --prefix)"
  source_if_exists "${HOMEBREW_ROOT}/opt/asdf/libexec/asdf.sh"
  source_if_exists "${HOMEBREW_ROOT}/etc/profile.d/autojump.sh"
  source_if_exists "${HOMEBREW_ROOT}/etc/profile.d/bash_completion.sh"
fi

source_if_exists "$HOME/.fzf.bash"
source_if_exists "$HOME/.bashrc"

# always prefer the current directory's bin
export PATH="./bin:$PATH"
