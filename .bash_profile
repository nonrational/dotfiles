# osx sources this on every new Terminal.app tab/window but NOT on new bash's
# so, screen will *not* source this on new screen creation (ctrl+a,c)

[[ -s $HOME/.bashrc ]] && . $HOME/.bashrc

if command -v goenv > /dev/null; then
  # https://github.com/syndbg/goenv/issues/30
  export GOBIN_PATH="$HOME/go/$(goenv version-name)"
  export PATH="$GOBIN_PATH/bin:$PATH"
fi

if [ -d /usr/local/flutter.git ]; then
  export PATH="$PATH:/usr/local/flutter.git/bin"
fi

export PATH="./bin:$HOME/bin:$PATH"
