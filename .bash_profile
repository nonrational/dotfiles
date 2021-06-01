# osx sources this on every new Terminal.app tab/window but NOT on new bash's
# so, screen will *not* source this on new screen creation (ctrl+a,c)

export BASH_SILENCE_DEPRECATION_WARNING=1

[[ -s $HOME/.bashrc ]] && . $HOME/.bashrc
[[ -s $HOME/src/parallelize/env ]] && . $HOME/src/parallelize/env

if [ -d /usr/local/flutter.git ]; then
  export PATH="$PATH:/usr/local/flutter.git/bin"
fi

export PATH="./bin:$HOME/bin:$HOME/.local/bin:/usr/local/sbin:$PATH"

