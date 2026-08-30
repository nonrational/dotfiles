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
tcc_skipped=0
unset_skipped=0
complex_skipped=0
condition_skipped=0
ok_count=0
drift_count=0
missing_count=0

usage() {
    echo "usage: $0 [--dry-run] [check|audit|apply|accept|doctor] [domain [key]]" >&2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            dry_run=1
            shift
            ;;
        check | audit | apply | accept | doctor)
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

# Maps a row's status to the condition that scopes which machine it applies
# to. `os=`/`host=` pass through verbatim; an empty status and any `noaudit=`
# status both collapse to "no condition", because noaudit records why a row
# might be unreadable, not a decision about which machine it targets.
status_condition() {
    case "$1" in
        os=* | host=*) printf '%s' "$1" ;;
        *) printf '%s' "" ;;
    esac
}

parse_table() {
    local lineno=0 line trimmed status i j
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
                    noaudit=complex) ;;
                    *)
                        echo "error: $TABLE line $lineno: type '${ROW[2]}' cannot be compared; it needs noaudit=complex" >&2
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
        # dict-add legitimately repeats a domain+key across rows, one per
        # dict entry; every other type must own its domain+key uniquely or
        # apply can never converge (each row would fight the other's write).
        if [ "${ROW[2]}" != dict-add ]; then
            j=0
            while [ "$j" -lt "${#t_domain[@]}" ]; do
                if [ "${t_type[$j]}" != dict-add ] \
                    && [ "${t_domain[$j]}" = "${ROW[0]}" ] \
                    && [ "${t_key[$j]}" = "${ROW[1]}" ] \
                    && [ "$(status_condition "${t_status[$j]}")" = "$(status_condition "$status")" ]; then
                    echo "error: $TABLE line $lineno: duplicate domain+key '${ROW[0]} ${ROW[1]}'" >&2
                    exit 1
                fi
                j=$((j + 1))
            done
        fi
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

source "$DOTS/scripts/host-id.sh"
os="$(os_id)"
host="$(host_id)"

condition_matches() {
    case "$1" in
        "" | noaudit=*) return 0 ;;
        os=*) [ "${1#os=}" = "$os" ] ;;
        host=*) [ "${1#host=}" = "$host" ] ;;
        *) return 1 ;;
    esac
}

defaults_read() {
    local domain="$1" key="$2"
    case "$domain" in
        currentHost:*) defaults -currentHost read "${domain#currentHost:}" "$key" 2>/dev/null ;;
        *) defaults read "$domain" "$key" 2>/dev/null ;;
    esac
}

defaults_read_type() {
    local domain="$1" key="$2" out
    case "$domain" in
        currentHost:*)
            out="$(defaults -currentHost read-type "${domain#currentHost:}" "$key" 2>/dev/null)" || return 1
            ;;
        *)
            out="$(defaults read-type "$domain" "$key" 2>/dev/null)" || return 1
            ;;
    esac
    printf '%s\n' "${out#Type is }"
}

table_type_of() {
    case "$1" in
        boolean) printf 'bool\n' ;;
        integer) printf 'int\n' ;;
        dictionary) printf 'dict\n' ;;
        *) printf '%s\n' "$1" ;;
    esac
}

normalize() {
    case "$1" in
        bool)
            case "$2" in
                true | TRUE | True | YES | Yes | yes | 1) printf '1\n' ;;
                false | FALSE | False | NO | No | no | 0) printf '0\n' ;;
                *) printf '%s\n' "$2" ;;
            esac
            ;;
        *) printf '%s\n' "$2" ;;
    esac
}

# The table's booleans read true/false so the file stays reviewable, but
# `defaults read` returns 0/1. Canonicalize on the way in, since accept is
# what writes rows back.
canonical_value() {
    local type="$1" v="$2"
    if [ "$type" != bool ]; then
        printf '%s\n' "$v"
        return 0
    fi
    case "$(normalize bool "$v")" in
        1) printf 'true\n' ;;
        0) printf 'false\n' ;;
        *) printf '%s\n' "$v" ;;
    esac
}

# The table stores ${HOME} literally so a row describes desired state rather
# than one machine's paths. Every comparison and every write expands it.
expand_value() {
    local v="$1"
    printf '%s\n' "${v//\$\{HOME\}/$HOME}"
}

tokenize_value() {
    local v="$1" token='${HOME}'
    printf '%s\n' "${v//$HOME/$token}"
}

# audit reports a type drift, so apply has to be able to resolve one. Without
# this the two commands disagree about whether a row has changed and apply
# silently leaves a drift that audit keeps reporting.
type_matches() {
    local domain="$1" key="$2" type="$3" live_type
    if [ "$type" = raw ]; then
        return 0
    fi
    if ! live_type="$(defaults_read_type "$domain" "$key")"; then
        return 0
    fi
    [ "$(table_type_of "$live_type")" = "$type" ]
}

