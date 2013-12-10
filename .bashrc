# sourced on new screens, non-login shells.
# echo sourcing .bashrc
host=`uname -n | sed -e 's/\.local//g'`;
uname=`uname`;

if [ "$uname" == "Darwin" ]; then
    [[ -s "/opt/boxen/env.sh" ]] && source "/opt/boxen/env.sh"

    brewery=`brew --prefix`
    [[ -s $brewery/etc/autojump.sh ]]     && . $brewery/etc/autojump.sh
    [[ -s $brewery/etc/bash_completion ]] && . $brewery/etc/bash_completion

    # export RBENV_ROOT="$brewery/var/rbenv"
    # if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

    export EDITNOW='subl'
    export EDITOR='subl -w'
    export LESS="$LESS -i -F -R -X"
    export HISTCONTROL=ignoredups

    export JAVA_HOME=/Library/Java/Home

    # preview man
    pman() {
        man -t "${1}" | open -f -a /Applications/Preview.app/
    }

    alias jj='autojump'
    # use BSD ls with no --color
    alias ls='ls -F'
    alias top='top -o cpu'
    alias opena="open -n -a"
    alias crontab="EDITOR=vi VIM_CRONTAB=true crontab"
    [[ "`which gfind`" ]] && alias find="gfind"
    [[ "`which gsleep`" ]] && alias sleep="gsleep"

    [[ "`which aws`" ]] && complete -C aws_completer aws


elif [ "$uname" == "Linux" ]; then

    # use GNU ls with --color
    alias ls='ls --color -F'
    alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

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
export HISTCONTROL="ignoredups"
export HISTIGNORE="[   ]*:&:bg:fg:exit"

# do close spelling matches with cd
shopt -s cdspell
shopt -s histappend
shopt -s nocaseglob
shopt -s checkwinsize

# handy aliases
alias ll='ls -l'
alias la='ls -hlA'
alias l='ls'
alias df='df -h'
alias du='du -h'
alias grep="grep --color"
alias become="sudo su -"

alias hosts='sudo $EDITNOW /etc/hosts'
alias pjs='sudo jps -mlvV | grep -v "Bootstrap\|Jps\|\/opt\/dell\/srvadmin"'

# fun aliases
alias wtc='curl -s "http://whatthecommit.com" | grep "<p>" | cut -c4-'
alias scg='curl -s http://www.madsci.org/cgi-bin/cgiwrap/~lynn/jardin/SCG | grep "<h2>" -A4 | tr "\n" " " | sed -e "s/<h2>[ \t]*//" -e "s/\<.*$//g"'
alias prpg="LC_CTYPE=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | fold -w 18 | head -n1"
alias hex32="LC_CTYPE=C tr -dc 'A-F0-9' < /dev/urandom | fold -w 32 | head -n1"

#aliases for my local stuff
alias ddate="date '+%Y%m%d%'"
alias mdate="date '+%Y-%m-%d%'"
alias cdate="date '+%Y%m%d%H%M%S'"


parse_git_branch() {
    git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
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

if [ "$uname" == "Darwin" ]; then
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
[[ -s $HOME/.local.bashrc ]]  && . $HOME/.local.bashrc
[[ -s $HOME/.local/.bashrc ]] && . $HOME/.local/.bashrc
