#!/bin/bash
# One-shot: split .macos into the macos-defaults table (default) and the
# imperative lines that stay behind (--remainder). Committed so the 218-row
# transcription can be reviewed rather than trusted.
#
# Do not re-run this over the now-seeded table: .macos was retired down to its
# imperative remainder, so a fresh run has nothing left to parse into rows and
# would blank the table instead of regenerating it. It would also discard the
# seeding: four rows (AppleLocale, ActivityMonitor ShowCategory, and the two
# AppleMultitouchTrackpad click-threshold rows) were deliberately accepted
# with live values that differ from what .macos originally declared, and a
# fresh migration knows nothing of that decision.
set -euf -o pipefail

DOTS="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$DOTS/.macos"
TAB=$'\t'
HOME_TOKEN='${HOME}'
mode=table

if [ $# -gt 0 ]; then
    case "$1" in
        --remainder) mode=remainder ;;
        *)
            echo "usage: $0 [--remainder]" >&2
            exit 2
            ;;
    esac
fi

pending=()

flush_pending() {
    local p
    if [ "${#pending[@]}" -gt 0 ]; then
        for p in "${pending[@]}"; do
            printf '%s\n' "$p"
        done
    fi
    pending=()
}

quote_tail() {
    local out="" a
    for a in "$@"; do
        out="$out${out:+ }$(printf '%q' "$a")"
    done
    printf '%s' "$out"
}

# Absent from the live machine for two different reasons that need different
# markers: a whole domain that will not read is TCC, a readable domain missing
# one key is simply unset.
classify() {
    local domain="$1" key="$2" host_flag=""
    case "$domain" in
        currentHost:*)
            host_flag="-currentHost"
            domain="${domain#currentHost:}"
            ;;
    esac
    # `command` is required: this runs inside the `defaults` shim below, and a
    # bare call would re-enter it instead of reaching the binary.
    if command defaults $host_flag read "$domain" "$key" >/dev/null 2>&1; then
        printf ''
        return 0
    fi
    if command defaults $host_flag read "$domain" >/dev/null 2>&1; then
        printf 'noaudit=unset'
    else
        printf 'noaudit=tcc'
    fi
}

emit() {
    local host="$1" domain="$2" key="$3" type="$4" value="$5" status
    if [ "$mode" = remainder ]; then
        pending=()
        return 0
    fi
    if [ "$host" = currentHost ]; then
        domain="currentHost:$domain"
    fi
    # Continuation lines in .macos are tab-indented; a surviving tab would add a
    # phantom column.
    value="${value//$TAB/ }"
    # eval expanded ${HOME} while parsing, which would bake this machine's home
    # directory into a table meant to describe desired state rather than one Mac.
    value="${value//$HOME/$HOME_TOKEN}"
    # .macos writes at least one bool as YES; the table's convention is true/false.
    if [ "$type" = bool ]; then
        case "$value" in
            true | TRUE | True | YES | Yes | yes | 1) value=true ;;
            false | FALSE | False | NO | No | no | 0) value=false ;;
        esac
    fi
    case "$type" in
        array | dict | dict-add | date | data) status="noaudit=complex" ;;
        *) status="$(classify "$domain" "$key")" ;;
    esac
    flush_pending
    if [ -n "$status" ]; then
        printf '%s\n' "$domain$TAB$key$TAB$type$TAB$value$TAB$status"
    else
        printf '%s\n' "$domain$TAB$key$TAB$type$TAB$value"
    fi
}

defaults() {
    local host=""
    if [ "$1" = "-currentHost" ]; then
        host=currentHost
        shift
    fi
    if [ "$1" != write ]; then
        return 0
    fi
    shift
    local domain="$1" key="$2"
    shift 2
    case "$1" in
        -bool | -boolean) emit "$host" "$domain" "$key" bool "$2" ;;
        -int | -integer) emit "$host" "$domain" "$key" int "$2" ;;
        -float) emit "$host" "$domain" "$key" float "$2" ;;
        -string) emit "$host" "$domain" "$key" string "$2" ;;
        -date) emit "$host" "$domain" "$key" date "$2" ;;
        -data) emit "$host" "$domain" "$key" data "$2" ;;
        -array | -array-add)
            shift
            emit "$host" "$domain" "$key" array "$(quote_tail "$@")"
            ;;
        -dict)
            shift
            emit "$host" "$domain" "$key" dict "$(quote_tail "$@")"
            ;;
        -dict-add)
            shift
            emit "$host" "$domain" "$key" dict-add "$(quote_tail "$@")"
            ;;
        # An untyped value is handed to `defaults` to parse as a plist fragment,
        # which is what `AdminHostInfo HostName` and `mouse.scaling -1` rely on.
        *) emit "$host" "$domain" "$key" raw "$1" ;;
    esac
}

sudo() { "$@"; }

while IFS= read -r line || [ -n "$line" ]; do
    while [ "${line%\\}" != "$line" ]; do
        line="${line%\\}"
        IFS= read -r next || break
        line="$line${next#"${next%%[![:space:]]*}"}"
    done
    trimmed="${line#"${line%%[![:space:]]*}"}"
    case "$trimmed" in
        "" | "#"*)
            pending+=("$line")
            continue
            ;;
        "defaults write "* | "defaults -currentHost write "* | "sudo defaults write "*)
            eval "$trimmed"
            ;;
        *)
            if [ "$mode" = remainder ]; then
                flush_pending
                printf '%s\n' "$line"
            else
                pending=()
            fi
            ;;
    esac
done <"$SOURCE"
