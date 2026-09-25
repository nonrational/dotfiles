#!/bin/bash
# Declarative macOS defaults: check/audit/apply/accept the `defaults write`
# lines in ./.macos, which stays a runnable script.
# Spec: docs/superpowers/specs/2026-08-25-macos-defaults-declarative-design.md
set -euf -o pipefail

DOTS="$(cd "$(dirname "$0")/.." && pwd)"
# Overridable so the test suite can point at a sandboxed script.
SOURCE="${MACOS_DEFAULTS_SOURCE:-$DOTS/.macos}"
TAB=$'\t'
HOME_TOKEN='${HOME}'

dry_run=0
mode=audit
filter_domain=""
filter_key=""
failures=0
unreadable_skipped=0
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

# One entry per `defaults write` line, in file order. t_status is the noaudit
# reason (derived for containers, marked otherwise) and t_condition the host
# marker; they are separate because a container row can also be per-host.
# t_line is the physical line the write starts on and t_span how many lines it
# covers, so accept can replace exactly that text; t_indent, t_prefix (`sudo `)
# and t_comment (a prose trailing comment) are what a rewritten line has to
# reproduce.
t_domain=()
t_key=()
t_type=()
t_value=()
t_status=()
t_condition=()
t_line=()
t_span=()
t_indent=()
t_prefix=()
t_comment=()

# --- parsing ----------------------------------------------------------------
# The `defaults write` lines are parsed by evaluating each one with `defaults`
# and `sudo` shimmed, so the shell does the tokenizing: quotes and ${HOME}
# behave exactly as they do when .macos runs. Before the eval, every line has
# to match safe_re, which admits only plain words, quoted strings and a
# trailing comment: no `;`, `&&`, pipes, redirections, `$(...)`, backticks or
# globs, so audit and check can never run anything but the shim. What passes
# is the same trust level as `sh .macos`, a script from this repo run by its
# owner.

parse_lineno=0
parse_emitted=0
cur_domain=""
cur_key=""
cur_type=""
cur_value=""

parse_error() {
    echo "error: $SOURCE line $parse_lineno: $1" >&2
    exit 1
}

quote_tail() {
    local out="" a
    for a in "$@"; do
        out="$out${out:+ }$(printf '%q' "$a")"
    done
    printf '%s' "$out"
}

emit() {
    local host="$1" domain="$2" key="$3" type="$4" value="$5"
    if [ "$parse_emitted" = 1 ]; then
        parse_error "more than one defaults write on one line"
    fi
    parse_emitted=1
    if [ "$host" = currentHost ]; then
        domain="currentHost:$domain"
    fi
    # eval expanded ${HOME} while parsing; put the token back so a row
    # describes desired state rather than one Mac's paths.
    value="$(tokenize_value "$value")"
    if [ "$type" = bool ]; then
        value="$(canonical_value bool "$value")"
    fi
    cur_domain="$domain"
    cur_key="$key"
    cur_type="$type"
    cur_value="$value"
}

# The shim. Only active while parse_source runs; unset afterwards so every
# later call reaches the real binary.
defaults() {
    local host=""
    if [ "${1:-}" = "-currentHost" ]; then
        host=currentHost
        shift
    fi
    if [ "${1:-}" != write ]; then
        parse_error "expected 'defaults write', got 'defaults ${1:-}'"
    fi
    shift
    if [ $# -lt 3 ]; then
        parse_error "expected domain, key and value"
    fi
    local domain="$1" key="$2"
    shift 2
    case "$1" in
        -bool | -boolean | -int | -integer | -float | -string | -date | -data)
            if [ $# -ne 2 ]; then
                parse_error "expected exactly one value after $1"
            fi
            ;;
    esac
    case "$1" in
        -bool | -boolean) emit "$host" "$domain" "$key" bool "$2" ;;
        -int | -integer) emit "$host" "$domain" "$key" int "$2" ;;
        -float) emit "$host" "$domain" "$key" float "$2" ;;
        -string) emit "$host" "$domain" "$key" string "$2" ;;
        # Container values, date and data included, are stored as the quoted
        # argument tail write_row re-splits; a date with spaces stays one word.
        -date) emit "$host" "$domain" "$key" date "$(quote_tail "$2")" ;;
        -data) emit "$host" "$domain" "$key" data "$(quote_tail "$2")" ;;
        -array | -dict | -dict-add)
            local type="${1#-}"
            shift
            emit "$host" "$domain" "$key" "$type" "$(quote_tail "$@")"
            ;;
        # Appending is never idempotent: every apply would add the elements
        # again. Spell the whole array out with -array instead.
        -array-add) parse_error "-array-add is not supported; write the full list with -array" ;;
        -[A-Za-z]*) parse_error "unknown type flag '$1'" ;;
        *)
            # An untyped value is handed to `defaults` to parse as a plist
            # fragment, which is what `AdminHostInfo HostName` relies on. A
            # negative number is a value, not a flag.
            if [ $# -ne 1 ]; then
                parse_error "expected exactly one untyped value"
            fi
            emit "$host" "$domain" "$key" raw "$1"
            ;;
    esac
}

