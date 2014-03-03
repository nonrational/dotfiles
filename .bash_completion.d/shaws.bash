_get_pem_file_list() {
    # For test:
    #local -a flist=("foo" "bar")
    #printf "%s " "${flist[@]}"
    # Or:
    ls ~/.ssh/aws/

    # For live something in direction of:
    #ssh user@host 'ls /path/to/dir' <-- but not ls for other then dirty testing.
}

__ssh_known_hosts() {
    if [[ -f ~/.ssh/known_hosts ]]; then
        cut -d " " -f1 ~/.ssh/known_hosts | cut -d "," -f1
    fi
}

_GetOptPEM() {
    local cur known_hosts

    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    known_hosts="$(__ssh_known_hosts)"

    case "$cur" in
    -*)
        COMPREPLY=( $( compgen -W '-h --help' -- "$cur" ) );;
    # *@*)
        # COMPREPLY=( $(compgen -W "${known_hosts}" -P ${cur/@*/}@ -- ${cur/*@/}) );;
    *)
        if [ "$COMP_CWORD" == "1" ]; then
            COMPREPLY=( $( compgen -W "$(_get_pem_file_list)" -- "$cur" ) );
        elif [ "$COMP_CWORD" == "2" ]; then
            COMPREPLY=( $(compgen -W "${known_hosts}" -- ${cur}) );
        fi
        ;;
        # This could be done nicer I guess:
    esac

    return 0
}
