# sourced on new screens, non-login shells.

host=`uname -n | sed -e 's/\.lan$//g' -e 's/\.local$//g'`;
platform=`uname`;

export HISTIGNORE="[   ]*:&:bg:fg:exit"
export HISTCONTROL=ignoredups:erasedups  # no duplicate entries
export HISTSIZE=100000                   # big big history
export HISTFILESIZE=100000               # big big history
shopt -s histappend                      # append to history, don't overwrite it

# Save and reload the history after each command finishes
export PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

# do close spelling matches with cd
shopt -s cdspell
shopt -s nocaseglob
shopt -s checkwinsize

# handy aliases
alias ll='ls -l'
alias la='ls -hlA'
alias l='ls'
alias rm='rm -v'
alias df='df -h'
alias du='du -h'
alias grep="grep --color"
alias hist="history|tail"
alias psa="ps auxwww"
alias cdate="date '+%Y%m%d%H%M%S'"

# psuedo-random, insecure password generator
prpg() {
  echo -n $RANDOM | openssl sha1 -binary | base64 | tr -d '/+='
}

reset_known_host() {
  if [ "$1" != "" ]; then
    grep -v "$1" $HOME/.ssh/known_hosts > $HOME/.ssh/known_hosts.tmp
    mv -v $HOME/.ssh/known_hosts.tmp $HOME/.ssh/known_hosts
  else
    echo "No pattern provided"
  fi
}

source_if_exists() {
  [[ -s "$1" ]] && source "$1"
}

source_if_exists "$HOME/.bashrc.${platform}"
source_if_exists "$HOME/.bashrc.${host}"
source_if_exists "$HOME/.local/.bashrc"
