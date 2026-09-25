# One setup command for a Mac, and one for an exe box

**Issue:** [#28](https://github.com/nonrational/dotfiles/issues/28) \
**Date:** 2026-09-25 \
**Status:** design, awaiting review

## Problem

Bringing a machine to the state this repo describes means executing the README's shell block by hand, in order, and knowing which lines to skip on a re-run. Nothing but prose encodes the ordering, five of the make targets fail when run twice, and two of them are destructive on every run after the first. The same shape repeats downstream: an exe.dev VM for @nonreagent is a clone, `./install.sh`, and two prose steps.

The spike question the issue asked: which of the README's steps are genuinely idempotent, and can the rest be expressed as checkpoints that print and halt rather than steps that silently no-op? If the checkpoint set is small, a single setup command is honest.

## Spike findings

Every README step, classified from the Makefile and probed on this machine (macOS 26.6.2).

| Step | Bucket | Evidence |
|---|---|---|
| `xcode-select --install` | checkpoint | Opens a GUI installer; exits 1 once installed. Guard: `xcode-select -p`. |
| `git clone` | n/a | The script runs from the clone. |
| `make brew-install` | idempotent with guard | Skip when `/opt/homebrew/bin/brew` exists. |
| `make brew-bundle` | idempotent | `brew bundle` converges. |
| `/etc/shells` + `chsh` | idempotent with guard | Check the file and `dscl . -read ~ UserShell`. Needs sudo, not a human. |
| "get a new terminal" | not a step | Only puts `brew` on PATH. `eval "$(brew shellenv)"` in-script replaces it. |
| `make init-submodules` | idempotent | |
| `make deploy` | idempotent | `deploy.sh audit` already proves convergence. |
| `make link-karabiner` | idempotent with guard | Bare `ln -s` fails on re-run today. |
| `make clipboard-bridge` | idempotent | bootout, then bootstrap. |
| `gh auth login` | interactive, inline | Guard: `gh auth status`. Runs on `/dev/tty`; no halt. |
| `make link-sublime` | idempotent with guard | `git clone` fails on re-run today. |
| `make restore-preferences` | first run only | Clobbers live iTerm, Amphetamine and Moom preferences. |
| restart iTerm, grant Full Disk Access | checkpoint | `make macos-doctor` detects the FDA half and halts. |
| `make macos-reset-dock` | first run only | Wipes the Dock on every run. |
| `make macos-disable-restore-apps-on-login` | idempotent | Re-run's `tee` fails against the immutable file, cosmetically. |
| `make macos` | idempotent, ends in a checkpoint | Table apply converges; `scripts/macos-bootstrap.sh` is re-runnable; the reboot ends the run. |

**Answer.** Three checkpoints halt the run: the Command Line Tools installer, Full Disk Access, and the reboot. Five targets need a guard. Two steps are first-run-only and destructive. Everything else converges. That is a small checkpoint set, so the command is honest.

Two things the issue did not anticipate. The dependency graph is shallow: brew before bundle, bundle before `set-shell` and before any brew-installed tool, deploy before `clipboard-bridge` and `make macos`. And the terminal restart disappears entirely once the script evaluates `brew shellenv` itself.

## Design

### Entry: `setup.sh` at the repo root

One file, two ways in:

```
curl -fsSL https://raw.githubusercontent.com/nonrational/dotfiles/main/setup.sh | bash
./setup.sh          # or make setup, any time after
```

"Setup" reads as both first install and catch-up, which is the point. "Install" implies once, "bootstrap" is taken by the macOS script, and "converge" names the mechanism rather than the job.

The body is wrapped in a function invoked on the last line, so a half-downloaded script does nothing. When the script is not running from inside a git checkout (`BASH_SOURCE` unset, or its directory has no `.git`), it self-bootstraps: install the Command Line Tools if `xcode-select -p` fails (a checkpoint, see below), clone `https://github.com/nonrational/dotfiles` into `~/.dotfiles` since a fresh Mac has no SSH keys, export `SETUP_FIRST_RUN=1`, and exec `~/.dotfiles/setup.sh`. Every prompt (sudo, `gh auth login`, the screen-lock password) reads from `/dev/tty`, because under the pipe stdin is the script.

The OS branch is by `uname`, the way the manifest's `os=` condition is.

### Split: `scripts/setup-lib.sh` holds the harness, `setup.sh` holds the steps

The harness is the reusable part and the tricky shell: self-clone, `/dev/tty` prompts, the first-run flag, `step`, `checkpoint`, the runner, `--dry-run`. The steps are repo-specific. They are separate files from the first commit so nonreagent can vendor the harness the way it already vendors `deploy.sh` and `scripts/host-id.sh` (see Downstream).

`setup-lib.sh` exposes four functions and nothing else:

- `step <name> <guard-fn> <run-fn>`: if the guard exits 0, print `skip: <name>` and move on; otherwise run, or under `--dry-run` print `would: <name>`.
- `first_run_step <name> <run-fn>`: as `step`, but only when `SETUP_FIRST_RUN=1`; otherwise print `skip: <name> (first run only)`.
- `checkpoint <n> <message>`: print the numbered instruction, tell the user to re-run `setup.sh`, exit 1.
- `run_setup`: the self-bootstrap check, the OS dispatch to `setup_darwin` or `setup_linux`, and the summary line.

The step and guard functions live in `setup.sh` and call make targets. `setup.sh` contributes ordering, `brew shellenv`, the checkpoints, and the first-run gate. Nothing else.

### macOS steps, in order

1. Command Line Tools. Guard `xcode-select -p`. On miss: run `xcode-select --install` and checkpoint 1, "finish the installer, then re-run".
2. `brew-install`. Guard: `/opt/homebrew/bin/brew` is executable.
3. `eval "$(/opt/homebrew/bin/brew shellenv)"`. Always; not a step, a fact the rest of the run needs.
4. `brew-bundle`. No guard; `brew bundle` is the guard.
5. `set-shell` (new target). Guard: `/etc/shells` lists the brew bash and `dscl . -read ~ UserShell` returns it.
6. `init-submodules`. Guard: no submodule path is empty.
7. `deploy`. Guard: `./deploy.sh audit` exits 0.
8. `link-karabiner`. Guard: `~/.config/karabiner` resolves to the repo's `karabiner`.
9. `clipboard-bridge`. Guard: `launchctl list` shows the label.
10. `gh auth login`. Guard: `gh auth status`. Interactive, inline on `/dev/tty`; no checkpoint.
11. `link-sublime`. Guard: `~/.sublime3` is a git checkout and the Application Support link resolves to it.
12. First run only: `restore-preferences`, then `macos-reset-dock`.
13. `macos-disable-restore-apps-on-login`. Guard: the ByHost loginwindow files are empty and immutable.
14. `macos-doctor`. On failure: checkpoint 2, "grant Full Disk Access to this terminal, restart it, then re-run".
15. `macos-apply`, then `scripts/macos-bootstrap.sh`.
16. Reboot: checkpoint 3 by nature. The script prints that it is rebooting and runs the existing osascript.

The `make macos` target keeps working on its own (doctor, apply, bootstrap, reboot) but `setup.sh` calls its three parts separately so the doctor failure is a checkpoint rather than a make error.

### Linux steps, in order

1. `init-submodules`. 2. `deploy`. Same guards, same first-run flag, no checkpoints. This is the path the nonreagent hosts take and the one CI can run end to end.

### Makefile changes

Guards move into the targets that own them, so each target becomes re-runnable on its own and `setup.sh` never re-implements a target's logic:

- `brew-install`: skip with a message when brew exists.
- `set-shell`: new. Appends the brew bash to `/etc/shells` if absent, `chsh` if the user shell differs. Replaces the README's inline block.
- `link-karabiner`, `link-sublime`: skip the clone or link when it is already correct; replace a wrong link.
- `macos-disable-restore-apps-on-login`: `chflags nouimmutable` before the `tee`, so a re-run does not print a failure.
- `setup`: alias for `./setup.sh "$(ARGS)"`.
- `.PHONY`: drop `macos-setup` and `init-post-reboot`, which name no target, and add `setup` and `set-shell`.

### First run

The self-clone is the only thing that sets `SETUP_FIRST_RUN`. The two destructive targets run only under it. Running `./setup.sh` from an existing clone never touches the Dock or the preference files, and there is no flag to force it. Re-doing first setup on a machine that has a clone means deleting the clone, which is the right bar for a destructive action.

### Checkpoints

A checkpoint prints one numbered instruction, says "re-run setup.sh when done", and exits 1. Re-running starts from the top; every earlier step is a no-op by then, so there is no state file to keep or corrupt. Exit 1 rather than 0 so a wrapper (CI, the exe-box script) can tell "halted for a human" from "converged".

### `--dry-run`

Prints each step with its guard's verdict (`skip:` or `would:`) and runs nothing, including the self-clone. This is what CI runs on both OSes and what a human runs to see what a re-run would do.

### Tests

`test/test_setup.sh`, sandboxed like `test_deploy.sh`. It puts stub `xcode-select`, `brew`, `gh`, `launchctl`, `dscl` and `make` on PATH under a temp `$HOME`, with each stub's behavior set by an environment variable, and asserts:

- macOS order: the stub `make` logs the targets it was called with, in the order above.
- Guards skip: with every stub reporting "already done", the run is all `skip:` lines and calls no target.
- Each checkpoint halts: stub `xcode-select -p` failing yields exit 1 and the checkpoint 1 message with nothing after it; stub `make macos-doctor` failing yields checkpoint 2.
- First run: the destructive targets appear only with `SETUP_FIRST_RUN=1`, and `--dry-run` never sets it.
- Linux: `uname` stubbed to Linux runs exactly `init-submodules` and `deploy`.
- Self-bootstrap: piping the script into bash from outside a checkout, with a stub `git`, clones to `$HOME/.dotfiles` and re-execs.

Added to `make test`, so both CI legs pick it up.

### CI

`ci.yml` adds `./setup.sh --dry-run` on both runners. The ubuntu leg replaces its bare `./deploy.sh apply` and `audit` calls with `HOME=$(mktemp -d) ./setup.sh`, which runs the real Linux path and proves it converges; the macOS leg keeps `deploy.sh apply` and `audit` as they are, since the real macOS path needs brew and sudo.

### Docs

The README's two shell blocks collapse to the curl line, the local re-run line, the three checkpoints, and a sentence saying the first-run steps happen only when the script clones. `CLAUDE.md` gains one Commands line for `setup.sh` and `make setup`. `scripts/macos-bootstrap.sh`'s header gains "run by setup.sh after the table applies, immediately before the reboot".

## Downstream: nonreagent/dotfiles

Nothing changes there automatically. Its `build.sh` selects paths from an allowlist that only names things under `home/`, and vendors `deploy.sh` and `scripts/host-id.sh` by explicit copy. A root-level `setup.sh` and the Makefile changes are invisible to it.

The intended change there, as its own PR in that repo after this one merges:

- `build.sh` vendors `scripts/setup-lib.sh` alongside `deploy.sh`, through the same explicit-copy hook.
- Its own `setup.sh` sources the lib and lists its steps: `install.sh` (which already owns the base-image preflight and orphan pruning), `gh auth login` guarded by `gh auth status`, `~/.claude/sync-plugins.sh`, and first run only, `setup-review-watcher`.
- Its README's install block becomes the curl line for `https://raw.githubusercontent.com/nonreagent/dotfiles/main/setup.sh`.

The `gh` step is that repo's only interactive one. The device flow makes it so; the alternative is a token, handled below.

## `scripts/new-exe-box.sh`: one command for a new VM

Lives here, not downstream, because it runs from the Mac with the human's exe.dev key and 1Password session. exe.dev's `new` command takes `--setup-script`, which the default `exeuntu` image runs once at first boot, so the box provisions itself and this script is a wrapper.

```
scripts/new-exe-box.sh <name>          # or make exe-box NAME=<name>
```

1. `ssh exe.dev new --name <name> --json --setup-script /dev/stdin`, fed one line: the curl-to-bash for nonreagent's `setup.sh`. That run does the unattended part and halts at its `gh` checkpoint with no one watching, which is fine because of step 3.
2. Poll `ssh -o StrictHostKeyChecking=accept-new <name>.exe.xyz true` until the box answers, with a bounded timeout.
3. Inject the token over stdin, never through `--env` or the setup script, so it lands only in `gh`'s config on the VM, the same state an interactive login leaves:

   ```
   op read "op://<vault>/<item>/token" \
     | ssh <name>.exe.xyz 'gh auth login --with-token && gh auth setup-git'
   ```

4. `ssh <name>.exe.xyz ~/.dotfiles/setup.sh`. The `gh` guard now passes and the run finishes through `sync-plugins.sh`. Idempotency is what makes the two-phase first boot work.
5. Print the name and `https://<name>.exe.xyz`.

The 1Password item path is the script's one configuration value, read from `EXE_BOX_GH_TOKEN_REF` with a default in the script. `op` unlocking is the only human touch.

The same pipe can carry a `claude setup-token` value into the VM's environment file, which would close the expired-login failure the review watcher records. That is a separate decision: a long-lived Claude token is a larger blast radius than a fine-grained PAT scoped to nonreagent's repositories. This spec leaves it out; the wrapper is written so adding a second injected secret is one more line.

**Order of delivery.** This repo's `setup-lib.sh` and `setup.sh` first. Then nonreagent's `setup.sh`, in its repo. Then this wrapper, which has nothing to curl until the second exists. The wrapper is therefore the last task in the plan and may land as its own PR.

**Verify on a throwaway box before writing the wrapper.** Which user the first-boot script runs as and whether `$HOME` is the login user's, since `setup.sh` clones into `~/.dotfiles`. And whether `git`, `curl`, `gh` and `claude` are present in `exeuntu` at first boot; `sync-plugins.sh` needs `claude`. The docs do not say. One `ssh exe.dev new` with a probe script settles both. Non-interactive ssh to the `exe.dev` lobby hangs on host-key prompts from this machine, as exe.dev's own skill file warns, so the wrapper passes `-o StrictHostKeyChecking=accept-new` on every lobby and VM call.

## Out of scope

- `topgrade` or any package-manager updating beyond `brew bundle`. Updating a machine and converging it are different verbs; if the first is ever wanted it is a separate command with a checked-in config, as recorded on the issue.
- Resume state. Idempotent steps make it unnecessary.
- A flag to force the first-run steps on an existing clone.
- Injecting a Claude token into exe boxes (see above).
- Windows.
- nonreagent's own `setup.sh`; designed here for the lib's sake, delivered there.

## Decisions taken during design

- **Automatic first-run steps.** The destructive targets run without asking on a fresh machine, because "one command for a new Mac" was the goal; the self-clone is the gate.
- **Name.** `setup.sh`, over `converge`, `install` and `bootstrap`.
- **Token over stdin.** Over `--env` and over the setup script, so the exe.dev control plane never stores it.
- **Lib split from day one.** Over two independent scripts, because the vendoring path downstream already exists and the harness is where the fragile shell lives.