sudo() { "$@"; }

is_container() {
    case "$1" in
        array | dict | dict-add | date | data) return 0 ;;
        *) return 1 ;;
    esac
}

# What a `defaults write` line may contain: plain words, single-quoted
# strings, double-quoted strings whose only expansion is ${HOME}, a bare
# ${HOME}, and an optional trailing comment. Everything the shell would treat
# as another command, an expansion or a glob is excluded outside quotes, and
# `$` and backticks are excluded inside double quotes, so the eval below can
# only ever reach the shim. Built from pieces because of the quote characters.
sq="'"
dq='"'
safe_plain="[^${dq}${sq}\\\\;&|<>\`\$(){}*?[#[:space:]]|[[:space:]]"
safe_single="${sq}[^${sq}]*${sq}"
safe_double="${dq}([^${dq}\\\\\`\$]|\\\\.|\\\$\\{HOME\\})*${dq}"
safe_re="^(${safe_plain}|${safe_single}|${safe_double}|\\\$\\{HOME\\})*([[:space:]]#.*)?\$"
# Capture groups, in order of opening paren: 1 the token loop, 2 inside
# safe_double, 3 the trailing comment. Parens inside bracket expressions do
# not count. Keep this in step with the pieces above.
comment_group=3
marker_token='[a-z]+=[A-Za-z0-9_.-]+'
markers_re="^${marker_token}([[:space:]]+${marker_token})*\$"

