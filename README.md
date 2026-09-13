[![ci](https://github.com/nonrational/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/nonrational/dotfiles/actions/workflows/ci.yml)

## nonrational/dotfiles

_Architectural Digest_ for `$HOME`.

# Installation

## macOS

```shell
#!/usr/bin/env sh
xcode-select --install

git clone https://github.com/nonrational/dotfiles .dotfiles
cd .dotfiles

make brew-install
make brew-bundle

if [ -f /opt/homebrew/bin/bash ]; then
  echo '/opt/homebrew/bin/bash' | sudo tee -a /etc/shells
  chsh -s '/opt/homebrew/bin/bash'
else
  echo 'Unable to set default shell to `/opt/homebrew/bin/bash`'
fi

# Better get a new terminal at this point.
make init-submodules
make deploy
make link-karabiner

# Authenticate with `gh` to clone private repo(s)
gh auth login
make link-sublime
make restore-preferences

# Almost there! Good idea to restart iTerm now, and take the opportunity to
# ensure it has full disk access.
make macos-reset-dock
make macos-disable-restore-apps-on-login
make macos
```

## GNU/Linux

```shell
#!/usr/bin/env sh

git clone git@github.com:nonrational/dotfiles .dotfiles
cd .dotfiles

make init-submodules
make deploy
```

# Development

Since live-copies are symlinked out, commit and push changes as necessary.

For big refactors, don't try to do it live; use a separate clone or worktrees.

# Credits

People whose good work I've borrowed, curated via [`/find-inspiration`](home/.agents/skills/find-inspiration/SKILL.md).

- <a href="https://github.com/alexknowshtml"><img src="https://github.com/alexknowshtml.png?size=64" width="20" height="20" align="absmiddle" alt=""></a> **Alex Hillman** · [alexknowshtml/claude-skills](https://github.com/alexknowshtml/claude-skills)
- <a href="https://github.com/chriskempson"><img src="https://github.com/chriskempson.png?size=64" width="20" height="20" align="absmiddle" alt=""></a> **chriskempson** · [chriskempson/tomorrow-theme](https://github.com/chriskempson/tomorrow-theme)
- <a href="https://github.com/jessfraz"><img src="https://github.com/jessfraz.png?size=64" width="20" height="20" align="absmiddle" alt=""></a> **Jess Frazelle** · [jessfraz/dotfiles](https://github.com/jessfraz/dotfiles)
- <a href="https://github.com/obra"><img src="https://github.com/obra.png?size=64" width="20" height="20" align="absmiddle" alt=""></a> **Jesse Vincent** · [obra/dotfiles](https://github.com/obra/dotfiles)
- <a href="https://github.com/webpro"><img src="https://github.com/webpro.png?size=64" width="20" height="20" align="absmiddle" alt=""></a> **Lars Kappert** · [webpro/dotfiles](https://github.com/webpro/dotfiles)
- <a href="https://github.com/mattpocock"><img src="https://github.com/mattpocock.png?size=64" width="20" height="20" align="absmiddle" alt=""></a> **Matt Pocock** · [mattpocock/skills](https://github.com/mattpocock/skills)
- <a href="https://github.com/paulirish"><img src="https://github.com/paulirish.png?size=64" width="20" height="20" align="absmiddle" alt=""></a> **Paul Irish** · [paulirish/dotfiles](https://github.com/paulirish/dotfiles)
- <a href="https://github.com/samandmoore"><img src="https://github.com/samandmoore.png?size=64" width="20" height="20" align="absmiddle" alt=""></a> **Sam Moore** · [samandmoore/dotfiles](https://github.com/samandmoore/dotfiles)
