# osx sources this on every new Terminal.app tab/window but NOT on new bash's
# so, screen will *not* source this on new screen creation (ctrl+a,c)

[[ -s $HOME/.bashrc ]] && . $HOME/.bashrc
[[ -d $HOME/bin ]] && export PATH=$HOME/bin:$PATH
[[ -d $JAVA_HOME/bin ]] && export PATH=$JAVA_HOME/bin:$PATH
[[ -d "/usr/local/heroku/bin" ]] && export PATH="$PATH:/usr/local/heroku/bin"
