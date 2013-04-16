#!/bin/bash
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
defaults write NSGlobalDomain KeyRepeat -int 0
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write com.apple.dock orientation left
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

killall Dock
killall Finder
