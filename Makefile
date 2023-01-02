default:
	@echo "Cowardly refusing to run on $(shell uname). Use platform specific targets."

init: brew-install brew-bundle link-dotfiles link-karabiner macos
	osascript -e 'tell app "loginwindow" to «event aevtrrst»'

init-post-reboot: asdf link-sublime link-vscode restore-preferences disable-restore-apps-on-login

brew-install:
	/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew-bundle:
	brew update
	brew bundle

asdf:
	asdf plugin-add golang
	asdf plugin-add ruby
	asdf plugin-add nodejs
	asdf plugin-add erlang
	asdf plugin-add elixir

macos-reset-dock:
	defaults write com.apple.dock persistent-apps -array
	killall Dock

macos:
	sh .macos

link-dotfiles:
	mkdir -p $$HOME/.local
	./link-dotfiles.sh

link-karabiner:
	# don't link entire .config directory because it contains secrets sometimes
	mkdir -p $$HOME/.config
	ln -s $$PWD/karabiner $$HOME/.config/karabiner

link-sublime:
	git clone https://github.com/nonrational/sublime3 $$HOME/.sublime3
	rm -rf $$HOME/Library/Application\ Support/Sublime\ Text
	ln -s $$HOME/.sublime3 $$HOME/Library/Application\ Support/Sublime\ Text

link-vscode:
	ln -sf $$PWD/etc/vscode.keybindings.json $$HOME/Library/Application\ Support/Code/User/keybindings.json
	ln -sf $$PWD/etc/vscode.settings.json $$HOME/Library/Application\ Support/Code/User/settings.json

backup-preferences:
	cp $$HOME/Library/Preferences/com.googlecode.iterm2.plist $$PWD/etc/com.googlecode.iterm2.plist
	cp $$HOME/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/com.if.Amphetamine.plist $$PWD/etc/com.if.Amphetamine.plist
	code --list-extensions > $$PWD/etc/vscode--list-extensions.txt

restore-preferences:
	cp $$PWD/etc/com.googlecode.iterm2.plist $$HOME/Library/Preferences/com.googlecode.iterm2.plist
	cp $$PWD/etc/com.if.Amphetamine.plist $$HOME/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/com.if.Amphetamine.plist
	# cat $$PWD/etc/vscode--list-extensions.txt | xargs -n 1 code --install-extension

disable-restore-apps-on-login:
	# See https://apple.stackexchange.com/a/322787
	# clear the file if it isn't empty
	find ~/Library/Preferences/ByHost/ -name 'com.apple.loginwindow*' ! -size 0 -exec tee {} \; < /dev/null
	# set the user immutable flag
	find ~/Library/Preferences/ByHost/ -name 'com.apple.loginwindow*' -exec chflags uimmutable {} \;

.PHONY: init init-post-reboot brew-install brew-bundle asdf link-dotfiles link-karabiner macos sublime backup-preferences restore-preferences disable-restore-apps-on-login
