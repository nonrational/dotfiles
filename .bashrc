# sourced on new screens, non-login shells.
# echo sourcing .bashrc
host=`uname -n | sed -e 's/\.local//g'`;
my_uname=`uname`;

# rm -f /tmp/bashstart.*.log
# PS4='+ $(date "+%s.%N")\011 '
# exec 3>&2 2>/tmp/bashstart.$$.log
# set -x

if [ "$my_uname" == "Darwin" ]; then
    brewery=`brew --prefix`

    [[ -s $brewery/etc/profile.d/autojump.sh ]] && . $brewery/etc/profile.d/autojump.sh

    if [[ "$0" == "-bash" ]]; then
      [[ -s "$brewery/etc/bash_completion" ]] && . "$brewery/etc/bash_completion"
    fi

    for lang in rb py go nod; do
      command -v "${lang}env" > /dev/null && eval "$(${lang}env init -)"
    done

    export EDITNOW='subl'
    export EDITOR='subl -w'
    export LESS="$LESS -i -F -R -X"

    [[ "`which gfind`" ]] && alias find="gfind"
    [[ "`which gsleep`" ]] && alias sleep="gsleep"
    [[ "`which aws`" ]] && complete -C aws_completer aws

    alias ls="/bin/ls -F"
    alias top='top -o cpu'
    alias opena="open -n -a"
    alias crontab="EDITOR=vi VIM_CRONTAB=true crontab"
    alias respec="rspec --only-failures"

    alias puma-dev-setup='sudo puma-dev -d test:localhost:loc.al -setup'
    alias puma-dev-install='puma-dev -d test:localhost:loc.al -install'
    alias puma-dev-uninstall='puma-dev -uninstall -d test:localhost:loc.al'

    function puma-dev-ln () {
        echo ln -sf $1 "~/.puma-dev/$(basename $1)"
        echo ln -sf $1 "~/.puma-dev/$(basename $1).loc"
    }

    alias git='hub'

elif [ "$my_uname" == "Linux" ]; then

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

alias hosts='sudo $EDITNOW /etc/hosts'

# fun aliases
alias wtc='curl -s "http://whatthecommit.com" | grep "<p>" | cut -c4-'

alias hex32="LC_CTYPE=C tr -dc 'A-F0-9' < /dev/urandom | fold -w 32 | head -n1"
alias prpg="LC_CTYPE=C tr -dc 'A-Za-z0-9_-' < /dev/urandom | fold -w 16 | head -n1"

alias nukelock="find -maxdepth 2 -name Gemfile.lock | xargs git checkout"
alias pry-watch='while clear && sleep 1; do pry-remote -w; done'

#aliases for my local stuff
alias ddate="date '+%Y%m%d%'"
alias mdate="date '+%Y-%m-%d%'"
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

rerake(){
    RAILS_ENV=test rake db:reset
    rake
}

uninstall-all-rbenv-gems-for-current-ruby-version() {
  list=`gem list --no-versions`
  for gem in $list; do
    gem uninstall $gem -aIx
  done
  gem list
  gem install bundler
}

function virtualenv_prompt() {
    local reset_color="\[\e[m\]"
    local magenta="\[\e[35m\]"
    local yellow="\[\e[33m\]"
    local green="\[\e[32m\]"

    if [ -n "$VIRTUAL_ENV" ]; then
        pyver=$(python -V 2>&1 | cut -f2 -d' ')
        echo "(${magenta}venv${reset_color}:${yellow}${VIRTUAL_ENV##*/}$reset_color|${green}${pyver}${reset_color}) "
    fi
}

export LIBTCOD_DLL_PATH="/usr/local/lib;/usr/lib;$HOME/.local/lib;$HOME/lib"

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
    PS1="$(virtualenv_prompt)${PS1}"
    PS2='> '
    PS4='+ '
}

figcom () {
    figlet "$@" | sed 's/^/# /g'
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
[[ -s $HOME/.local/.bashrc ]] && . $HOME/.local/.bashrc

# set +x
# exec 2>&3 3>&-