audit_row() {
    local i="$1"
    local domain="${t_domain[$i]}" key="${t_key[$i]}" type="${t_type[$i]}"
    local value="${t_value[$i]}" status="${t_status[$i]}"
    local live want live_type

    case "$status" in
        noaudit=complex)
            echo "skip: $domain $key (complex)"
            complex_skipped=$((complex_skipped + 1))
            return 0
            ;;
    esac

    if ! live="$(defaults_read "$domain" "$key")"; then
        case "$status" in
            noaudit=*)
                # tcc and unset both record why a row may be unreadable, not a
                # decision to ignore it: TCC visibility depends on whether this
                # terminal has Full Disk Access, and an unset key appears once
                # its app first writes preferences. Audit them when they read.
                if [ "$status" = "noaudit=tcc" ]; then
                    tcc_skipped=$((tcc_skipped + 1))
                else
                    unset_skipped=$((unset_skipped + 1))
                fi
                echo "skip: $domain $key (${status#noaudit=})"
                return 0
                ;;
        esac
        echo "missing: $domain $key"
        failures=$((failures + 1))
        missing_count=$((missing_count + 1))
        return 0
    fi

    # A `raw` row is written with no type flag, so `defaults` infers the stored
    # type and the table has no claim to assert against it.
    if [ "$type" != raw ]; then
        if live_type="$(defaults_read_type "$domain" "$key")"; then
            live_type="$(table_type_of "$live_type")"
            if [ "$live_type" != "$type" ]; then
                echo "drift: $domain $key type want=$type live=$live_type"
                failures=$((failures + 1))
                drift_count=$((drift_count + 1))
                return 0
            fi
        fi
    fi

    want="$(normalize "$type" "$(expand_value "$value")")"
    live="$(normalize "$type" "$live")"
    if [ "$want" = "$live" ]; then
        echo "ok: $domain $key"
        ok_count=$((ok_count + 1))
    else
        echo "drift: $domain $key want=$want live=$live"
        failures=$((failures + 1))
        drift_count=$((drift_count + 1))
    fi
}

