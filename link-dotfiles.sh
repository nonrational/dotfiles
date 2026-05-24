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

_show_diff(){
    local a="$1" b="$2"
    if command -v git >/dev/null 2>&1; then
        git diff --no-index -- "$a" "$b" 2>/dev/null || return 1
    else
        diff -u "$a" "$b" || return 1
    fi
}

_merge(){
    local src="$1" trg="$2"
    echo "  left=$trg (current)  right=$src (dotfiles)"
    if [ -n "${MERGE_TOOL:-}" ]; then
        $MERGE_TOOL "$trg" "$src"
    elif command -v nvim >/dev/null 2>&1; then
        nvim -d "$trg" "$src"
    elif command -v vimdiff >/dev/null 2>&1; then
        vimdiff "$trg" "$src"
    else
        echo "[error] no merge tool found; set MERGE_TOOL"
        echo "[skip] $trg"
        return
    fi
    printf "  symlink now? (y/n) "
    read -r yn
    case "$yn" in
        y|Y) mv "$trg" "$trg.bak"; echo "[backup] $trg.bak"; ln -sv "$src" "$trg" ;;
        *)   echo "[skip] $trg" ;;
    esac
}

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
            if _show_diff "$trg" "$src"; then
                echo "  files are identical — symlinking"
                rm -f "$trg"
                ln -sv "$src" "$trg"
                return
            fi
            if [ -t 0 ]; then
                printf "  (b)ackup, (m)erge, (o)verwrite, (s)kip, (q)uit? "
                read -r choice
            else
                choice=s
                echo "  non-interactive: skipping"
            fi
            case "$choice" in
                b|B) mv "$trg" "$trg.bak"; echo "[backup] $trg.bak"; ln -sv "$src" "$trg" ;;
                m|M) _merge "$src" "$trg" ;;
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
