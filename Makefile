SHELL := /bin/bash

default:
	@echo "Cowardly refusing to run on $(shell uname). Use platform specific targets."

brew-install:
	/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew-bundle:
	/opt/homebrew/bin/brew shellenv > /tmp/brew-shell.env
	source /tmp/brew-shell.env && which brew && brew update && brew bundle

macos:
	sh .macos
	osascript -e 'tell app "loginwindow" to «event aevtrrst»'

macos-reset-dock:
	defaults write com.apple.dock persistent-apps -array
	killall Dock

# .claude rules are mirrored by per-file symlinks in .copilot/instructions and
# dir symlinks in .gemini/antigravity-cli — renames in .claude/rules break the
# copilot links silently, so fail fast on any dangling tracked symlink.
check-symlinks:
	@broken=$$(git ls-files -z | while IFS= read -r -d '' f; do \
		[ -L "$$f" ] && [ ! -e "$$f" ] && echo "$$f"; \
	done; true); \
	if [ -n "$$broken" ]; then \
		echo "[error] broken symlinks:"; \
		echo "$$broken" | sed 's/^/  /'; \
		exit 1; \
	fi
	@echo "all tracked symlinks resolve"

link-dotfiles:
	mkdir -p $$HOME/.local
	./link-dotfiles.sh

# Ensures .copilot/instructions/*.instructions.md (per-file symlinks required by
# the Copilot CLI's *.instructions.md filename suffix) mirror
# .claude/rules/*.md 1:1 — both historical breaks (f820754, 0d4743e) were renames
# in .claude/rules/ that silently dangled or orphaned these links.
check-copilot-instructions:
	@mkdir -p .copilot/instructions; \
	changed=0; \
	for rule in .claude/rules/*.md; do \
		[ -f "$$rule" ] || continue; \
		name=$$(basename "$$rule" .md); \
		link=".copilot/instructions/$$name.instructions.md"; \
		if [ ! -L "$$link" ] || [ "$$(realpath "$$link" 2>/dev/null)" != "$$(realpath "$$rule")" ]; then \
			echo "[fix] symlinking $$link -> $$rule"; \
			rm -f "$$link"; \
			ln -s "../../$$rule" "$$link"; \
			changed=1; \
		fi; \
	done; \
	for link in .copilot/instructions/*.instructions.md; do \
		[ -L "$$link" ] || continue; \
		rule=".claude/rules/$$(basename "$$link" .instructions.md).md"; \
		if [ ! -f "$$rule" ]; then \
			echo "[fix] removing orphaned symlink $$link"; \
			rm -f "$$link"; \
			changed=1; \
		fi; \
	done; \
	if [ "$$changed" -eq 1 ]; then \
		if [ -n "$$CI" ]; then \
			echo "[error] copilot instructions were out of sync. failing CI."; \
			exit 1; \
		else \
			echo "copilot instructions were updated. please commit the changes."; \
		fi; \
	else \
		echo "copilot instructions mirror .claude/rules"; \
	fi

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
	defaults export com.manytricks.Moom $$PWD/etc/com.manytricks.Moom.plist

restore-preferences:
	@mkdir -p $$HOME/Library/Preferences/
	cp $$PWD/etc/com.googlecode.iterm2.plist $$HOME/Library/Preferences/com.googlecode.iterm2.plist
	@mkdir -p $$HOME/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/
	cp $$PWD/etc/com.if.Amphetamine.plist $$HOME/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/com.if.Amphetamine.plist
	defaults import com.manytricks.Moom $$PWD/etc/com.manytricks.Moom.plist

macos-disable-restore-apps-on-login:
	# See https://apple.stackexchange.com/a/322787
	# clear the file if it isn't empty
	find ~/Library/Preferences/ByHost/ -name 'com.apple.loginwindow*' ! -size 0 -exec tee {} \; < /dev/null
	# set the user immutable flag
	find ~/Library/Preferences/ByHost/ -name 'com.apple.loginwindow*' -exec chflags uimmutable {} \;

set-file-associations:
	./scripts/set-file-associations.sh

init-submodules:
	git submodule update --init --recursive

# grep '^\w' Makefile | sed 's/:.*//g' | tr '\n' ' ' | pbcopy
.PHONY: default macos-setup init-post-reboot brew-install brew-bundle macos-reset-dock macos check-symlinks check-copilot-instructions link-dotfiles link-karabiner link-sublime backup-preferences restore-preferences disable-restore-apps-on-login set-file-associations
