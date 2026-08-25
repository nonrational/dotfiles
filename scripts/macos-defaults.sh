#!/bin/bash
# Declarative macOS defaults: check/audit/apply/accept the table in ./macos-defaults.
# Spec: docs/superpowers/specs/2026-08-25-macos-defaults-declarative-design.md
set -euf -o pipefail

DOTS="$(cd "$(dirname "$0")/.." && pwd)"
# Overridable so the test suite can point at a sandboxed table.
TABLE="${MACOS_DEFAULTS_TABLE:-$DOTS/macos-defaults}"
TAB=$'\t'

dry_run=0
mode=audit
filter_domain=""
filter_key=""
failures=0

usage() {
    echo "usage: $0 [--dry-run] [check|audit|apply|accept] [domain [key]]" >&2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            dry_run=1
            shift
            ;;
        check | audit | apply | accept)
            mode="$1"
            shift
            filter_domain="${1:-}"
            if [ $# -gt 0 ]; then shift; fi
            filter_key="${1:-}"
            if [ $# -gt 0 ]; then shift; fi
            if [ $# -gt 0 ]; then
                usage
                exit 2
            fi
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

t_domain=()
t_key=()
t_type=()
t_value=()
t_status=()

# Splits on tabs into the global ROW, preserving empty fields. `IFS=$'\t' read`
# cannot be used here: bash classes tab as IFS whitespace, so it collapses runs
# of tabs and drops a leading one, shifting every field left without an error.
split_row() {
    local rest="$1"
    ROW=()
    while :; do
        case "$rest" in
            *"$TAB"*)
                ROW+=("${rest%%"$TAB"*}")
                rest="${rest#*"$TAB"}"
                ;;
            *)
                ROW+=("$rest")
                break
                ;;
        esac
    done
}

parse_table() {
    local lineno=0 line trimmed status i
    if [ ! -f "$TABLE" ]; then
        echo "error: table not found at $TABLE" >&2
        exit 1
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        trimmed="${line#"${line%%[![:space:]]*}"}"
        case "$trimmed" in
            "" | "#"*) continue ;;
        esac
        split_row "$line"
        if [ "${#ROW[@]}" -lt 4 ] || [ "${#ROW[@]}" -gt 5 ]; then
            echo "error: $TABLE line $lineno: expected 4 or 5 tab-separated columns, got ${#ROW[@]}" >&2
            exit 1
        fi
        i=0
        while [ "$i" -lt 4 ]; do
            if [ -z "${ROW[$i]}" ]; then
                echo "error: $TABLE line $lineno: column $((i + 1)) is empty" >&2
                exit 1
            fi
            i=$((i + 1))
        done
        status=""
        if [ "${#ROW[@]}" = 5 ]; then
            status="${ROW[4]}"
            if [ -z "$status" ]; then
                echo "error: $TABLE line $lineno: status column is empty; omit it instead" >&2
                exit 1
            fi
        fi
        case "${ROW[2]}" in
            bool | int | float | string | raw) ;;
            array | dict | dict-add | date | data)
                case "$status" in
                    noaudit=*) ;;
                    *)
                        echo "error: $TABLE line $lineno: type '${ROW[2]}' cannot be compared; it needs a noaudit= status" >&2
                        exit 1
                        ;;
                esac
                ;;
            *)
                echo "error: $TABLE line $lineno: unknown type '${ROW[2]}'" >&2
                exit 1
                ;;
        esac
        case "$status" in
            "" | noaudit=tcc | noaudit=unset | noaudit=complex | os=?* | host=?*) ;;
            *)
                echo "error: $TABLE line $lineno: unknown status '$status'" >&2
                exit 1
                ;;
        esac
        t_domain+=("${ROW[0]}")
        t_key+=("${ROW[1]}")
        t_type+=("${ROW[2]}")
        t_value+=("${ROW[3]}")
        t_status+=("$status")
    done <"$TABLE"
    if [ "${#t_domain[@]}" -eq 0 ]; then
        echo "error: $TABLE has no rows" >&2
        exit 1
    fi
}

row_selected() {
    local i="$1"
    if [ -n "$filter_domain" ] && [ "${t_domain[$i]}" != "$filter_domain" ]; then
        return 1
    fi
    if [ -n "$filter_key" ] && [ "${t_key[$i]}" != "$filter_key" ]; then
        return 1
    fi
    return 0
}

main() {
    local i n
    parse_table
    n="${#t_domain[@]}"
    if [ "$mode" = check ]; then
        if [ "$n" = 1 ]; then
            echo "ok: 1 row in $TABLE"
        else
            echo "ok: $n rows in $TABLE"
        fi
        return 0
    fi
    i=0
    while [ "$i" -lt "$n" ]; do
        if row_selected "$i"; then
            case "$mode" in
                audit) audit_row "$i" ;;
                apply) apply_row "$i" ;;
            esac
        fi
        i=$((i + 1))
    done
    if [ "$failures" -gt 0 ]; then
        exit 1
    fi
}

main
