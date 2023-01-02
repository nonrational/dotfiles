## Why?

Because storing cross-machine config is cumbersome. Installing Git is &mdash; for the most part &mdash; easy.

# Installation

## macOS

```shell
#!/usr/bin/env sh
xcode-select --install

git clone https://github.com/nonrational/dotfiles .dotfiles
cd .dotfiles
make init
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
