## Why?

Because storing cross-machine config is cumbersome. Installing Git is &mdash; for the most part &mdash; easy.

# Installation

## macOS

```shell
#!/usr/bin/env sh
xcode-select --install

git checkout https://github.com/nonrational/dotfiles .dotfiles
cd .dotfiles
make
```

## GNU/Linux

```shell
#!/usr/bin/env sh
git checkout git@github.com:nonrational/dotfiles .dotfiles
cd .dotfiles
make link-dotfiles
```

# Development

Since live-copies are symlinked out, just commit and push changes as necessary.

For big refactors, don't try to do it live. Clone a separate copy.
