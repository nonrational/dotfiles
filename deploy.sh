#!/bin/bash
# Manifest-driven deploy: apply/audit symlinks declared in ./manifest.
# Spec: docs/superpowers/specs/2026-07-06-manifest-deploy-spike-design.md
set -euf -o pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$DOTS/manifest"

dry_run=0
mode=apply

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        apply | audit) mode="$1" ;;
        *)
            echo "usage: $0 [--dry-run] [apply|audit]" >&2
            exit 2
            ;;
    esac
    shift
done

sources=()
targets=()
conditions=()

parse_manifest() {
    local lineno=0 line src trg cond extra
    if [ ! -f "$MANIFEST" ]; then
        echo "error: manifest not found at $MANIFEST" >&2
        exit 1
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        line="${line%%#*}"
        if [ -z "${line//[[:space:]]/}" ]; then
            continue
        fi
        read -r src trg cond extra <<<"$line"
        if [ -z "$trg" ] || [ -n "$extra" ]; then
            echo "error: manifest line $lineno: expected 2 or 3 columns" >&2
            exit 1
        fi
        case "$cond" in
            "" | os=?* | host=?*) ;;
            *)
                echo "error: manifest line $lineno: unknown condition '$cond'" >&2
                exit 1
                ;;
        esac
        if [ ! -e "$DOTS/$src" ]; then
            echo "error: manifest line $lineno: source $DOTS/$src does not exist" >&2
            exit 1
        fi
        sources+=("$src")
        targets+=("$trg")
        conditions+=("$cond")
    done <"$MANIFEST"
    if [ "${#sources[@]}" -eq 0 ]; then
        echo "error: manifest has no entries" >&2
        exit 1
    fi
}

os="$(uname)"
host="$(uname -n | sed -e 's/\.lan$//g' -e 's/\.local$//g')"
failures=0

condition_matches() {
    case "$1" in
        "") return 0 ;;
        os=*) [ "${1#os=}" = "$os" ] ;;
        host=*) [ "${1#host=}" = "$host" ] ;;
    esac
}

expand_target() {
    case "$1" in
        "~/"*) printf '%s\n' "$HOME/${1#\~/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

apply_entry() {
    local src="$1" trg="$2" prefix=""
    if [ "$dry_run" = 1 ]; then
        prefix="would: "
    fi
    if [ -L "$trg" ] && [ "$(readlink "$trg")" = "$src" ]; then
        echo "ok: $trg -> $src"
    elif [ -L "$trg" ]; then
        echo "${prefix}relink: $trg -> $src (was $(readlink "$trg"))"
        if [ "$dry_run" = 0 ]; then
            rm "$trg"
            ln -s "$src" "$trg"
        fi
    elif [ -e "$trg" ]; then
        if [ -e "$trg.bak" ] || [ -L "$trg.bak" ]; then
            echo "error: $trg.bak already exists; skipping $trg" >&2
            failures=$((failures + 1))
        else
            echo "${prefix}backup: $trg -> $trg.bak, link $trg -> $src"
            if [ "$dry_run" = 0 ]; then
                mv "$trg" "$trg.bak"
                ln -s "$src" "$trg"
            fi
        fi
    else
        echo "${prefix}link: $trg -> $src"
        if [ "$dry_run" = 0 ]; then
            mkdir -p "$(dirname "$trg")"
            ln -s "$src" "$trg"
        fi
    fi
}

audit_entry() {
    local src="$1" trg="$2"
    if [ -L "$trg" ] && [ "$(readlink "$trg")" = "$src" ]; then
        echo "ok: $trg"
    elif [ -e "$trg" ] || [ -L "$trg" ]; then
        echo "drift: $trg is not a symlink to $src"
        failures=$((failures + 1))
    else
        echo "missing: $trg"
        failures=$((failures + 1))
    fi
}

main() {
    local i src trg cond
    parse_manifest
    i=0
    while [ "$i" -lt "${#sources[@]}" ]; do
        src="$DOTS/${sources[$i]}"
        trg="$(expand_target "${targets[$i]}")"
        cond="${conditions[$i]}"
        if condition_matches "$cond"; then
            case "$mode" in
                apply) apply_entry "$src" "$trg" ;;
                audit) audit_entry "$src" "$trg" ;;
            esac
        else
            echo "skip: ${targets[$i]} ($cond)"
        fi
        i=$((i + 1))
    done
    if [ "$failures" -gt 0 ]; then
        exit 1
    fi
}

main
