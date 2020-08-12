#!/bin/bash

force_delete=0

DOTS="$PWD"
uname="$(uname)"

while [ $# -gt 0 ]
do
    case "$1" in
    (-f) force_delete=1; shift;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*)  break;;
    esac
    shift
done

if [ ! -d "$DOTS" ]; then
    echo "$DOTS does not exist! Aborting..."
    exit 1
fi

symlink(){
    file="$1"
    src="$DOTS/$file"

    if [ ! -e "$src" ]; then
        echo "[error] $src does not exist!"
        return
    fi

    trg=""
    if [ "$2" == "" ]; then
        trg="$HOME/$file"
    else
        trg="$2"
    fi

    if [ -e "$trg" ]; then
        if [ $force_delete == 1 ]; then
            rm -rf "$trg"
            ln -sv "$src" "$trg"
        else
            echo "[error] unable to symlink $src; $trg exists."
        fi
    else
        mkdir -p "$(dirname "$trg")"
        ln -fsv "$src" "$trg"
    fi
}

exclusion_patterns=(".git" ".gitignore" ".github" ".DS_Store" "." ".." ".AppleDouble");
exclusion_list=${exclusion_patterns[@]};

should_symlink() {
    for e in $exclusion_list; do [[ "$e" == "$1" ]] && echo "1"; done
    echo "0"
}

# Anything that starts with a dot should be linked as is.
STANDARD_DOT_FILES=( "$DOTS/.*" )
for dot_file_path in $STANDARD_DOT_FILES; do
    dot_file_basename=$(basename "$dot_file_path");
    [[ "$(should_symlink "$dot_file_basename")" == "0" ]] && symlink "$dot_file_basename"
done

# special cases - these don't start with a dot
symlink "bin.$uname" ~/bin