# Decided from the plist's writability rather than the path prefix: the test
# suite uses absolute-path domains under mktemp, which are writable and must
# not reach for sudo.
needs_sudo() {
    local domain="$1"
    case "$domain" in
        /*) ;;
        *) return 1 ;;
    esac
    [ -e "$domain.plist" ] && [ ! -w "$domain.plist" ]
}

write_row() {
    local domain="$1" key="$2" type="$3" value="$4"
    local host_flag="" target="$domain" sudo_cmd=""
    value="$(expand_value "$value")"

    case "$domain" in
        currentHost:*)
            host_flag="-currentHost"
            target="${domain#currentHost:}"
            ;;
    esac
    if needs_sudo "$target"; then
        sudo_cmd="sudo"
    fi

    case "$type" in
        array | dict | dict-add | date | data)
            # Container values carry their own quoted argument tail, which only
            # the shell can re-split. Scalar rows never take this branch.
            eval "$sudo_cmd defaults $host_flag write \"\$target\" \"\$key\" -$type $value"
            ;;
        raw)
            $sudo_cmd defaults $host_flag write "$target" "$key" "$value"
            ;;
        *)
            $sudo_cmd defaults $host_flag write "$target" "$key" "-$type" "$value"
            ;;
    esac
}

apply_row() {
    local i="$1"
    local domain="${t_domain[$i]}" key="${t_key[$i]}" type="${t_type[$i]}"
    local value="${t_value[$i]}" status="${t_status[$i]}"
    local prefix="" live

    if [ "$dry_run" = 1 ]; then
        prefix="would: "
    fi

    case "$status" in
        noaudit=*) ;;
        *)
            if live="$(defaults_read "$domain" "$key")"; then
                if [ "$(normalize "$type" "$live")" = "$(normalize "$type" "$(expand_value "$value")")" ] \
                    && type_matches "$domain" "$key" "$type"; then
                    echo "ok: $domain $key"
                    return 0
                fi
            fi
            ;;
    esac

    echo "${prefix}write: $domain $key = $value"
    if [ "$dry_run" = 1 ]; then
        return 0
    fi
    write_row "$domain" "$key" "$type" "$value"
}

# A complex row's value column is an eval argument tail, not a serialization
# `defaults read` could ever match, so accepting one would rewrite it with a
# multi-line plist dump and break the one-row-per-line format. A tcc row is an
# ordinary scalar whenever it reads at all, so it is accepted like any other;
# when it does not read, the inner `defaults_read` below skips it anyway.
accept_candidate() {
    local i="$1"
    case "${t_status[$i]}" in
        noaudit=complex) return 1 ;;
    esac
    row_selected "$i" && condition_matches "${t_status[$i]}"
}

run_accept() {
    local i n idx live live_type new_status skip_reason tmp line trimmed prefix=""
    local new_row=()

    if [ "$dry_run" = 1 ]; then
        prefix="would: "
    fi
    n="${#t_domain[@]}"
    i=0
    while [ "$i" -lt "$n" ]; do
        new_row[$i]=""
        if accept_candidate "$i"; then
            if live="$(defaults_read "${t_domain[$i]}" "${t_key[$i]}")"; then
                skip_reason=""
                case "$live" in
                    "") skip_reason="value is empty" ;;
                    *"$TAB"*) skip_reason="value contains a tab" ;;
                    *$'\n'*) skip_reason="value contains a newline" ;;
                esac
                if [ -n "$skip_reason" ]; then
                    echo "accept: ${t_domain[$i]} ${t_key[$i]}: skipped, live $skip_reason" >&2
                else
                    new_status="${t_status[$i]}"
                    # The marker only recorded that the key was unreadable at seed
                    # time; it just read, so it no longer describes anything.
                    if [ "$new_status" = "noaudit=unset" ]; then
                        new_status=""
                    fi
                    live_type="${t_type[$i]}"
                    if [ "$live_type" != raw ]; then
                        if live_type="$(defaults_read_type "${t_domain[$i]}" "${t_key[$i]}")"; then
                            live_type="$(table_type_of "$live_type")"
                        else
                            live_type="${t_type[$i]}"
                        fi
                    fi
                    if [ "$live_type" != "${t_type[$i]}" ] \
                        || [ "$(normalize "$live_type" "$live")" != "$(normalize "${t_type[$i]}" "$(expand_value "${t_value[$i]}")")" ] \
                        || [ "$new_status" != "${t_status[$i]}" ]; then
                        new_row[$i]="${t_domain[$i]}$TAB${t_key[$i]}$TAB$live_type$TAB$(canonical_value "$live_type" "$(tokenize_value "$live")")"
                        if [ -n "$new_status" ]; then
                            new_row[$i]="${new_row[$i]}$TAB$new_status"
                        fi
                        echo "${prefix}accept: ${t_domain[$i]} ${t_key[$i]} = $live"
                    fi
                fi
            fi
        fi
        i=$((i + 1))
    done

    tmp="$(mktemp "$TABLE.XXXXXX")"
    idx=0
    while IFS= read -r line || [ -n "$line" ]; do
        trimmed="${line#"${line%%[![:space:]]*}"}"
        case "$trimmed" in
            "" | "#"*)
                printf '%s\n' "$line" >>"$tmp"
                continue
                ;;
        esac
        if [ -n "${new_row[$idx]}" ]; then
            printf '%s\n' "${new_row[$idx]}" >>"$tmp"
        else
            printf '%s\n' "$line" >>"$tmp"
        fi
        idx=$((idx + 1))
    done <"$TABLE"

    if [ "$dry_run" = 1 ]; then
        rm -f "$tmp"
        return 0
    fi
    mv "$tmp" "$TABLE"
}

# Full Disk Access is a prerequisite for auditing app-container preferences:
# without it the shell cannot read Safari's or Mail's domains and those rows
# skip instead of being checked. This directory is readable only by a process
# that has been granted it.
has_full_disk_access() {
    ls "$HOME/Library/Application Support/com.apple.TCC" >/dev/null 2>&1
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
    if [ "$mode" = doctor ]; then
        if has_full_disk_access; then
            echo "ok: Full Disk Access granted"
        else
            echo "error: Full Disk Access not granted to this terminal" >&2
            echo "  App-container rows (Safari, Mail) cannot be audited without it." >&2
            echo "  Grant it in System Settings > Privacy & Security > Full Disk Access," >&2
            echo "  add your terminal, then restart the terminal." >&2
            failures=$((failures + 1))
        fi
        echo "ok: $n rows in $TABLE"
        if [ "$failures" -gt 0 ]; then
            exit 1
        fi
        return 0
    fi
    if [ "$mode" = accept ]; then
        run_accept
        return 0
    fi
    i=0
    while [ "$i" -lt "$n" ]; do
        if row_selected "$i"; then
            if ! condition_matches "${t_status[$i]}"; then
                echo "skip: ${t_domain[$i]} ${t_key[$i]} (${t_status[$i]})"
                condition_skipped=$((condition_skipped + 1))
            else
                case "$mode" in
                    audit) audit_row "$i" ;;
                    apply) apply_row "$i" ;;
                esac
            fi
        fi
        i=$((i + 1))
    done
    if [ "$mode" = audit ] && [ "$tcc_skipped" -gt 0 ] && ! has_full_disk_access; then
        echo "hint: $tcc_skipped rows skipped for tcc. Grant Full Disk Access to this terminal to audit them (./scripts/macos-defaults.sh doctor)." >&2
    fi
    if [ "$mode" = audit ]; then
        local skipped=$((condition_skipped + tcc_skipped + unset_skipped + complex_skipped))
        echo "summary: $ok_count ok, $drift_count drift, $missing_count missing, $skipped skipped (condition $condition_skipped, tcc $tcc_skipped, unset $unset_skipped, complex $complex_skipped)"
    fi
    if [ "$failures" -gt 0 ]; then
        exit 1
    fi
}

main
