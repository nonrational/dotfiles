#!/bin/bash

# assume this in run in the .dotfiles checkout
DOTS="$PWD"

force_delete=0

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

    if [ ! -f $src ]; then
        echo "[error] $src does not exist!"
        return
    fi

    trg=""
    if [ "$2" == "" ]; then
        trg=$HOME/$file
    else
        trg=$2
    fi

    if [ -f $trg ]; then
        if [ $force_delete == 1 ]; then
            rm -rvi $trg
            ln -sv $src $trg
        else
            echo "[error] unable to push $src; $trg exists."
        fi
    else
        mkdir -p "`dirname $trg`"
        ln -fsv $src $trg
    fi
}

linky .bash_profile
linky .bashrc
linky .profile
linky .gitconfig
linky .githelpers
linky .gitignore_global
linky .inputrc
linky .nethackrc
linky .screenrc
linky .ssh.config ~/.ssh/config
linky .vim
linky .viminfo
linky .vimrc

if [ "$osenv" == "Darwin" ]; then
    echo "Linking OS X Addons"
    # linky Sublime\ Text\ 2 /Users/norton/Library/Application\ Support/
elif [ "$osenv" == "Linux" ]; then
    echo "Linking Linux Addons"
fi
