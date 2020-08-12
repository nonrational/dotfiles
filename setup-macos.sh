#!/usr/bin/env bash
set -euf -o pipefail

log_and_exec(){
    echo $1
    sh $1
}

# homebrew & bundle
command -v brew || /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brew bundle

log_and_exec 20-install-profile.sh
log_and_exec 30-install-sublime-prefs.sh
log_and_exec 40-install-iterm2-preferences.sh
log_and_exec 50-install-karabiner-preferences.sh

log_and_exec 99-install-osx-prefs.sh

# osascript -e 'tell app "loginwindow" to «event aevtrrst»'
