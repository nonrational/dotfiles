#!/usr/bin/env bash

log_and_exec(){
    echo $1
    sh $1
}

# log_and_exec 00-install-osx-prefs.sh

log_and_exec 01-install-development-headers.sh

log_and_exec 10-install-homebrew.sh

brew bundle

log_and_exec 20-install-profile.sh

log_and_exec 30-install-sublime-prefs.sh

log_and_exec 40-install-iterm2-preferences.sh
