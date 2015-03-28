#!/bin/bash

force_delete=0
apply_root=0

DOTS="$PWD"
uname="`uname`"
host="`uname -n | sed -e 's/\.local//g'`";

# make some options require arguments
# set -- $(getopt d: "$@")

while [ $# -gt 0 ]
do
    case "$1" in
    (-f) force_delete=1; shift;;
    (-r) apply_root=1; shift;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*)  break;;
    esac
    shift
done

if [ ! -d $DOTS ]; then
    echo "$DOTS does not exist! Aborting..."
    exit 1
fi

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

exclusion_patterns=(".git" ".gitignore" ".DS_Store" "." ".." ".AppleDouble");
exclusion_list="${exclusion_patterns[@]}";

should_copy() {
    for e in $exclusion_list; do [[ "$e" == "$1" ]] && echo 1; done
    echo 0
}

# Anything that starts with a dot should be linked as is.
STANDARD_DOT_FILES=$DOTS/.*
for sdf in $STANDARD_DOT_FILES; do
    bnf=`basename $sdf`;
    if [[ `should_copy $bnf` == 0 ]]; then
        linky $bnf
    fi
done

# special cases - these don't start with a dot
linky "bin.$uname" ~/bin

# root configurations
if [[ $apply_root == 1 ]]; then
    sudo ln -sfv $DOTS/root.profile /var/root/.profile
fi

# if [ "$uname" == "Darwin" ]; then
#     echo "Linking OS X Specific Addons ... ";
# elif [ "$uname" == "Linux" ]; then
#     echo "Linking Linux Specific Addons ... "
# fi
