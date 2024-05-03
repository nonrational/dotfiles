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

# close terminal
# grant iterm full disk access
# auth with 1password
# safari auth to github

# set modern bash as the default shell

if [ -f /opt/homebrew/bin/bash ]; then
    echo '/opt/homebrew/bin/bash' | sudo tee -a /etc/shells
    chsh -s '/opt/homebrew/bin/bash'
else
    echo 'Unable to set default shell to `/opt/homebrew/bin/bash`'
fi

make link-dotfiles
make link-karabiner
make restore-preferences

make macos-reset-dock
make macos-disable-restore-apps-on-login
make macos
# restart

# enable 1password shell integration / ssh agent
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
