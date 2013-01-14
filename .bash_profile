# osx sources this on every new Terminal.app tab/window but NOT on new bash's
# screen will not source this on new screen creation
# echo sourcing .bash_profile

# src .bashrc
if [ -f $HOME/.bashrc ]; then
    . $HOME/.bashrc
fi

MYPATHS=$(find $HOME/bin -type d -exec echo -n ':{}' \;)
export PATH=$PATH$MYPATHS

if [ "$host" == "asterix" ]; then
    export PATH=/opt/local/bin:/opt/local/sbin:/usr/local/bin:/usr/local/sbin:/usr/local/mysql/bin:$HOME/bin:$PATH
    export PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
    if [ -e $HOME/pear/bin ]; then
        export PATH=$PATH:$HOME/pear/bin
    fi
fi

if [ "$osenv" == "Darwin" ]; then
    # if running on Lion, unhides the ~/Library folder in Finder
    if which sw_vers >/dev/null 2>&1 && [[ $(sw_vers |awk '/ProductVersion/ {print $2}' |sed 's/\([0-9]*\.[0-9]*\)\.[0-9]*/\1/') == '10.7' ]] && which chflags >/dev/null 2>&1; then
        chflags nohidden ~/Library
    fi
fi


