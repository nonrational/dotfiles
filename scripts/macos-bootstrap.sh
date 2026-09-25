#!/usr/bin/env bash

# macOS bootstrap: the imperative remainder of the original ~/.macos
# (https://mths.be/macos). Every `defaults write` that used to live here is now
# a row in ../macos-defaults; run `make macos-audit` to compare them against the
# machine. What is left cannot be expressed as a domain/key/value: nvram,
# systemsetup, sysadminctl, PlistBuddy, chflags, lsregister, tmutil, and the
# app restarts. Re-runnable; `make macos` runs it after applying the table.

# https://macos-defaults.com/

# Close any open System Preferences/Settings panes, to prevent them from overriding
# settings we're about to change
osascript -e 'tell application "System Preferences" to quit' 2> /dev/null
osascript -e 'tell application "System Settings" to quit' 2> /dev/null

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until this script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Disable the sound effects on boot
sudo nvram StartupMute=%01

# Remove duplicates in the “Open With” menu (also see `lscleanup` alias)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# Set the timezone; see `sudo systemsetup -listtimezones` for other values
sudo systemsetup -settimezone "America/Los_Angeles" > /dev/null

# Enable snap-to-grid for icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

# Increase grid spacing for icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist

# Increase the size of icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist

# Show the ~/Library folder
chflags nohidden ~/Library

# Show the /Volumes folder
sudo chflags nohidden /Volumes

# Require the password immediately after sleep or the screen saver begins.
# The old com.apple.screensaver rows are a one-time migration source that
# loginwindow erases; this is the live setting. Prompts for the login password.
sysadminctl -screenLock immediate -password -

# Disable automatic Time Machine backups (backups run only on demand)
hash tmutil &> /dev/null && sudo tmutil disable

###############################################################################
# Kill affected applications                                                  #
###############################################################################

for app in "Activity Monitor" "Calendar" "cfprefsd" "Contacts" "Dock" "Finder" "Google Chrome" "Mail" "Messages" "NotificationCenter" "Photos" "Safari" "SystemUIServer"; do
	killall "${app}" &> /dev/null
done
echo "Done. Note that some of these changes require a logout/restart to take effect."
