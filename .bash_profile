# on macos, iterm and tmux will source this for every new window or pane.
# screen will *not* source this on new screen creation (ctrl+a,c)

source_if_exists() {
  [ -s "$1" ] && source "$1"
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

source_if_exists "/usr/local/opt/asdf/libexec/asdf.sh"
source_if_exists "/usr/local/etc/profile.d/autojump.sh"
source_if_exists "/usr/local/etc/bash_completion"

source_if_exists "$HOME/.bashrc"





