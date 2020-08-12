all: brew asdf link-dotfiles sublime iterm2 karabiner macos restart

brew:
	command -v brew || /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
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

sublime:
	git clone https://github.com/nonrational/sublime3 $$HOME/.sublime3
	rm -rf $$HOME/Library/Application\ Support/Sublime\ Text\ 3
	ln -s $$HOME/.sublime3 $$HOME/Library/Application\ Support/Sublime\ Text\ 3

iterm2:
	cp ./etc/com.googlecode.iterm2.plist $$HOME/Library/Preferences/com.googlecode.iterm2.plist

karabiner:
	# assumes we're in ~/.dotfiles
	ln -s $$HOME/.dotfiles/karabiner $$HOME/.config/karabiner

macos:
	sh .macos

restart:
	osascript -e 'tell app "loginwindow" to «event aevtrrst»'
