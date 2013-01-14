#!/bin/bash

# assume this in run in the .dotfiles checkout
DOTS="$HOME/.dotfiles"
if [ "$1" != "" ]; then
    DOTS="$1"
fi

if [ ! -d $DOTS ]; then
    echo "$DOTS does not exist! Aborting..."
    exit 1
fi

force_delete=0

uname="`uname`"
host="`uname -n | sed -e 's/\.local//g'`";

# make some options require arguments
# set -- $(getopt abf: "$@")

while [ $# -gt 0 ]
do
    case "$1" in
    (-f) force_delete=1; shift;;
    (--) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*)  break;;
    esac
    shift
done

linky(){
    file=$1
    src="$DOTS/$file"

    if [ ! -e "$src" ]; then
        echo "[error] $src does not exist!"
        return
    fi

    trg=""
    if [ "$2" == "" ]; then
        trg=$HOME/$file
    else
        trg=$2
    fi

    if [ -e "$trg" ]; then
        if [ $force_delete == 1 ]; then
            rm -rf $trg
            ln -sv $src $trg
        else
            echo "[error] unable to push $src; $trg exists."
        fi
    else
        mkdir -p "`dirname $trg`"
        ln -fsv $src $trg
    fi
}

# Anything that starts with a dot should be linked as is.
STANDARD_DOT_FILES=$DOTS/.*
for sdf in $STANDARD_DOT_FILES; do
    linky `basename $sdf`
done

# special cases - these don't start with a dot
linky .ssh.config ~/.ssh/config
linky "bin.$uname" ~/bin

if [ "$uname" == "Darwin" ]; then
    echo "Linking OS X Specific Addons ... ";
    ln -sfv $DOTS/Sublime\ Text\ 2 ${HOME}/Library/Application\ Support
elif [ "$uname" == "Linux" ]; then
    echo "Linking Linux Specific Addons ... "
fi