parse_source() {
    local line next trimmed start span indent prefix comment body head
    local status condition token j
    if [ ! -f "$SOURCE" ]; then
        echo "error: source not found at $SOURCE" >&2
        exit 1
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        parse_lineno=$((parse_lineno + 1))
        start="$parse_lineno"
        span=1
        # Backslash-newline joins the next line verbatim, as the shell does:
        # no whitespace stripped, and never after a comment, where the shell
        # has already discarded the backslash.
        case "${line#"${line%%[![:space:]]*}"}" in
            "#"*) ;;
            *)
                while [ "${line%\\}" != "$line" ]; do
                    line="${line%\\}"
                    IFS= read -r next || break
                    parse_lineno=$((parse_lineno + 1))
                    span=$((span + 1))
                    line="$line$next"
                done
                ;;
        esac
        indent="${line%%[![:space:]]*}"
        trimmed="${line#"$indent"}"
        prefix=""
        case "$trimmed" in
            "defaults write "* | "defaults -currentHost write "*) ;;
            "sudo defaults write "*) prefix="sudo " ;;
            *) continue ;;
        esac
        if ! [[ "$trimmed" =~ $safe_re ]]; then
            parse_error "line contains shell syntax the parser will not run (; & | < > \$( \` or an unquoted paren or glob); put any other command on its own line"
        fi
        # bash 3.2 leaves a group that did not participate unset.
        comment="${BASH_REMATCH[$comment_group]:-}"
        head="${trimmed%"$comment"}"
        # A trailing comment made only of key=value tokens is a set of markers.
        # One that mixes a marker with prose is an error rather than prose, so
        # a marker cannot degrade silently. Anything else is kept as a comment.
        status=""
        condition=""
        body="${comment#*#}"
        body="${body#"${body%%[![:space:]]*}"}"
        body="${body%"${body##*[![:space:]]}"}"
        if [ -n "$body" ] && [[ "$body" =~ $markers_re ]]; then
            comment=""
            for token in $body; do
                case "$token" in
                    host=?*)
                        if [ -n "$condition" ]; then
                            parse_error "more than one host= marker"
                        fi
                        condition="$token"
                        ;;
                    noaudit=unset | noaudit=complex)
                        if [ -n "$status" ]; then
                            parse_error "more than one noaudit= marker"
                        fi
                        status="$token"
                        ;;
                    noaudit=tcc)
                        parse_error "noaudit=tcc is derived at audit time; remove the marker"
                        ;;
                    *) parse_error "unknown marker '$token'" ;;
                esac
            done
        elif [[ "$body" =~ (^|[[:space:]])[a-z]+= ]]; then
            parse_error "a marker comment may contain only key=value tokens; move the prose above the line"
        fi
        parse_emitted=0
        eval "$head"
        if [ "$parse_emitted" = 0 ]; then
            parse_error "no defaults write recognized"
        fi
        case "$status" in
            noaudit=unset)
                if is_container "$cur_type"; then
                    parse_error "noaudit=unset does not apply to a container type"
                fi
                ;;
            noaudit=complex)
                if [ "$cur_type" != raw ]; then
                    parse_error "noaudit=complex is only for an untyped value; a typed container is already skipped and a scalar can be compared"
                fi
                ;;
        esac
        # A container value has no scalar form to compare, so audit always
        # skips it. Derived from the type rather than written down.
        if is_container "$cur_type"; then
            status="noaudit=complex"
        fi
        # dict-add legitimately repeats a domain+key, one line per entry; every
        # other type must own its domain+key uniquely per host or apply can
        # never converge (each line would fight the other's write).
        if [ "$cur_type" != dict-add ]; then
            j=0
            while [ "$j" -lt "${#t_domain[@]}" ]; do
                if [ "${t_type[$j]}" != dict-add ] \
                    && [ "${t_domain[$j]}" = "$cur_domain" ] \
                    && [ "${t_key[$j]}" = "$cur_key" ] \
                    && [ "${t_condition[$j]}" = "$condition" ]; then
                    parse_error "duplicate domain+key '$cur_domain $cur_key' (first on line ${t_line[$j]})"
                fi
                j=$((j + 1))
            done
        fi
        t_domain+=("$cur_domain")
        t_key+=("$cur_key")
        t_type+=("$cur_type")
        t_value+=("$cur_value")
        t_status+=("$status")
        t_condition+=("$condition")
        t_line+=("$start")
        t_span+=("$span")
        t_indent+=("$indent")
        t_prefix+=("$prefix")
        t_comment+=("$comment")
    done <"$SOURCE"
    unset -f defaults sudo
    if [ "${#t_domain[@]}" -eq 0 ]; then
        echo "error: $SOURCE has no defaults write lines" >&2
        exit 1
    fi
}

# --- comparison -------------------------------------------------------------

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
host="$(host_id)"

condition_matches() {
    case "$1" in
        "") return 0 ;;
        host=*) [ "${1#host=}" = "$host" ] ;;
        *) return 1 ;;
    esac
}

defaults_read() {
    local domain="$1" key="$2"
    case "$domain" in
        currentHost:*) command defaults -currentHost read "${domain#currentHost:}" "$key" 2>/dev/null ;;
        *) command defaults read "$domain" "$key" 2>/dev/null ;;
    esac
}

# Whether the domain itself reads. A domain that will not read is how TCC
# denial presents from a shell, and also how an app that has never written
# preferences looks; either way there is no key to compare.
domain_reads() {
    case "$1" in
        currentHost:*) command defaults -currentHost read "${1#currentHost:}" >/dev/null 2>&1 ;;
        *) command defaults read "$1" >/dev/null 2>&1 ;;
    esac
}

defaults_read_type() {
    local domain="$1" key="$2" out
    case "$domain" in
        currentHost:*)
            out="$(command defaults -currentHost read-type "${domain#currentHost:}" "$key" 2>/dev/null)" || return 1
            ;;
        *)
            out="$(command defaults read-type "$domain" "$key" 2>/dev/null)" || return 1
            ;;
    esac
    printf '%s\n' "${out#Type is }"
}

