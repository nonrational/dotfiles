#!/bin/bash
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false
defaults write NSGlobalDomain KeyRepeat -int 0
defaults write -g ApplePressAndHoldEnabled -bool false

defaults write com.apple.dashboard devmode YES

defaults write com.apple.dock orientation left

defaults write com.apple.finder AppleShowAllFiles FALSE
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"


killall Dock
killall Finder
