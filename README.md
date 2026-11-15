[![ci](https://github.com/nonrational/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/nonrational/dotfiles/actions/workflows/ci.yml)

## nonrational/dotfiles

_Architectural Digest_ for `$HOME`.

# Installation

```shell
curl -sS https://nonration.al/setup.sh | bash
```

## What `setup.sh` does

On a Mac, `setup.sh` will...

1. Install the Xcode Command Line Tools if they are missing.
2. Install Homebrew if missing, then run `brew bundle`.
3. Make Homebrew's bash your login shell (needs `sudo`).
4. Initialize git submodules.
5. Symlink `home/` into `$HOME` (`deploy.sh`).
6. Link the Karabiner and Sublime Text configs, load the clipboard bridge launch agent, and run `gh auth login`.
7. Turn off "reopen windows on login", then apply the macOS defaults table and `scripts/macos-bootstrap.sh`.
8. Reboot, only if this run applied the defaults for applications like iTerm, Amphetamine, and Moom.

On Linux, `setup.sh` initializes git submodules and deploys the `home/` symlinks.

### Checkpoints

A few steps along the way require human input. The script prints a numbered instruction, exits 1, and resumes when re-run.

1. Finish the Command Line Tools installer.
2. Grant Full Disk Access to your terminal (System Settings > Privacy & Security), then restart it. The defaults audit cannot read Safari or Mail settings without it.
3. Reboot, if the automatic restart fails.

A failed step prints `failed: <name>` and exits 2. Fix the cause and re-run.

### What it does not do

- Pull updates. It runs the checkout you have; `git pull` first to pick up new changes.
- Upgrade software beyond what `brew bundle` does.
- Support Intel Macs (the Homebrew path is `/opt/homebrew`) or Windows.
- Undo anything. `deploy.sh audit` and `make macos-audit` report drift without changing it.

# Clipboard bridge (exe.dev VMs)

`make clipboard-bridge` loads `org.nonrational.clipboard-bridge`, a socket-activated launch agent on `127.0.0.1:2224` that answers image requests from the pasteboard and nothing else. `home/.ssh/config.d/exe.conf` reverse-forwards that port into every `*.exe.xyz` session and shares connections between windows; add `Include config.d/*.conf` as the first line of `~/.ssh/config` once. Inside a VM, Claude Code's ctrl+v then pastes whatever image is on the mac clipboard. The VM half is the `wl-paste` shim in [nonreagent/dotfiles](https://github.com/nonreagent/dotfiles); design and trust model: [clipboard bridge design](https://github.com/nonreagent/dotfiles/blob/main/docs/superpowers/specs/2026-09-07-clipboard-bridge-design.md). The include is global, so OpenSSH's permission check on it gates every `ssh`: if they all start failing with `Bad owner or permissions on ~/.ssh/config.d/exe.conf`, `chmod 644` the repo's copy.

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
