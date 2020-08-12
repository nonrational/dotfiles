# set -x
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats ' %b'

setopt PROMPT_SUBST
export PROMPT='%(?.%F{green}√.%F{red}?%?)%f %B%F{240}%1~%f%b%F{green}${vcs_info_msg_0_}%f %# '

setopt NO_CASE_GLOB
setopt AUTO_CD

HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
setopt EXTENDED_HISTORY
SAVEHIST=5000
HISTSIZE=2000
# share history across multiple zsh sessions
setopt SHARE_HISTORY
# append to history
setopt APPEND_HISTORY
# adds commands as they are typed, not at shell exit
setopt INC_APPEND_HISTORY
# expire duplicates first
setopt HIST_EXPIRE_DUPS_FIRST
# do not store duplications
setopt HIST_IGNORE_DUPS
#ignore duplicates when searching
setopt HIST_FIND_NO_DUPS
# removes blank lines from history
setopt HIST_REDUCE_BLANKS

setopt CORRECT
setopt CORRECT_ALL

export EDITNOW='subl'
export EDITOR='subl -w'
export LESS="$LESS -i -F -R -X"

alias ls="/bin/ls -F"
alias respec="rspec --only-failures"

# allow PUMA_DEV_BIN="./puma-dev" for installing dev versions
export PUMA_DEV_BIN='puma-dev'
alias puma-dev-setup="sudo $PUMA_DEV_BIN -d test:localhost:loc.al -setup"
alias puma-dev-install="$PUMA_DEV_BIN -d test:localhost:loc.al -install"
alias puma-dev-uninstall="$PUMA_DEV_BIN -uninstall -d test:localhost:loc.al"

alias vboxup='VBoxManage list runningvms | grep ubuntu-18.04 || VBoxManage startvm ubuntu-18.04 --type headless'

function puma-dev-ln () {
  echo ln -sf $1 "~/.puma-dev/$(basename $1)"
  echo ln -sf $1 "~/.puma-dev/$(basename $1).loc"
}

alias git='hub'
alias ls='ls -F'
alias ll='ls -l'
alias l='ls'

host=$(uname -n | sed -e 's/\.local//g')

brewery=$(brew --prefix)

# autojump
. "$brewery/etc/profile.d/autojump.sh"

# asdf
brew_prefix_asdf="$brewery/opt/asdf"
export ASDF_DIR="$brew_prefix_asdf"
. "$brew_prefix_asdf/asdf.sh"

# To make Homebrew’s completions available in zsh, you must get the Homebrew-managed zsh site-functions on your FPATH
# before initialising zsh’s completion facility.
# Add the following to your ~/.zshrc file:
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH

  autoload -Uz compinit
  compinit
fi

export PATH="/usr/local/opt/sqlite/bin:$PATH"
