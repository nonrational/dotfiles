# osx sources this on every new Terminal.app tab/window but NOT on new bash's
# so, screen will *not* source this on new screen creation (ctrl+a,c)

[[ -s $HOME/.bashrc ]] && . $HOME/.bashrc

if [[ -d $HOME/bin ]]; then
    for bindir in `find $HOME/bin/ -maxdepth 1 -type d | sort -r`; do
        export PATH=${bindir%/}:$PATH
    done
fi

[[ -d "/usr/local/heroku/bin" ]] && export PATH="$PATH:/usr/local/heroku/bin"
[[ -d "/usr/local/share/npm/bin/" ]] && export PATH="$PATH:/usr/local/share/npm/bin/"
[[ -d "$GOPATH" ]] && export PATH="$GOPATH/bin:$PATH"
export PATH=$PATH:/Users/norton/Library/Android/sdk/platform-tools/
