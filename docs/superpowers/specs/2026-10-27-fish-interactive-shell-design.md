# Fish as an interactive shell, with a shared starship prompt

Part of issue #29. Supporting research: `docs/superpowers/specs/2026-10-27-fish-prompt-research.md`.

## Intent

The owner is happy with bash and wants more interactive ergonomics: better completion, spell correction, better history, and sturdier line editing. Fish supplies those without plugin management. Bash stays the login shell and the shell for scripts, agents, and hooks; fish is what a terminal window starts.

A second goal rides along: a fish prompt, built with starship, that shows git branch and dirty state on a clean two-line layout.

## Goals

- A fish config deployed through the existing `manifest`, covering what `.bash_profile`, `.bashrc`, and `.bashrc.Darwin` set up today: PATH, exports, aliases, and the helper functions.
- One tracked `starship.toml` (two-line layout, plain symbols), loaded by fish only when starship is installed.
- Every local pane (kitty windows and tmux panes on the Mac) starts fish.
- Zero change in behavior for any host that lacks fish or starship.

## Non-goals

- No `chsh` to fish on any machine. `$SHELL` stays bash.
- No port of `bin.Darwin` scripts, `.githelpers`, or git aliases. They stay bash.
- No tide, hydro, or pure. Research found them fish-only; starship is the only candidate that serves both shells from a plain TOML file.
- No starship (and no other change) in bash. The bash prompt, including `uber_prompt`, stays as it is, so exe hosts and ssh sessions see no difference.
- No agent-aware prompt segment in this change (see "Left to later").
- No zsh work (issue #9 is a separate spike).

## Anti-goals

- A bash startup that errors, warns, or slows on a host without starship.
- A deploy mechanism change. `deploy.sh` stays symlink-only (parked decision in `2026-07-06-manifest-deploy-spike-design.md`).
- Any edit that breaks a running bash process or the downstream @nonreagent hosts, which redeploy this repo on their own schedule and keep bash.

## Constraints

- Repo is live: `~/.claude`, `~/.config/*`, and the rc files are symlinks into this checkout. Changes must be additive.
- `deploy.sh` supports `os=`, `host=`, and `tool=` conditions on a manifest line. `tool=<name>` is true when `command -v <name>` succeeds. The fish and starship lines use it, so a host without the tool skips the link.
- Fish writes runtime state (`fish_variables`) into `~/.config/fish/`. `home/.config/fish/.gitignore` must exclude it, in keeping with the repo's rule that runtime state never lands in tracked files.
- `~/.config/fish/` already exists on the owner's Mac as a real directory holding fish's stub `config.fish`, with no symlink. `deploy.sh apply` already handles this: it renames an existing real path to `<target>.bak` and links over it, and it errors without touching the path when `<target>.bak` exists. The plan must check for an existing `~/.config/fish.bak` first.
- Prompt must work without a Nerd Font.
- Repo prose rules apply to comments and docs: no "just"/"simply", no "gate", no em-dash asides, backtick `snake_case` identifiers.

## Decisions (the owner's, as stated)

- Bash remains the login shell. Exe hosts for @nonreagent keep bash for now.
- The prompt is the two-line starship layout from the spike: line one carries directory, git branch, git status, and command duration; line two is the bare input line.
- Alt+E (edit line in `$EDITOR`) works in fish through kitty's `macos_option_as_alt yes`, already applied.
- The tmux root-table `C-k` binding is removed (done in `home/.tmux.conf`); clear-history lives at `C-a C-k`.
- Work happens live in this checkout, additively.
- **Fish starts in every local pane:** kitty's `shell` setting and tmux's `default-shell` both point at fish. Bash stays the login shell and `$SHELL`.
- **Exe hosts and phone ssh sessions keep bash and its current prompt.** Starship is configured from a fish `conf.d/` file that loads only when starship is present, and nothing in the bash files changes.

## Decisions (my calls, for the owner to check)

- **Starship loads from `conf.d/starship.fish`**, guarded by `command -v starship` and by `status is-interactive`, so a host with fish but no starship gets fish's default prompt. The PATH block lives in `conf.d/00-path.fish`, because `conf.d` files load before `config.fish` and starship must resolve under a minimal GUI PATH.
- **Fish start-up must no-op where fish is missing.** `home/.tmux.conf` is deployed to every host, including exe hosts, so the `default-shell` change is conditional and resolves fish's absolute path at runtime, because tmux needs one. As built, a `run-shell` (which blocks the command queue, so the override lands before the first pane) runs a `case` on the absolute path from `command -v fish`; no `if-shell`. Kitty's `shell` line comes from `geninclude fish-shell.sh`, which prints it only when the Homebrew fish is executable, so a Mac without fish keeps kitty's default shell.
- **Helper functions** (`prpg`, `reset_known_host`, `scutil_set_hostname`) move to `functions/*.fish`, one per file. `parse_git_branch` is dropped (starship replaces it). `TERM=xterm-color` is dropped in fish. Also not ported: autojump (`j`) and the `HOMEBREW_ROOT` export from `.bash_profile` (owner to decide whether to port autojump).
- **OS and host branching** moves from filename suffixes to guarded `conf.d/` files (`darwin.fish`, `host-<name>.fish`), derived the way `scripts/host-id.sh` does.
- **Aliases** are ported as `alias` first. Converting to `abbr` is a later taste decision.
- **Prompt width:** directory truncation is two to three components. Starship's `hostname` module shows only in ssh sessions by default; that matters only if fish runs over ssh later.
- **Fish directory link:** the manifest links the whole `home/.config/fish` directory (kitty precedent), with a default-deny `.gitignore` like `home/.claude/.gitignore`, so `fish_variables` and any other runtime file stay untracked. Fish's generated completions live under `~/.cache/fish/` (`__fish_cache_dir` in fish 4.9; unverified for other versions), outside this directory.
- **Host file:** `home/.bashrc.nyx` exists today (1Password ssh agent, `op` plugin wrappers, cargo and postgres on PATH), so `conf.d/host-nyx.fish` ports those lines. The current Mac's hostname is not `nyx`, so the builder must not assume that file runs on the owner's laptop.
- **Local escape hatch:** `config.fish` ends with `test -r ~/.local/config.fish; and source ~/.local/config.fish`, the fish counterpart of the `~/.local/.bashrc` hook. The owner's private bash file (a symlink to a work-specific directory outside this repo) holds employer-specific env vars, account identifiers, and helper functions. Its fish port stays untracked and never enters this public repo. It needs a separate pass, because several pieces are bash syntax (see the port inventory in the session notes): the CA-bundle block, and the subshell and `eval` helpers. The 1Password plugin wrapper file (`~/.config/op/plugins.sh`) is two lines today (an exported flag and an `aws` alias), so it ports by hand; `op completion fish | source` covers completions. `op plugin init` regenerates that file, and whether it also writes a fish variant is unverified.
- **Test matrix:** fish present or absent crossed with starship present or absent, run under a sandbox `$HOME` and a stripped `PATH`.
- **Bash prompt glitch stays open.** Since bash is untouched, the long-line Ctrl+K/Ctrl+U glitch seen outside tmux is not addressed here. The tmux Ctrl+K cause is fixed; any remaining cause (`TERM=xterm-color`, the `\001`/`\002` prompt codes) is a separate, small change.
- **Brewfile** gains `fish` and `starship` (macOS only).
- **Prompt config location:** `home/.config/starship.toml`, linked to `~/.config/starship.toml`.

## Left to the builder

- Whether a second, thinner config (selected when `$SSH_CONNECTION` is set) is worth it, or whether one config with truncation is thin enough. Start with one.
- How to test: a case in `test/` that proves the fish config parses (`fish --no-execute`), the manifest links resolve under a sandbox `$HOME`, `tmux.conf` loads cleanly with and without fish on `PATH`, and the bash rc files are byte-identical to before (the guarantee that bash is untouched).
- Exact `starship.toml` styling, within the plain-symbol rule.
- Commit series: the plan should name atomic commits, for example (1) fish config and starship config, (2) manifest and tests, (3) kitty and tmux start-up, (4) Brewfile.

## Left to later

- Agent segment. Findings: `CLAUDECODE` is set only for processes Claude Code spawns, not in the outer shell, and no prompt project documents an agent segment. A `claude` wrapper function that sets a marker is the likeliest route.
- A Ctrl+C bell at an empty prompt (`bind ctrl-c` wrapper, unverified at a live prompt).
- Autosuggestion and history tuning, fzf and zoxide setup in fish.
- Moving the exe hosts to fish.
