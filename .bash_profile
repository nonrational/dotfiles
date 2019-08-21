# osx sources this on every new Terminal.app tab/window but NOT on new bash's
# so, screen will *not* source this on new screen creation (ctrl+a,c)

[[ -s $HOME/.bashrc ]] && . $HOME/.bashrc

[[ ! -z "$GOPATH" ]] && export PATH="$GOPATH/bin:$PATH"

export PATH="$HOME/bin:$PATH"
