# Fish interactive shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy a fish config and a two-line starship prompt through the existing symlink manifest, start fish in every local pane on the Mac, and leave bash and all remote hosts untouched.

**Architecture:** `home/.config/fish/` (linked as a directory, `tool=fish`) holds `config.fish`, `conf.d/`, and `functions/`. `home/.config/starship.toml` (linked `tool=starship`) is loaded by a guarded `conf.d/starship.fish`. Kitty and tmux start fish through conditional lines. A new `test/test_fish.sh` carries the tests, and `Makefile`'s `test` target runs it.

**Tech Stack:** fish 4.x, starship 1.27, tmux, kitty, bash test scripts (`test/*.sh` style), `deploy.sh` manifest.

**Spec:** `docs/superpowers/specs/2026-10-27-fish-interactive-shell-design.md` (research: `docs/superpowers/specs/2026-10-27-fish-prompt-research.md`).

## Global Constraints

- Bash rc files (`home/.bashrc*`, `home/.bash_profile`, `home/.profile`) must stay byte-identical to `origin/main`.
- No `chsh`; `$SHELL` stays bash. `deploy.sh` stays symlink-only.
- Manifest lines: `home/.config/fish  ~/.config/fish  tool=fish` and `home/.config/starship.toml  ~/.config/starship.toml  tool=starship`.
- `home/.config/fish/.gitignore` is default-deny, so `fish_variables` and any other runtime file stay untracked.
- Starship config: plain symbols (no Nerd Font), two lines (context, then bare input line), copied from the spike's `two-line.toml`.
- No employer, project, or account identifiers anywhere in the repo, commits, or PR text. The private port lives only in `~/.local/config.fish`, untracked.
- Prose and comments: no "just", "simply", "gate"; no em-dash asides; comments say why.
- Commits: plain subjects, no `fix:`-style prefixes, `Co-Authored-By` trailer from the session's attribution line.

## Review Focus

- Fish present, starship absent: interactive startup prints nothing and the prompt is fish's default (Task 3 test).
- Fish launched with kitty's minimal GUI `PATH` (no `/opt/homebrew/bin`): `conf.d/00-path.fish` still puts Homebrew first, so `starship` resolves (Task 3 test).
- `~/.config/fish.bak` already exists at deploy time: `deploy.sh` skips with an error and changes nothing; the plan checks for it before applying (Task 1 step 5, Task 6 step 3).
- tmux on a host with no fish: config loads clean and `default-shell` stays `$SHELL` (Task 5 test).
- `./bin` stays first on `PATH` relative to the current directory (Task 2 test).

## File Structure

- Create `home/.config/fish/config.fish`: interactive guard, local hook, `op` completion, `./bin` first on PATH. PATH and exports live in `conf.d/00-path.fish` as built (see "As built").
- Create `home/.config/fish/conf.d/aliases.fish`, `darwin.fish`, `host-nyx.fish`, `starship.fish`.
- Create `home/.config/fish/functions/{prpg,reset_known_host,scutil_set_hostname}.fish`.
- Create `home/.config/fish/.gitignore`, `home/.config/starship.toml`.
- Create `test/test_fish.sh`; modify `Makefile` (`test` target) and `manifest`, `Brewfile`, `home/.tmux.conf`, `home/.config/kitty/kitty.conf`, `test/test_tmux.sh`.

## Task 0: Branch and land the finished edits

The checkout is live, so work happens on a branch in place: symlinks follow the working tree.

**Files:** `home/.tmux.conf`, `home/.config/kitty/kitty.conf`, the two spec docs, this plan.

- [ ] **Step 1:** `git fetch origin && git switch -c fish-interactive-shell origin/main` (a dirty tree carries over). Verify: `git log --oneline origin/main..HEAD` is empty.
- [ ] **Step 2:** Commit the design, research, and plan docs. Subject: `Add fish interactive shell design, research and plan`.
- [ ] **Step 3:** Commit only the `C-k` hunk of `home/.tmux.conf` (`git add -p`; the `bind-key J` hunk belongs to the owner and stays unstaged). Subject: `Move tmux clear-history to prefix C-k so the shell receives Ctrl+K`.
- [ ] **Step 4:** Commit `home/.config/kitty/kitty.conf` alone. Subject: `Let kitty send Option as Alt so shell Alt bindings work`. Leave `home/.claude/settings.json` unstaged.