type_name_of() {
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

# Booleans are kept as true/false so the file stays reviewable, but
# `defaults read` returns 0/1. Canonicalize on the way in, since accept is
# what writes lines back.
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

# Rows hold ${HOME} literally so a line describes desired state rather than
# one machine's paths. Every comparison and every write expands it.
expand_value() {
    local v="$1"
    printf '%s\n' "${v//\$\{HOME\}/$HOME}"
}

tokenize_value() {
    local v="$1"
    printf '%s\n' "${v//$HOME/$HOME_TOKEN}"
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
    [ "$(type_name_of "$live_type")" = "$type" ]
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
        # An unset marker records that the key may never read back; an
        # unreadable domain means either no Full Disk Access or an app that
        # has never written preferences. Neither is a decision to ignore the
        # row: both are audited as soon as they read.
        if [ "$status" = "noaudit=unset" ]; then
            echo "skip: $domain $key (unset)"
            unset_skipped=$((unset_skipped + 1))
            return 0
        fi
        if ! domain_reads "$domain"; then
            echo "skip: $domain $key (unreadable domain)"
            unreadable_skipped=$((unreadable_skipped + 1))
            return 0
        fi
        echo "missing: $domain $key"
        failures=$((failures + 1))
        missing_count=$((missing_count + 1))
        return 0
    fi

    # A `raw` row is written with no type flag, so `defaults` infers the stored
    # type and the line has no claim to assert against it.
    if [ "$type" != raw ]; then
        if live_type="$(defaults_read_type "$domain" "$key")"; then
            live_type="$(type_name_of "$live_type")"
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

# --- apply ------------------------------------------------------------------

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

# --- accept -----------------------------------------------------------------

# Quotes one argument the way .macos spells it: bare when it is plain, double
# quoted otherwise, with ${HOME} left expandable so the line still runs.
shell_word() {
    local w="$1"
    # Pattern and replacement live in variables: bash 3.2 (macOS /bin/bash)
    # mishandles backslashes written inline in a double-quoted substitution.
    local escaped_token='\\$\{HOME\}' token='${HOME}'
    case "$w" in
        "") printf '""' ;;
        *[!A-Za-z0-9_./:@+=,-]*)
            w="${w//\\/\\\\}"
            w="${w//\"/\\\"}"
            w="${w//\`/\\\`}"
            w="${w//\$/\\\$}"
            w="${w//$escaped_token/$token}"
            printf '"%s"' "$w"
            ;;
        *) printf '%s' "$w" ;;
    esac
}

# Rebuilds one line from its parts: indentation, `sudo `, the write, the live
# type flag and value, then the markers (or the prose comment the line had).
format_line() {
    local i="$1" type="$2" value="$3" status="$4"
    local domain="${t_domain[$i]}" host_flag="" out markers=""
    case "$domain" in
        currentHost:*)
            host_flag=" -currentHost"
            domain="${domain#currentHost:}"
            ;;
    esac
    out="${t_indent[$i]}${t_prefix[$i]}defaults${host_flag} write $(shell_word "$domain") $(shell_word "${t_key[$i]}")"
    if [ "$type" = raw ]; then
        out="$out $(shell_word "$value")"
    else
        out="$out -$type $(shell_word "$value")"
    fi
    if [ -n "$status" ]; then
        markers="$status"
    fi
    if [ -n "${t_condition[$i]}" ]; then
        markers="$markers${markers:+ }${t_condition[$i]}"
    fi
    if [ -n "$markers" ]; then
        out="$out # $markers"
    elif [ -n "${t_comment[$i]}" ]; then
        out="$out${t_comment[$i]}"
    fi
    printf '%s\n' "$out"
}

# A complex row's value is an eval argument tail, not a serialization
# `defaults read` could ever match, so accepting one would rewrite it with a
# multi-line plist dump. A row whose domain will not read is an ordinary
# scalar whenever it reads at all, so it is accepted like any other; when it
# does not read, the inner `defaults_read` below skips it anyway.
accept_candidate() {
    local i="$1"
    case "${t_status[$i]}" in
        noaudit=complex) return 1 ;;
    esac
    row_selected "$i" && condition_matches "${t_condition[$i]}"
}

