#!/bin/bash
set -euf -o pipefail

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

symlink(){
    file="$1"
    src="$DOTS/$file"
    trg="${2-"$HOME/$file"}"

    if [ ! -e "$src" ]; then
        echo "[error] $src does not exist!"
        return
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

dot_files=$(
    find . -maxdepth 1 -name '.*' \
        ! -name '.' \
        ! -name '.AppleDouble' \
        ! -name '.DS_Store' \
        ! -name '.git' \
        ! -name '.github' \
        ! -name '.gitignore'
)

# Anything that starts with a dot should be linked as is.
for dotfile in $dot_files; do
    symlink "$(basename "$dotfile")"
done

# special cases - these don't start with a dot
symlink "bin.$uname" $HOME/bin
