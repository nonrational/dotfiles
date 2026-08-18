# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Public dotfiles (`nonrational/dotfiles`), deployed by symlinking `home/` entries into `$HOME` per the `manifest`. Once deployed, everything under `home/` is **live**: `~/.claude`, `~/.agents`, `~/.gemini`, `~/.copilot` and the shell rc files are symlinks back into this working tree, so edits take effect immediately and running tools write their runtime state inside the repo. The rules in `home/.agents/rules/` are loaded globally into every Claude Code session — do not restate them here or in code.

## Commands

- `make test` — full suite: `test/test_deploy.sh` + `test/test_shell.sh`. Run either script directly for one suite; both sandbox a throwaway `$HOME` under mktemp and never touch the real one.
- `./deploy.sh apply|audit [--dry-run]` — manifest-driven symlink deploy/verify. `make deploy` = apply plus re-asserting the skip-worktree flag (see Gotchas).
- `make check-symlinks` — fail on any dangling tracked symlink; `make check-skills` — same, scoped to `home/.agents/skills` (safe in CI); `make check-copilot-instructions` — self-heals the per-file mirror of rules into `home/.copilot/instructions/` (run after renaming anything in `home/.agents/rules/`); `make check-skill-frontmatter` — needs PyYAML.
- CI (`.github/workflows/ci.yml`) runs `make test`, a deploy apply+audit against a temp `$HOME`, and all the check targets, on macOS and ubuntu.

## Architecture

- **`manifest` + `deploy.sh`** — three whitespace columns: source, target, optional condition (`os=Darwin|Linux`, `host=<name>`, `tool=<name>`). deploy.sh is symlink-only by design: apply is `ln -s`, audit is a readlink comparison. Do not add copy/concat/generate behavior to it — that is a parked decision recorded in `docs/superpowers/specs/2026-07-06-manifest-deploy-spike-design.md`.
- **`home/.agents` is the source of truth for agent config** (rules + skills), shared across harnesses through symlink shims: `~/.claude/rules` and `~/.claude/skills` point into it, as does `home/.gemini/antigravity-cli/skills`. `home/.copilot/instructions/*.instructions.md` are per-file symlinks mirroring `home/.agents/rules/*.md` — a rename in rules dangles them silently, which is exactly what `check-copilot-instructions` and `check-skills` guard. Design and parked decisions: `docs/superpowers/specs/2026-07-16-agents-source-of-truth-design.md`.
- **Many skills are vendored, not local.** `home/.agents/ext/mattpocock-skills` is a git submodule; most entries in `home/.agents/skills/` are symlinks into it. Only the real directories there (e.g. `issue-sweep`, `ux-review`, `find-inspiration`, `prose-register`) are editable in this repo.
- **OS/host branching is by filename**: `.Darwin`/`.Linux` suffixes, `.bashrc.<hostname>`, `bin.Darwin` → `~/bin`. Shell is bash-first (Homebrew bash via `chsh`); zsh files exist but are secondary. Shell chain per window: `.bash_profile` → `.bashrc` → `.bashrc.<platform>` → `.bashrc.<host>`.
- **Design docs** live at `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` (plans in `docs/superpowers/plans/`). Specs record parked decisions — read the relevant one before restructuring the deploy or agents layout.

## Gotchas

- **Runtime state lands inside the repo.** Live tools write history, caches, and mutable settings into tracked directories. `home/.claude/.gitignore` is a default-deny allowlist; keep it that way and never stage blindly — a new untracked file here (queues, caches) may contain private-repo content that must not reach this public repo.
- **`home/.gemini/antigravity-cli/settings.json` is deliberately skip-worktree'd** (`make skip-mutable-settings`): Antigravity appends private workspace paths to its `trustedWorkspaces` key. To commit a deliberate settings change: `make unskip-mutable-settings`, stage everything except `trustedWorkspaces`, commit, re-skip.
- **Don't refactor live.** Broken symlinks or a bad rc edit break the live shell and agent config immediately. Per the README: for big refactors, use a separate clone or a worktree, not the deployed checkout.
- **Interactive shells auto-attach tmux** (end of `home/.bashrc.Darwin`): new iTerm/Terminal windows exec into tmux session `main`. The guards (interactive, `$TMUX`, `TERM_PROGRAM` allowlist, `CLAUDECODE`/`AI_AGENT` markers) keep scripts and agent shells out — preserve them when editing that file; `NO_TMUX=1` opts a shell out.
