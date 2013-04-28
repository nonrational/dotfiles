# osx sources this on every new Terminal.app tab/window but NOT on new bash's
# so, screen will *not* source this on new screen creation (ctrl+a,c)

[[ -s $HOME/.bashrc ]] && . $HOME/.bashrc
[[ -d $HOME/bin ]] && export PATH=$HOME/bin:$PATH
[[ -d $JAVA_HOME/bin ]] && export PATH=$JAVA_HOME/bin:$PATH
[[ -d "/usr/local/heroku/bin" ]] && export PATH="$PATH:/usr/local/heroku/bin"

# these machines use macports, so source the hardcoded stuff for them
if [ "$host" == "asterix" -o "$host" == "hypnos" ]; then
    export PATH=/opt/local/bin:/opt/local/sbin:/usr/local/bin:/usr/local/sbin:/usr/local/mysql/bin:$PATH
    export PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
    if [ -e $HOME/pear/bin ]; then
        export PATH=$PATH:$HOME/pear/bin
    fi
fi

# Turn ~/.ssh/known_hosts into a treasure trove of auto-completion goodness
complete -W "$(echo `cat ~/.ssh/known_hosts | cut -f 1 -d ' ' | sed -e s/,.*//g | uniq | grep -v "\["`;)" ssh
