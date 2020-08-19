init: brew-install brew-bundle link-dotfiles link-karabiner macos
	osascript -e 'tell app "loginwindow" to «event aevtrrst»'

init-post-reboot: asdf link-sublime link-vscode restore-preferences

brew-install:
	curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash

brew-bundle:
	brew update
	brew bundle

asdf:
	asdf plugin-add golang
	asdf install golang 1.14.7

	asdf plugin-add ruby
	asdf install ruby 2.7.1

	asdf plugin-add elixir
	asdf install elixir 1.10.4

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
	rm -rf $$HOME/Library/Application\ Support/Sublime\ Text\ 3
	ln -s $$HOME/.sublime3 $$HOME/Library/Application\ Support/Sublime\ Text\ 3

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
	cat $$PWD/etc/vscode--list-extensions.txt | xargs -n 1 code --install-extension


.PHONY: init init-post-reboot brew-install brew-bundle asdf link-dotfiles link-karabiner macos sublime backup-preferences restore-preferences