run_accept() {
    local i n live live_type new_status skip_reason tmp line lineno prefix=""
    local new_line=() line_owner=()

    if [ "$dry_run" = 1 ]; then
        prefix="would: "
    fi
    n="${#t_domain[@]}"
    i=0
    while [ "$i" -lt "$n" ]; do
        new_line[$i]=""
        if accept_candidate "$i"; then
            if live="$(defaults_read "${t_domain[$i]}" "${t_key[$i]}")"; then
                skip_reason=""
                case "$live" in
                    *"$TAB"*) skip_reason="value contains a tab" ;;
                    *$'\n'*) skip_reason="value contains a newline" ;;
                esac
                if [ "${t_span[$i]}" -gt 1 ]; then
                    skip_reason="line spans ${t_span[$i]} lines; edit it by hand"
                fi
                if [ -n "$skip_reason" ]; then
                    echo "accept: ${t_domain[$i]} ${t_key[$i]}: skipped, $skip_reason" >&2
                else
                    new_status="${t_status[$i]}"
                    # The marker only recorded that the key was unreadable when
                    # written; it just read, so it no longer describes anything.
                    if [ "$new_status" = "noaudit=unset" ]; then
                        new_status=""
                    fi
                    live_type="${t_type[$i]}"
                    if [ "$live_type" != raw ]; then
                        if live_type="$(defaults_read_type "${t_domain[$i]}" "${t_key[$i]}")"; then
                            live_type="$(type_name_of "$live_type")"
                        else
                            live_type="${t_type[$i]}"
                        fi
                    fi
                    if [ "$live_type" != "${t_type[$i]}" ] \
                        || [ "$(normalize "$live_type" "$live")" != "$(normalize "${t_type[$i]}" "$(expand_value "${t_value[$i]}")")" ] \
                        || [ "$new_status" != "${t_status[$i]}" ]; then
                        new_line[$i]="$(format_line "$i" "$live_type" "$(canonical_value "$live_type" "$(tokenize_value "$live")")" "$new_status")"
                        line_owner[${t_line[$i]}]="$i"
                        echo "${prefix}accept: ${t_domain[$i]} ${t_key[$i]} = $live"
                    fi
                fi
            fi
        fi
        i=$((i + 1))
    done

    if [ "$dry_run" = 1 ] || [ "${#line_owner[@]}" -eq 0 ]; then
        return 0
    fi
    # Assembled beside the source and moved into place in one rename, so a
    # failure part-way leaves .macos untouched and the trap removes the
    # scratch file. `cp -p` gives the scratch file the source's mode first,
    # so the rename keeps .macos executable if it was.
    tmp="$(mktemp "$SOURCE.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    cp -p "$SOURCE" "$tmp"
    lineno=0
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        if [ -n "${line_owner[$lineno]:-}" ]; then
            printf '%s\n' "${new_line[${line_owner[$lineno]}]}"
        else
            printf '%s\n' "$line"
        fi
    done <"$SOURCE" >"$tmp"
    mv -f "$tmp" "$SOURCE"
    trap - EXIT
}

# --- main -------------------------------------------------------------------

# Full Disk Access is a prerequisite for auditing app-container preferences:
# without it the shell cannot read Safari's or Mail's domains and those rows
# skip instead of being checked. This directory is readable only by a process
# that has been granted it.
has_full_disk_access() {
    ls "$HOME/Library/Application Support/com.apple.TCC" >/dev/null 2>&1
}

main() {
    local i n
    parse_source
    n="${#t_domain[@]}"
    if [ "$mode" = check ]; then
        if [ "$n" = 1 ]; then
            echo "ok: 1 row in $SOURCE"
        else
            echo "ok: $n rows in $SOURCE"
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
        echo "ok: $n rows in $SOURCE"
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
            if ! condition_matches "${t_condition[$i]}"; then
                echo "skip: ${t_domain[$i]} ${t_key[$i]} (${t_condition[$i]})"
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
    if [ "$mode" = audit ] && [ "$unreadable_skipped" -gt 0 ] && ! has_full_disk_access; then
        echo "hint: $unreadable_skipped rows skipped because their domain would not read. Grant Full Disk Access to this terminal to audit them (./scripts/macos-defaults.sh doctor)." >&2
    fi
    if [ "$mode" = audit ]; then
        local skipped=$((condition_skipped + unreadable_skipped + unset_skipped + complex_skipped))
        echo "summary: $ok_count ok, $drift_count drift, $missing_count missing, $skipped skipped (condition $condition_skipped, unreadable $unreadable_skipped, unset $unset_skipped, complex $complex_skipped)"
    fi
    if [ "$failures" -gt 0 ]; then
        exit 1
    fi
}

main
