#!/usr/bin/env bash

# Bash completion support for Rake, Ruby Make.

# This messes up COMP_WORDBREAKS throughout the system.
# Fixing it to restrict changes to rakecomplete only.
# export COMP_WORDBREAKS=${COMP_WORDBREAKS/\:/}

# Troubleshooting ===
# If completion isn't working, ensure you've bundled and that bare `rake` works.
# After that, you may need to `rm .rake_tasks~`.

_rakecomplete() {
    local cur
    _get_comp_words_by_ref -n : cur
    rakefile=""
    seek_path="."
    while true; do
        rakefile="${seek_path}/Rakefile"
        [[ $(readlink -f $seek_path) == "/" || -f "$rakefile" ]] && break
        seek_path="../${seek_path}"
    done

    if [[ -f "$rakefile" ]]; then
        recent=`ls -t $seek_path/.rake_tasks~ ${rakefile} **/*.rake 2> /dev/null | head -n 1`
        if [[ $recent != "$seek_path/.rake_tasks~" ]]; then
            rake --silent --prereqs | grep "rake" | cut -d " " -f 2 > $seek_path/.rake_tasks~
        fi
        COMPREPLY=($(compgen -W "`cat $seek_path/.rake_tasks~`" -- "$cur"))
        # remove colon containing prefix from COMPREPLY items
        __ltrim_colon_completions "$cur"
        return 0
    else
      COMPREPLY=()
    fi
}

complete -o default -o nospace -F _rakecomplete rake
