default:
	@echo "Cowardly refusing to run on $(shell uname). Use platform specific targets."

brew-install:
	/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew-bundle:
	eval "$$(/opt/homebrew/bin/brew shellenv)"
	brew update
	brew bundle

macos:
	sh .macos
	osascript -e 'tell app "loginwindow" to «event aevtrrst»'

macos-reset-dock:
	defaults write com.apple.dock persistent-apps -array
	killall Dock

link-dotfiles:
	mkdir -p $$HOME/.local
	./link-dotfiles.sh

link-karabiner:
	# don't link entire .config directory because it may contain secrets
	mkdir -p $$HOME/.config
	ln -s $$PWD/karabiner $$HOME/.config/karabiner

link-sublime:
	git clone https://github.com/nonrational/sublime3 $$HOME/.sublime3
	rm -rf $$HOME/Library/Application\ Support/Sublime\ Text
	ln -s $$HOME/.sublime3 $$HOME/Library/Application\ Support/Sublime\ Text

backup-preferences:
	cp $$HOME/Library/Preferences/com.googlecode.iterm2.plist $$PWD/etc/com.googlecode.iterm2.plist
	cp $$HOME/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/com.if.Amphetamine.plist $$PWD/etc/com.if.Amphetamine.plist

restore-preferences:
	@mkdir -p $$HOME/Library/Preferences/
	cp $$PWD/etc/com.googlecode.iterm2.plist $$HOME/Library/Preferences/com.googlecode.iterm2.plist
	@mkdir -p $$HOME/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/
	cp $$PWD/etc/com.if.Amphetamine.plist $$HOME/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/com.if.Amphetamine.plist

macos-disable-restore-apps-on-login:
	# See https://apple.stackexchange.com/a/322787
	# clear the file if it isn't empty
	find ~/Library/Preferences/ByHost/ -name 'com.apple.loginwindow*' ! -size 0 -exec tee {} \; < /dev/null
	# set the user immutable flag
	find ~/Library/Preferences/ByHost/ -name 'com.apple.loginwindow*' -exec chflags uimmutable {} \;

# grep '^\w' Makefile | sed 's/:.*//g' | tr '\n' ' ' | pbcopy
.PHONY: default macos-setup init-post-reboot brew-install brew-bundle macos-reset-dock macos link-dotfiles link-karabiner link-sublime backup-preferences restore-preferences disable-restore-apps-on-login