## Task 1: Test harness and fish skeleton

**Files:** Create `test/test_fish.sh`, `home/.config/fish/config.fish`, `home/.config/fish/.gitignore`; modify `Makefile`, `manifest`.

**Produces:** `fake_fish_home()` in `test_fish.sh` (a throwaway `$HOME` with `.config/fish` linked to the repo and a `bin` dir of stubs); `run_fish <PATH> <cmd>` (runs `fish -ic` with a controlled `PATH`, output in `$got`, status in `$status`); `ok`/`bad`/`skip` helpers copied from `test_shell.sh`.

- [ ] **Step 1:** Write `test_fish.sh` with `test_config_parses`: `fish --no-execute` over every `*.fish` under `home/.config/fish`, asserting exit 0. Skip cleanly when fish is not installed, like `test_tmux.sh`.
- [ ] **Step 2:** Run `./test/test_fish.sh`. Expected: FAIL (no files yet).
- [ ] **Step 3:** Create `config.fish` with an empty `status is-interactive` block, and the default-deny `.gitignore` (`*`, then `!` entries for `.gitignore`, `config.fish`, `conf.d/`, `functions/`, `completions/` and their `*.fish`, modeled on `home/.claude/.gitignore`).
- [ ] **Step 4:** Add the fish manifest line, add `./test/test_fish.sh` to the `test` target, run `make test`. Expected: all pass.
- [ ] **Step 5:** Run `ls ~/.config/fish.bak` (must not exist) then `./deploy.sh apply --dry-run`; expected: it reports backing up `~/.config/fish` and linking. Do not apply yet.
- [ ] **Step 6:** Commit. Subject: `Add fish config skeleton, manifest link and test harness`.

## Task 2: Port PATH, exports, aliases, functions

**Files:** Modify `config.fish`; create `conf.d/aliases.fish`, `conf.d/darwin.fish`, `functions/prpg.fish`, `functions/reset_known_host.fish`, `functions/scutil_set_hostname.fish`; modify `test/test_fish.sh`.

Source of truth for what to port: `home/.bash_profile` (PATH list), `home/.bashrc` (aliases, `prpg`, `reset_known_host`), `home/.bashrc.Darwin` (exports, `ls` alias, `GEM_HOME`, `ulimit`, `scutil_set_hostname`). Dropped by design: `TERM`, `parse_git_branch`, `uber_prompt`, history and `shopt` settings.

- [ ] **Step 1: Tests first** in `test_fish.sh`, each with its assertion:
  - `test_path_order`: with `PATH=/usr/bin:/bin`, `fish -ic 'echo $PATH[1]'` prints `./bin`, and `/opt/homebrew/bin` appears before `/usr/bin` when that directory exists (skip the second assertion where it does not).
  - `test_functions_defined`: `functions -q prpg reset_known_host` succeeds; on Darwin `functions -q scutil_set_hostname` too.
  - `test_prpg_length`: `prpg 20` prints 20 characters, none of `/+=`.
  - `test_aliases`: `alias` output contains `ll`, `la`, `l`, `rm`, `df`, `du`, `grep`, `hist`, `psa`, `cdate`.
  - `test_editor_exports` (Darwin only): `$EDITOR` is `subl -w -n` and `$VISUAL` equals it.
- [ ] **Step 2:** Run; expected: FAIL on each.
- [ ] **Step 3:** Implement. `./bin` goes first with `set -gx PATH ./bin $PATH` because `fish_add_path` makes relative paths absolute (verified in `fish_add_path --help`). The other PATH entries use `fish_add_path --move --path`. Function names and arities match the bash originals; `prpg` defaults to 16. Darwin items live in `conf.d/darwin.fish` behind `test (uname) = Darwin`. Set `VISUAL` as well as `EDITOR`.
- [ ] **Step 4:** Run `make test`. Expected: PASS.
- [ ] **Step 5:** Commit. Subject: `Port PATH, exports, aliases and helper functions to fish`.

