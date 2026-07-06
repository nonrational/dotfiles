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

parse_manifest
