# osx sources this on every new Terminal.app tab/window but NOT on new bash's
# so, screen will *not* source this on new screen creation (ctrl+a,c)

export BASH_SILENCE_DEPRECATION_WARNING=1

source_if_exists() {
  [[ -s "$1" ]] && source "$1"
}

# homebrew config
export PATH="./bin:$HOME/bin:$HOME/.local/bin:/usr/local/sbin:$PATH"

source_if_exists "/usr/local/opt/asdf/libexec/asdf.sh"
source_if_exists "/usr/local/etc/profile.d/autojump.sh"
source_if_exists "/usr/local/etc/bash_completion"

source_if_exists "$HOME/.bashrc"





