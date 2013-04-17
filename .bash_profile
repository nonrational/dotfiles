# osx sources this on every new Terminal.app tab/window but NOT on new bash's
# so, screen will *not* source this on new screen creation (ctrl+a,c)

[[ -s $HOME/.bashrc ]] && . $HOME/.bashrc

export PATH=$PATH$(find $HOME/bin -type d -exec echo -n ':{}' \;)

# these machines use macports, so source the hardcoded stuff for them
if [ "$host" == "asterix" -o "$host" == "hypnos" ]; then
    export PATH=/opt/local/bin:/opt/local/sbin:/usr/local/bin:/usr/local/sbin:/usr/local/mysql/bin:$PATH
    export PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
    if [ -e $HOME/pear/bin ]; then
        export PATH=$PATH:$HOME/pear/bin
    fi
fi

# for osx, make sure that we show the ~/Library
if [ "$osenv" == "Darwin" ]; then
    # if running on Lion, unhides the ~/Library folder in Finder
    osx_version=$(sw_vers |awk '/ProductVersion/ {print $2}' |sed 's/\([0-9]*\.[0-9]*\)\.[0-9]*/\1/')
    if which sw_vers >/dev/null 2>&1 && [[ "$osx_version" == '10.7' || "$osx_version" == '10.8' ]] && which chflags >/dev/null 2>&1; then
        chflags nohidden ~/Library
    fi
fi


