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
    echo "  Merging $trg (current) and $src (dotfiles)..."

    # Determine editor
    local editor="${EDITOR:-}"
    if [ -z "$editor" ]; then
        if command -v nvim >/dev/null 2>&1; then
            editor="nvim"
        elif command -v vim >/dev/null 2>&1; then
            editor="vim"
        elif command -v vi >/dev/null 2>&1; then
            editor="vi"
        elif command -v nano >/dev/null 2>&1; then
            editor="nano"
        else
            echo "  [error] no EDITOR set and no standard editor (nvim/vim/vi/nano) found."
            echo "  [skip] $trg"
            return
        fi
    fi

    # Create temporary file for editing
    local tmp_merge
    tmp_merge=$(mktemp "${TMPDIR:-/tmp}/link-dotfiles-merge.XXXXXX")

    # Generate conflict markers
    if command -v git >/dev/null 2>&1; then
        git merge-file -p -L "CURRENT ($trg)" -L "BASE" -L "DOTFILES ($src)" "$trg" /dev/null "$src" > "$tmp_merge" || true
    else
        # Fallback if git is not available
        if command -v diff3 >/dev/null 2>&1; then
            diff3 -m -L "CURRENT ($trg)" -L "BASE" -L "DOTFILES ($src)" "$trg" /dev/null "$src" > "$tmp_merge" || true
        else
            # Simple fallback: concatenate them with markers
            {
                echo "<<<<<<< CURRENT ($trg)"
                cat "$trg"
                echo "======="
                cat "$src"
                echo ">>>>>>> DOTFILES ($src)"
            } > "$tmp_merge"
        fi
    fi

    # Open in EDITOR
    eval "$editor \"\$tmp_merge\""

    if grep -qE "^(<<<<<<<|=======|>>>>>>>)" "$tmp_merge"; then
        echo "  [warn] Merge markers still found in the file!"
    fi

    printf "  Apply merge changes? (y/n) "
    read -r yn
    case "$yn" in
        y|Y)
            cp "$tmp_merge" "$src"
            mv "$trg" "$trg.bak"
            echo "  [backup] $trg.bak"
            ln -sv "$src" "$trg"
            ;;
        *)
            echo "  [skip] $trg"
            ;;
    esac

    rm -f "$tmp_merge"
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
