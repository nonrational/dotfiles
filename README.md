## Why?

Because storing cross-machine config is cumbersome. Installing Git is &mdash; for the most part &mdash; easy.

# Installation

## macOS

```shell
#!/usr/bin/env sh
xcode-select --install

git clone https://github.com/nonrational/dotfiles .dotfiles
cd .dotfiles

make brew-install
make brew-bundle

# set modern bash as the default shell
(($(grep bash /etc/shells | wc -l)<2)) && which -a bash | head -n1 | sudo tee -a /etc/shells
chsh -s $(which -a bash | head -n1)

make link-dotfiles
make link-karabiner
make restore-preferences

make macos-reset-dock
make macos-disable-restore-apps-on-login
make macos
```

## GNU/Linux

```shell
#!/usr/bin/env sh

git clone git@github.com:nonrational/dotfiles .dotfiles
cd .dotfiles

make link-dotfiles
```

# Development

Since live-copies are symlinked out, commit and push changes as necessary.

For big refactors, don't try to do it live. Clone a separate copy.
