# osx sources this on every new Terminal.app tab/window but NOT on new bash's
# so, screen will *not* source this on new screen creation (ctrl+a,c)

export BASH_SILENCE_DEPRECATION_WARNING=1

[[ -s $HOME/.bashrc ]] && . $HOME/.bashrc
[[ -s $HOME/src/parallelize/env ]] && . $HOME/src/parallelize/env

if command -v goenv > /dev/null; then
  # https://github.com/syndbg/goenv/issues/30
  export GOBIN_PATH="$HOME/go/$(goenv version-name)"
  export PATH="$GOBIN_PATH/bin:$PATH"
fi

if [ -d /usr/local/flutter.git ]; then
  export PATH="$PATH:/usr/local/flutter.git/bin"
fi

export PATH="$HOME/.jenv/bin:$PATH"
export PATH="./bin:$HOME/bin:$PATH"


