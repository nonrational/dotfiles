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
        elif [ -L "$trg" ]; then
            rm -f "$trg"
            ln -sv "$src" "$trg"
        else
            echo "[warn] $trg exists and is not a symlink"
            if [ -t 0 ]; then
                printf "  (b)ackup, (o)verwrite, (s)kip, (q)uit? "
                read -r choice
            else
                choice=s
                echo "  non-interactive: skipping"
            fi
            case "$choice" in
                b|B) mv "$trg" "$trg.bak"; echo "[backup] $trg.bak"; ln -sv "$src" "$trg" ;;
                o|O) rm -rf "$trg"; ln -sv "$src" "$trg" ;;
                q|Q) echo "Aborted."; exit 0 ;;
                *)   echo "[skip] $trg" ;;
            esac
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
        ! -name '.gitignore' \
        ! -name '.gitmodules' \
        ! -name '.macos'
)

# Anything that starts with a dot should be linked as is.
for dotfile in $dot_files; do
    symlink "$(basename "$dotfile")"
done

# special cases - these don't start with a dot
symlink "bin.$uname" $HOME/bin
