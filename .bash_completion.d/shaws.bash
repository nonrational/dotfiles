_get_pem_file_list()
{
    # For test:
    #local -a flist=("foo" "bar")
    #printf "%s " "${flist[@]}"
    # Or:
    ls ~/.ssh/aws/

    # For live something in direction of:
    #ssh user@host 'ls /path/to/dir' <-- but not ls for other then dirty testing.
}

_GetOptPEM()
{
    local cur

    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    case "$cur" in
    -*)
        COMPREPLY=( $( compgen -W '-h --help' -- "$cur" ) );;
    *)
        # This could be done nicer I guess:
        COMPREPLY=( $( compgen -W "$(_get_pem_file_list)" -- "$cur" ) );;
    esac

    return 0
}