## Task 3: Starship prompt

**Files:** Create `home/.config/starship.toml`, `conf.d/starship.fish`; modify `manifest`, `test/test_fish.sh`.

- [ ] **Step 1: Tests first:**
  - `test_starship_absent`: with `PATH` lacking starship, `fish -ic exit` prints nothing to stdout or stderr and `fish_prompt` is fish's own.
  - `test_starship_present`: with a stub `starship` on `PATH` (a script that prints `STUB` for `prompt` and a no-op init for `init fish`), `fish_prompt` output contains `STUB`.
  - `test_starship_toml_valid`: if `starship` is installed, `STARSHIP_CONFIG=home/.config/starship.toml starship prompt` exits 0.
- [ ] **Step 2:** Run; expected: FAIL.
- [ ] **Step 3:** Copy the spike's `two-line.toml` (scratchpad `prompt-spike/`) to `home/.config/starship.toml` unchanged. `conf.d/starship.fish` runs `starship init fish | source` only when `status is-interactive` and `command -q starship`. Add the starship manifest line.
- [ ] **Step 4:** Run `make test`. Expected: PASS. Also run `./test/test_deploy.sh` unchanged. Expected: PASS.
- [ ] **Step 5:** Commit. Subject: `Add a two-line starship prompt for fish, loaded only when installed`.

## Task 4: Host file, local hook, op completion

**Files:** Create `conf.d/host-nyx.fish`; modify `config.fish`, `test/test_fish.sh`.

- [ ] **Step 1: Tests first:**
  - `test_local_hook`: a `$HOME/.local/config.fish` containing `set -gx LOCAL_HOOK_RAN 1` is sourced; absent file causes no output.
  - `test_host_file_inert`: with `uname -n` not `nyx` (stub `uname` on `PATH` printing another name), `SSH_AUTH_SOCK` is unchanged.
  - `test_op_completion_guarded`: with no `op` on `PATH`, startup prints nothing.
- [ ] **Step 2:** Run; expected: FAIL.
- [ ] **Step 3:** Port `home/.bashrc.nyx` (the ssh agent socket, `op` plugin aliases, cargo and postgres PATH) into `conf.d/host-nyx.fish`, guarded by the host id (`string replace -r '\.(lan|local)$' '' (uname -n)` equals `nyx`). Skip `_have` (bash-completion helper). In `config.fish`: `op completion fish | source` behind `command -q op`; last line `test -r ~/.local/config.fish; and source ~/.local/config.fish`.
- [ ] **Step 4:** Run `make test`. Expected: PASS.
- [ ] **Step 5:** Commit. Subject: `Add fish host file, local config hook and op completion`.

## Task 5: Start fish in kitty and tmux

**Files:** Modify `home/.config/kitty/kitty.conf`, `home/.tmux.conf`, `test/test_tmux.sh`.

