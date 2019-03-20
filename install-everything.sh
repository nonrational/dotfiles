#!/usr/bin/env bash

log_and_exec(){
    echo $1
    sh $1
}

log_and_exec 00-install-osx-prefs.sh

log_and_exec 01-install-homebrew.sh

brew bundle

log_and_exec 02-install-profile.sh

log_and_exec 03-install-sublime-prefs.sh

log_and_exec 04-install-iterm2-preferences.sh
