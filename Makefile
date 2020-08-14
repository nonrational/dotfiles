init: install-homebrew brew-bundle link-dotfiles link-karabiner iterm2-install macos restart
post-reboot: sublime vscode-install

install-homebrew:
	curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh > homebrew-install.sh
	./homebrew-install.sh
	rm ./homebrew-install.sh

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

link-dotfiles:
	./link-dotfiles.sh

link-karabiner:
	mkdir -p $$HOME/.config
	ln -s $$PWD/karabiner $$HOME/.config/karabiner

macos:
	sh .macos

restart:
	osascript -e 'tell app "loginwindow" to «event aevtrrst»'

sublime:
	git clone https://github.com/nonrational/sublime3 $$HOME/.sublime3
	rm -rf $$HOME/Library/Application\ Support/Sublime\ Text\ 3
	ln -s $$HOME/.sublime3 $$HOME/Library/Application\ Support/Sublime\ Text\ 3

iterm2-backup:
	cp $$HOME/Library/Preferences/com.googlecode.iterm2.plist $$PWD/etc/com.googlecode.iterm2.plist
	git add $$PWD/etc/com.googlecode.iterm2.plist
	git commit -m 'iterm2-backup'

iterm2-install:
	cp $$PWD/etc/com.googlecode.iterm2.plist $$HOME/Library/Preferences/com.googlecode.iterm2.plist

vscode-backup:
	code --list-extensions > $$PWD/etc/vscode--list-extensions.txt

vscode-install:
	cat $$PWD/etc/vscode--list-extensions.txt | xargs -n 1 code --install-extension
