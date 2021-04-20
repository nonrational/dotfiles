# sourced on new screens, non-login shells.
# echo sourcing .bashrc
host=`uname -n | sed -e 's/\.local//g'`;
my_uname=`uname`;

if [ "$my_uname" == "Darwin" ]; then
    brewery=`brew --prefix`

    [[ -s "$brewery/etc/profile.d/autojump.sh" ]] && . "$brewery/etc/profile.d/autojump.sh"
    [[ -s "$brewery/opt/asdf/asdf.sh" ]] && . "$brewery/opt/asdf/asdf.sh"

    # if we're running bash, source homebrew bash completion
    if [[ "$BASH_VERSINFO" -gt 0 ]]; then
      [[ -s "$brewery/etc/bash_completion" ]] && . "$brewery/etc/bash_completion"
    fi

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

elif [ "$my_uname" == "Linux" ]; then
    # use GNU ls with --color
    alias ls='ls --color -F'

    export EDITNOW='vim'
    export EDITOR='vim'

    [[ -s /usr/share/autojump/autojump.sh ]] && . /usr/share/autojump/autojump.sh
    [[ -s ~/.bash_aliases ]] && . ~/.bash_aliases;
    if [[ -s /etc/bash_completion ]] && ! shopt -oq posix; then
        . /etc/bash_completion;
    fi
fi

export CLICOLOR=1
export TERM=xterm-color
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

parse_git_branch() {
    git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
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

uber_prompt() {
    local        BLUE="\[\033[0;34m\]"
    local      YELLOW="\[\033[0;33m\]"
    local         RED="\[\033[0;31m\]"
    local   LIGHT_RED="\[\033[1;31m\]"
    local       GREEN="\[\033[0;32m\]"
    local LIGHT_GREEN="\[\033[1;32m\]"
    local       WHITE="\[\033[1;37m\]"
    local  LIGHT_GRAY="\[\033[0;37m\]"
    PS1="$LIGHT_GRAY$*$GREEN\$(parse_git_branch)$LIGHT_GRAY\$ "
    PS2='> '
    PS4='+ '
}

myself="`whoami`"
linux_prompt="[\u@\h \W]"
darwin_prompt="\u@\h:\W"
me_prompt="\h:\W"

if [ "$my_uname" == "Darwin" ]; then
    if [ "$myself" == 'norton' -o "$myself" == 'anorton' ]; then
        uber_prompt $me_prompt;
    else
        uber_prompt $darwin_prompt;
    fi
else
    uber_prompt $linux_prompt
fi

# if there are settings for a particular machine, put them in .local.bashrc
# i.e. PS1="[\u@\h \W]\$ "
[[ -s "$HOME/.local/.bashrc" ]] && . "$HOME/.local/.bashrc"

# set +x
# exec 2>&3 3>&-
