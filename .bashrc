# sourced on new screens, non-login shells.
# echo sourcing .bashrc

host=`uname -n | sed -e 's/\.lan$//g' -e 's/\.local$//g'`;
platform=`uname`;

export HISTIGNORE="[   ]*:&:bg:fg:exit"
export HISTCONTROL=ignoredups:erasedups  # no duplicate entries
export HISTSIZE=100000                   # big big history
export HISTFILESIZE=100000               # big big history
shopt -s histappend                      # append to history, don't overwrite it

# Save and reload the history after each command finishes
# export PROMPT_COMMAND="$PROMPT_COMMAND; \history -a;"

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

alias prpg="LC_CTYPE=C tr -dc 'A-Za-z0-9_-' < /dev/urandom | fold -w 16 | head -n1"

alias pry-watch='while clear && sleep 1; do pry-remote -w; done'

#aliases for my local stuff
alias ddate="date '+%Y%m%d%'"
alias cdate="date '+%Y%m%d%H%M%S'"

rpg(){
    size=${1:-12}; ruby -e "require 'securerandom'; puts SecureRandom.urlsafe_base64($size);"
}

git-rm-banch(){
    git branch -D $1 && git push origin :$1
}

basher(){
    env -i PATH=$PATH HOME=$HOME TERM=xterm-color "$(command -v bash)" --noprofile --norc
}

reset_known_host() {
    if [ "$1" != "" ]; then
        grep -v "$1" $HOME/.ssh/known_hosts > $HOME/.ssh/known_hosts.tmp
        mv -v $HOME/.ssh/known_hosts.tmp $HOME/.ssh/known_hosts
    else
        echo "No pattern provided"
    fi
}

# if there are settings for a particular machine, put them in .local.bashrc
# i.e. PS1="[\u@\h \W]\$ "
source_if_exists() {
  [[ -s "$1" ]] && source "$1"
}

source_if_exists "$HOME/.bashrc.${platform}"
source_if_exists "$HOME/.bashrc.${host}"
source_if_exists "$HOME/.local/.bashrc"

# set +x
# exec 2>&3 3>&-

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