- [ ] **Step 1: Tests first** in `test_tmux.sh`, following its `y_binding`-style helper: `test_default_shell_fish_present` (a stub `fish` on `PATH`; after load, `show-options -gv default-shell` equals the stub's absolute path) and `test_default_shell_fish_absent` (no fish; `default-shell` equals `$SHELL`). `run-shell` without `-b` blocks the command queue, so one `show-options` read after the load sees the final value.
- [ ] **Step 2:** Run `./test/test_tmux.sh`. Expected: FAIL on the present case.
- [ ] **Step 3:** In `home/.tmux.conf`, replace the unconditional `set -g default-shell $SHELL` with a form that sets it to fish's absolute path only when `command -v fish` succeeds (tmux needs an absolute path; `run-shell` with `$(command -v fish)` is the likely mechanism). Keep `$SHELL` as the fallback. In `kitty.conf` set `shell` to Homebrew's absolute fish path (`/opt/homebrew/bin/fish`), because kitty launched from the Dock does not inherit your shell `PATH` (reason unverified: confirm by launching kitty from the Dock). Wrap it so a missing fish falls back to bash; the builder chooses the wrapper form and records why.
- [ ] **Step 4:** Run `make test`. Expected: PASS. Reload kitty (Cmd+Ctrl+,) and open a window; `echo $fish_pid` prints a number.
- [ ] **Step 5:** Commit. Subject: `Start fish in kitty and tmux panes when installed`.

## Task 6: Brewfile and live deploy

**Files:** Modify `Brewfile`.

- [ ] **Step 1:** Add `brew "fish"` and `brew "starship"` with one-line comments, matching the file's alignment.
- [ ] **Step 2:** `make preflight`. Expected: pass. If `editorconfig-checker` flags fish files, format with two-space indent (the repo's `.editorconfig` default) and note that `fish_indent` defaults to four.
- [ ] **Step 3:** `make deploy`, then `./deploy.sh audit`. Expected: audit clean; `~/.config/fish.bak` holds the old stub directory.
- [ ] **Step 4:** Verify bash is untouched: `git diff origin/main --stat -- 'home/.bash*' home/.profile` prints nothing.
- [ ] **Step 5:** Commit. Subject: `Install fish and starship from the Brewfile`.

## Task 7: Private local port (not committed)

Write `~/.local/config.fish` from `~/.local/.bashrc`. It stays outside this repo.

- [ ] **Step 1:** Port by category: env vars (`set -gx`), PATH prepends (`fish_add_path`), aliases, the CA-bundle block (`if not test -s ...; begin ...; end > file; end`), and the helper functions (`pushd`/`popd` in place of subshells, `env VAR=(...) cmd` in place of inline assignment). Drop the bash pnpm completion; use `pnpm completion fish | source` behind `command -q pnpm` (command unverified). The `op` plugin file is two lines (an exported flag and an `aws` alias); port them by hand.
- [ ] **Step 2:** The private file's `eval`-based credential helper becomes a fish function that pipes its helper script's fish-mode output into `source`. The script already has a tested `--fish` mode (outside this repo); take the exact function from the owner's private notes.
- [ ] **Step 3:** Verify: `fish --no-execute ~/.local/config.fish`, then open a fish shell and confirm `functions -q` on the credential helper function and a spot-check of three variables.
- [ ] **Step 4 (leak check before any push):** build a grep pattern from the identifiers in `~/.local/.bashrc` (employer, project, account IDs, vault and item names) and confirm `git diff origin/main` and every commit message match nothing.

## Wrap-up

- [ ] Run `make preflight` once more, push the branch, and open the PR with the four-section body from the global rules: the issue line first (`Part of #29`, because the exe-host and bash prompt questions remain), then Problem, Motivation, Proposed Solution, Feedback. Grep the body and commit messages for private identifiers before pushing. Prune no worktree (none was used).

## Self-review notes

- Spec coverage: fish port (Tasks 1, 2), starship guarded (3), host/local hook/op completion (4), kitty+tmux start-up no-op where missing (5), Brewfile and untouched bash (6), private port (7).
- Deviation from the spec's example commit series: tests travel with the code they check, so commits are (docs, tmux fix, kitty option, skeleton, port, starship, host and hook, start-up, Brewfile). The spec left the series to the builder.
- Unverified in this plan: kitty's `PATH` when launched from the Dock; the exact tmux mechanism for an absolute `default-shell`; `pnpm completion fish`.

## As built

- PATH moved into `conf.d/00-path.fish` and folded into Task 3. `conf.d` files load before `config.fish`, and starship needs the full PATH to resolve under kitty's minimal GUI PATH. `config.fish` keeps the local hook and the `./bin` line, which runs after every `conf.d` file.
- Kitty: `kitty.conf` includes `fish-shell.sh` through `geninclude`, which prints the `shell` line only when the Homebrew fish is executable. `test/test_kitty.sh` covers it.
- `prpg` prints exactly N characters (oversampled, then `head -c N`), where bash printed a variable length.
- The live deploy hand-linked `~/.config/fish` and `~/.config/starship.toml` in place of `make deploy`, because `deploy.sh apply` also reported two unrelated pending manifest links that were left unapplied.
- tmux: a `run-shell` with a `case` on an absolute path sets `default-shell`; it replaced the `if-shell` idea, and the run-shell blocks the command queue so the override lands before the first pane.
