[![ci](https://github.com/nonrational/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/nonrational/dotfiles/actions/workflows/ci.yml)

## nonrational/dotfiles

_Architectural Digest_ for `$HOME`.

# Installation

## Any machine

```shell
curl -fsSL https://raw.githubusercontent.com/nonrational/dotfiles/main/setup.sh | bash
```

That is the whole sequence, for a new Mac, a Linux host, or a machine catching up after months. `setup.sh` clones this repo into `~/.dotfiles` if it has to, then runs every step whose end state does not already hold; re-run it any time with `./setup.sh` or `make setup` (`make setup ARGS=--dry-run` shows what a run would do). On a Mac it halts at three checkpoints, each printed with a number and the instruction to re-run when done:

1. The Command Line Tools installer, on a machine without them.
2. Full Disk Access for the terminal, which the `defaults` audit needs.
3. The reboot at the end.

The Dock reset and the iTerm, Amphetamine and Moom preference restore run only when `setup.sh` had to clone, so a re-run on an existing machine never wipes either. Linux runs only the submodule init and the deploy.

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
