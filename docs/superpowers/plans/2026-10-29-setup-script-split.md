# Split PR #74 into a Mac setup PR and an exe-box PR: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace PR #74 with two independent PRs: (A) `curl -sS https://nonration.al/setup.sh | bash` provisions a new Mac for @nonrational, halting at numbered checkpoints; (B) `make exe-box NAME=<machine>` creates or reuses `<machine>.exe.xyz` and provisions it as an @nonreagent host.

**Architecture:** PR A salvages `setup.sh`, the re-runnable make targets, and the CI and README changes from branch `setup-script`, folds `scripts/setup-lib.sh` back into `setup.sh` (no downstream consumer remains), applies the four findings from the operator's VM run, and adds a Cloudflare Worker that serves `setup.sh` at `nonration.al/dotfiles/setup.sh` with a 200. PR B salvages `scripts/new-exe-box.sh` and points it at nonreagent/dotfiles' existing `install.sh` instead of a downstream `setup.sh` that will not exist. Neither PR touches nonreagent/dotfiles.

**Tech Stack:** bash (3.2-compatible), make, Cloudflare Workers (ES module, `wrangler`), `node --test` (Node 24), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-25-setup-script-design.md` on branch `setup-script` (commit `f1ea01a`). PR A amends it in Task A1; PR B carries its own section as `docs/superpowers/specs/2026-10-29-exe-box-design.md`. The operator's QA comment on PR #74 (2026-10-13) is the source for Task A4.

## Global Constraints

- Source branch for salvage: `origin/setup-script`. Commit SHAs below refer to it: `f1ea01a` spec, `b91ca99` make targets, `2cd967f` harness, `4c17af4` setup.sh, `488f102` CI/README, `70d6f81` + `27a3f6e` exe box. `986173d` (the old plan) is not carried forward; this plan supersedes it.
- Each PR branches from `origin/main` in its own worktree: `.worktrees/setup-mac` (branch `setup-mac`, already holds this plan) and `.worktrees/exe-box` (branch `exe-box`). Never switch branches in the shared checkout.
- `setup.sh` runs under macOS's `/bin/bash` 3.2 on a fresh Mac: no `mapfile`, associative arrays, `${var,,}`, or `|&`.
- Exit codes for `setup.sh`: `0` converged (or dry run finished), `1` halted at a checkpoint, `2` a step failed or a usage error.
- Public URL, verbatim: `https://nonration.al/setup.sh`. Upstream it proxies: `https://raw.githubusercontent.com/nonrational/dotfiles/main/setup.sh`.
- The documented command is `curl -sS https://nonration.al/setup.sh | bash`, never with `-f`: `-f` drops the Worker's error body, so bash reads empty input and the pipeline exits 0 silently. Without `-f`, the error body runs and exits 1.
- `node --test` takes a quoted glob (`'cloudflare/dotfiles-proxy/*.test.mjs'`), never a directory: Node 22+ treats a directory argument as a module and fails.
- exe.dev VM hostnames are `<name>.exe.xyz` (not `.exe.dev`). Every ssh call passes `-o StrictHostKeyChecking=accept-new`.
- The GitHub token travels on ssh stdin only, never in an argument, `--env`, or a setup-script.
- Any test file that runs `git init` unsets `GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE` at its top.
- Commit subjects are plain sentences (no `feat:`-style prefixes) and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- PR bodies: issue line first, then exactly `### Problem`, `### Motivation`, `### Proposed Solution`, `### Feedback`. No AI attribution. Request review from `nonrational` on open.
- `make preflight` passes at every commit.

## Review Focus

1. **`curl … | bash` against an error.** The documented line has no `-f`, so whatever body the Worker returns runs in bash. A 404 or upstream failure must return a body that bash executes as `echo "<reason>" >&2; exit 1`, never HTML. Pinned in Task A5.
2. **A run function with two commands under `"$run" || exit 2`.** `||` suspends errexit inside the function, so `apply_macos` would run `macos-bootstrap.sh` after a failed `macos-apply`. Pinned in Task A4.
3. **Re-running `make exe-box` against a box that already exists.** Expected: no second `exe.dev new`, provisioning re-runs and converges. Pinned in Task B1.
4. **The reboot step on a Mac reached over ssh.** The operator saw osascript `-1708` and a bare exit 1. Expected: checkpoint 3 telling the human to restart by hand. Pinned in Task A4.
5. **A `.gitmodules` entry with no gitlink, or `git` failing.** Expected: the stale entry does not make `init-submodules` run every pass; a failing `git` makes the guard false (run the step) rather than true. Pinned in Task A4.
6. **A brand-new macOS 26 Mac at `macos-apply`.** The operator found `com.apple.addressbook ABShowDebugMenu` unwritable on macOS 26 (`origin/main:macos-defaults:575`), and `scripts/macos-defaults.sh` runs under `set -euf`, so apply aborts there on every run and the reboot never comes. Fixed in Task A4.

---

## PR A: `setup-mac`, the Mac setup command

### Task A1: Amend the spec for the split

**Files:**
- Create: `docs/superpowers/specs/2026-09-25-setup-script-design.md` (as it stands on `origin/setup-script`, which includes the later edits from `4c17af4` and `70d6f81`)
- Already present: `docs/superpowers/plans/2026-10-29-setup-script-split.md` (this file)

- [ ] **Step 1:** In `.worktrees/setup-mac`, `git show origin/setup-script:docs/superpowers/specs/2026-09-25-setup-script-design.md > docs/superpowers/specs/2026-09-25-setup-script-design.md`. Taking the final version here, not `f1ea01a`, is what lets A3's cherry-pick drop its spec hunks.
- [ ] **Step 2:** Edit the spec, quoting these anchors:
  - Status line `**Status:** design, awaiting review` → `**Status:** amended 2026-10-29: split into a Mac PR and an exe-box PR`.
  - Under `### Entry: \`setup.sh\` at the repo root`, the curl line becomes `curl -sS https://nonration.al/setup.sh | bash`; add one paragraph: a Cloudflare Worker on route `nonration.al/dotfiles/*` proxies `raw.githubusercontent.com/nonrational/dotfiles/main/setup.sh` with a 200, so bare `curl` works without `-L`.
  - Replace the section `### Split: \`scripts/setup-lib.sh\` holds the harness, \`setup.sh\` holds the steps` with `### One file`: the harness functions (`step`, `first_run_step`, `checkpoint`, `run_setup`) live in `setup.sh`; nothing downstream vendors them.
  - Replace `## Downstream: nonreagent/dotfiles` and `## \`scripts/new-exe-box.sh\`…` with one paragraph: nonreagent/dotfiles keeps its own `install.sh` unchanged; the exe-box wrapper ships separately (`docs/superpowers/specs/2026-10-29-exe-box-design.md`, PR B).
  - In `## Out of scope`, drop the bullet `nonreagent's own \`setup.sh\`…`. In `## Decisions taken during design`, replace `**Lib split from day one.**` with `**One file.** The lib split existed for downstream vendoring, which the split dropped.`
  - Add exit code `2` to the `### Checkpoints` paragraph: a failed step prints `failed: <name>` and exits 2.
- [ ] **Step 3:** Verify: `grep -nE 'setup-lib|new-exe-box|curl -fsSL' docs/superpowers/specs/2026-09-25-setup-script-design.md` prints nothing except the one line pointing at the exe-box spec.
- [ ] **Step 4:** Commit both files: `Design one setup command for a Mac, and plan its split from the exe box`.

### Task A2: Make the setup targets re-runnable

**Files:**
- Modify (cherry-pick `b91ca99`): `Makefile`, Create: `test/test_setup.sh`

**Interfaces:**
- Produces: make targets `brew-install`, `set-shell`, `link-karabiner`, `link-sublime`, `macos-disable-restore-apps-on-login` all re-runnable; `setup` alias (`./setup.sh $(ARGS)`); vars `BREW`, `BREW_BASH`, `SHELLS_FILE`. `test/test_setup.sh` with helpers `sandbox`, `stub <name> [stdout]`, `mk`, `ok`, `bad`, and `STUB_FAIL`/`STUB_EXIT` semantics as on `setup-script`.

- [ ] **Step 1:** `git cherry-pick b91ca99`. The `setup` target references a file that does not exist until A3; that is fine, nothing calls it yet.
- [ ] **Step 2:** Run `./test/test_setup.sh`. Expected: the eight make-target tests (`test_link_karabiner_is_idempotent` through `test_set_shell_requires_brew_bash`) PASS, `0 failed`.
- [ ] **Step 3:** `make preflight` passes. Keep the cherry-picked subject.

### Task A3: Add `setup.sh` as one file

**Files:**
- Create: `setup.sh` (content of `4c17af4`'s `setup.sh` plus `2cd967f`'s `scripts/setup-lib.sh`, merged)
- Modify: `test/test_setup.sh` (`b91ca99` already added it to the `test:` recipe; do not add it again)
- Do not create: `scripts/setup-lib.sh`. Do not touch: `docs/` (A1 owns the spec)

**Interfaces:**
- Consumes: A2's targets and test helpers; `scripts/host-id.sh` for `os_id`.
- Produces: `setup.sh` functions `step <name> <guard> <run>`, `first_run_step <name> <run>`, `checkpoint <n> <message...>`, `run_setup "$@"`, `setup_darwin`, `setup_linux`, `setup_self_bootstrap "$@"`; env `SETUP_REPO_URL`, `SETUP_CLONE_DIR`, `SETUP_BRANCH`, `SETUP_BREW`, `SETUP_BREW_BASH`, `SETUP_ETC_SHELLS`, `SETUP_FIRST_RUN`, `SETUP_DRY_RUN`.

- [ ] **Step 1:** `git cherry-pick --no-commit 2cd967f 4c17af4`; if the spec conflicts, `git checkout HEAD -- docs/` (A1 already holds its final text). Move the body of `scripts/setup-lib.sh` (minus its header and the `SETUP_ROOT` assertion) into `setup.sh` above the guards; `git rm scripts/setup-lib.sh`. `setup_self_bootstrap` detects a checkout by `[ -f "$here/scripts/host-id.sh" ]` instead of the lib. `main` sources `"$SETUP_ROOT/scripts/host-id.sh"` and calls `run_setup`. Rewrite the header comment: one file, no mention of vendoring.
- [ ] **Step 2:** In `test/test_setup.sh`, drop `scripts/setup-lib.sh` from `setup_repo`'s `cp` line (the suite aborts under `set -e` otherwise), and delete the `# --- setup-lib.sh ---` block (`lib_fixture`, `fixture`, and the eight `test_*` it defines). Port the three with no `setup.sh` equivalent, driving the real `setup.sh` through the existing `setup_run` helper:
  - `test_unknown_flag_is_usage_error`: `setup_run --bogus` → status `2`, output contains `usage: setup.sh [--dry-run]`, stub `make` never called.
  - `test_unsupported_os_fails`: `uname` stubbed to `FreeBSD` → status `2` (a failure, not a checkpoint; change `run_setup`'s `exit 1` there), output contains `error: unsupported OS FreeBSD`.
  - `test_run_without_tty_survives`: `setup_run </dev/null` with every guard holding → status `0`, last line `setup: converged (Darwin)`.
  Add `test_first_run_steps_skip_without_flag`: converged Mac, `SETUP_FIRST_RUN` unset → output has `skip: restore-preferences (first run only)` and `skip: macos-reset-dock (first run only)`.
  Remove the `test_lib_*`/fixture names from the call list at the bottom; keep every `setup.sh` and pipe test.
- [ ] **Step 3:** Run `./test/test_setup.sh`. Expected: all PASS, `0 failed`. Run `shellcheck setup.sh`; expected: no errors.
- [ ] **Step 4:** `make preflight` passes. Commit: `Add setup.sh: one re-runnable entry point for a Mac or a Linux host`.

### Task A4: Apply the findings from the operator's VM run

**Files:**
- Modify: `setup.sh`, `test/test_setup.sh`, `macos-defaults` (delete the row `com.apple.addressbook	ABShowDebugMenu	bool	true	noaudit=unset`, line 575 on `origin/main`)

**Interfaces:**
- Produces: `step`/`first_run_step` print `failed: <name>` to stderr and `exit 2` when the run function returns nonzero; a counter `SETUP_PENDING` incremented on every `would:` line; dry-run summary line `setup: dry run (<os>), <n> would run`.

- [ ] **Step 1: Write the failing tests** in `test/test_setup.sh`:
  - `test_failed_step_exits_2_with_name`: converged Mac with `STUB_FAIL='gh auth status|gh auth login'` → status `2`, stderr contains `failed: gh auth login`, and no `run:` line follows it.
  - `test_failed_apply_skips_bootstrap`: `STUB_MACOS_AUDIT=1`, `STUB_FAIL='make -C <root> macos-apply'` → status `2`, the stub `macos-bootstrap.sh` log is empty, output contains `failed: macos-apply + macos-bootstrap`.
  - Fixture change first: `setup_repo` keeps its fake `.git`, and a `git` stub answers `git -C <root> submodule status` by printing `$STUB_SUBMODULES`. `converged_mac` sets it to ` 0123abc etc/sub`; the first-run and Linux tests set `-0123abc etc/sub`, so `MAC_ORDER` and `test_linux_runs_only_submodules_and_deploy` still see `init-submodules` run.
  - `test_stale_gitmodules_entry_does_not_rerun_init`: builds its own real repo (`git init -q`, no `git` stub on PATH) whose `.gitmodules` lists `etc/stale` with no gitlink; with every other guard holding, output contains `skip: init-submodules`. This test proves git's own behavior, which the stub cannot.
  - `test_git_failure_runs_init`: `STUB_FAIL='git'` → output contains `run: init-submodules`.
  - `test_dry_run_summary_counts_pending`: Mac with `brew` absent and deploy audit failing, `--dry-run` → status `0`, last line `setup: dry run (Darwin), <n> would run` where `<n>` equals `grep -c '^would:'` of the same output, and no line `setup: converged`.
  - `test_reboot_failure_is_checkpoint_3`: `STUB_MACOS_AUDIT=1`, `STUB_FAIL='osascript'` → status `1`, exactly one line matching `^checkpoint 3:`, and that line starts `checkpoint 3: the reboot request failed`.
- [ ] **Step 2:** Run `./test/test_setup.sh`. Expected: the six new tests FAIL, the rest PASS.
- [ ] **Step 3: Implement.**
  - In `step` and `first_run_step`: `"$run" || { echo "failed: $name" >&2; exit 2; }`. Because `||` disables errexit inside `$run`, chain every multi-command run function with `&&`: `apply_macos() { mk macos-apply && "$SETUP_ROOT/scripts/macos-bootstrap.sh" && SETUP_MACOS_APPLIED=1; }`. `checkpoint` keeps calling `exit 1` directly, which the `||` does not intercept.
  - `submodules_present`: `local out; out="$(git -C "$SETUP_ROOT" submodule status 2>/dev/null)" || return 1; ! grep -q '^-' <<<"$out"`. `git submodule status` lists only paths with a gitlink, so the stale `.gitmodules` entry drops out. Leave `.gitmodules` itself alone; deleting `etc/tomorrow-theme` is a separate cleanup.
  - `run_setup` end: under dry run print `setup: dry run ($(os_id)), $SETUP_PENDING would run`; otherwise the existing `setup: converged (<os>)`.
  - `reboot_mac`: the pre-reboot echo loses its `checkpoint 3:` label (`rebooting. Run $0 once more afterwards; it should report every step as skip.`), then `osascript … || checkpoint 3 "the reboot request failed (no GUI session?). Restart this Mac by hand, then re-run setup.sh once more."`
  - Delete the `ABShowDebugMenu` row from `macos-defaults`. Verify `make check-macos-defaults` still passes.
- [ ] **Step 4:** Run `./test/test_setup.sh`. Expected: all PASS, `0 failed`. `make preflight` passes.
- [ ] **Step 5:** Commit: `Exit 2 on a failed setup step, and fix the rough edges the VM run found`.

### Task A5: Serve `setup.sh` at `nonration.al/dotfiles/setup.sh`

> **Amended 2026-10-29, after PR A opened:** the operator chose GitHub Pages from this repo over the Worker, at `/setup.sh` rather than `/dotfiles/setup.sh`, with a plain landing page at the root. The Worker below was built, reviewed, then replaced by `site/index.html`, `.github/workflows/pages.yml`, and `make site` / `make check-site`. The old splash page and its `.well-known/keybase.txt` are retired.

**Files:**
- Create: `cloudflare/dotfiles-proxy/worker.mjs`, `cloudflare/dotfiles-proxy/worker.test.mjs`, `cloudflare/dotfiles-proxy/wrangler.toml`
- Modify: `Makefile` (new `check-worker` target; add it to the `preflight:` prerequisite list)

**Interfaces:**
- Produces: `export default { async fetch(request: Request): Promise<Response> }`; exported `UPSTREAM = "https://raw.githubusercontent.com/nonrational/dotfiles/main/setup.sh"`.

- [ ] **Step 1: Write the failing tests** (`node:test`, `node:assert/strict`, stubbing `globalThis.fetch`):
  - `GET https://nonration.al/setup.sh` fetches exactly `UPSTREAM`; with upstream `200` body `echo hi`, returns status `200`, body `echo hi`, `content-type: text/plain; charset=utf-8`, `cache-control: no-store`.
  - Upstream `404` → status `502`, body matches `/^echo "nonration\.al: setup\.sh unavailable \(upstream 404\)" >&2; exit 1\n$/`.
  - `GET /dotfiles/anything-else` and `GET /dotfiles/` → status `404`, body `echo "nonration.al: no such file" >&2; exit 1\n`, and `fetch` never called.
  - Upstream `fetch` rejecting → status `502`, body starts `echo "nonration.al:` and ends `exit 1\n`.
  - Every error body, written to a temp file and run with `bash`, exits `1` (spawn via `node:child_process`).
- [ ] **Step 2:** `node --test 'cloudflare/dotfiles-proxy/*.test.mjs'` → FAIL (cannot import `./worker.mjs`).
- [ ] **Step 3:** Implement `worker.mjs`. Only the exact path `/dotfiles/setup.sh` proxies; no general path mapping. `wrangler.toml`: `name = "nonration-al-dotfiles"`, `main = "worker.mjs"`, `compatibility_date = "2026-10-01"`, `routes = [{ pattern = "nonration.al/dotfiles/*", zone_name = "nonration.al" }]`. `check-worker:` runs `node --test 'cloudflare/dotfiles-proxy/*.test.mjs'`.
- [ ] **Step 4:** `make check-worker` and `make preflight` pass.
- [ ] **Step 5:** Commit: `Serve setup.sh at nonration.al/dotfiles/setup.sh through a Cloudflare Worker`.

Deployment is the operator's, after PR A merges (the Worker proxies `main`, which has no `setup.sh` until then): `cd cloudflare/dotfiles-proxy && npx wrangler@4 login && npx wrangler@4 deploy`. Acceptance: `curl -s https://nonration.al/setup.sh | cmp - setup.sh` exits 0, and `curl -sI` shows `HTTP/2 200`. The PR's Feedback section says so.

### Task A6: CI, README, and CLAUDE.md

**Files:**
- Modify (cherry-pick `488f102`): `.github/workflows/ci.yml`, `README.md`, `CLAUDE.md`, `scripts/macos-bootstrap.sh`
- Modify: `setup.sh` (header and checkpoint-1 text)

- [ ] **Step 1:** `git cherry-pick --no-commit 488f102`. Resolve against current `main` (README and CLAUDE.md moved since 2026-09-25; fish landed in #95).
- [ ] **Step 2:** Replace the URL: README's install block becomes `curl -sS https://nonration.al/setup.sh | bash`; `setup.sh`'s header usage line likewise; the self-bootstrap checkpoint-1 line reads `re-run: curl -sS https://nonration.al/setup.sh | bash`. In the CLAUDE.md Commands bullet, drop the sentence about `scripts/setup-lib.sh` and vendoring; add a bullet `make check-worker` — tests the Worker in `cloudflare/dotfiles-proxy/` that serves `setup.sh` at nonration.al.
- [ ] **Step 3:** In README, under the three checkpoints, add: a failed step prints `failed: <name>` and exits 2; re-run after fixing it.
- [ ] **Step 4:** Verify: `git grep -nE 'raw.githubusercontent.com/nonrational/dotfiles/main/setup.sh|curl -fsSL https://nonration' -- . ':!cloudflare' ':!docs'` prints nothing; `./setup.sh --dry-run` on Linux exits 0 with last line `setup: dry run (Linux), <n> would run`; `make preflight` passes.
- [ ] **Step 5:** Commit: `Run setup.sh in CI and make the nonration.al curl line the README's install sequence`.

### Task A7: Open PR A

- [ ] **Step 1:** `git rebase --exec 'env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE make preflight' origin/main` passes at every commit.
- [ ] **Step 2:** Push `setup-mac`; open the PR titled `One setup command for a new Mac`, body first line `Resolves #28`. Feedback names: the Worker deploy and acceptance `curl` as the operator's post-merge step; the errexit-under-`||` change in `apply_macos`; the `link-sublime` refusal carried from #74; that the operator's VM run predates A4.
- [ ] **Step 3:** `gh pr edit --add-reviewer nonrational`. Remove the worktree.

---

## PR B: `exe-box`, one command for a new @nonreagent box

### Task B1: `scripts/new-exe-box.sh` against nonreagent's existing install

**Files:**
- Create: `scripts/new-exe-box.sh` (from `27a3f6e`), `test/test_exe_box.sh`, `docs/superpowers/specs/2026-10-29-exe-box-design.md`
- Modify: `Makefile` (`exe-box` target as in `70d6f81`; `./test/test_exe_box.sh` appended to `test:`), `README.md` (a new `# New exe.dev box` section directly above `# Clipboard bridge (exe.dev VMs)`: the `make exe-box NAME=<name>` line and two sentences on what it does)

**Interfaces:**
- Produces: `scripts/new-exe-box.sh <name>`; env `EXE_BOX_REPO_URL` (default `https://github.com/nonreagent/dotfiles`), `EXE_BOX_GH_TOKEN_REF` (default `op://Private/nonreagent-github/token`), `EXE_BOX_WAIT` (300), `EXE_BOX_POLL` (5). `EXE_BOX_SETUP_URL` is gone.

- [ ] **Step 1:** In a new worktree `.worktrees/exe-box` on branch `exe-box` from `origin/main`, restore the files: `git show 27a3f6e:scripts/new-exe-box.sh > scripts/new-exe-box.sh`. Write the spec: the `## \`scripts/new-exe-box.sh\`` section of the spec as it stands on `origin/setup-script` (after `70d6f81`; not `f1ea01a`, which still has the superseded `--setup-script` design), amended so step 4 is the clone-and-install command below and the "Order of delivery" paragraph is gone (nothing downstream needs to land first).
- [ ] **Step 2: Write the failing tests** in `test/test_exe_box.sh`, a standalone suite in the shape of the other `test/test_*.sh` files: copy `sandbox`, `stub`, `ok`, `bad` and `stub_ssh` from `setup-script`'s `test/test_setup.sh` (lines 16-48 and 499-522). `stub_ssh` keeps one failure counter across every `<host> true` call, so the existence probe consumes the first failure, and the default `STUB_SSH_NOT_READY=0` takes the reuse path. The `exe_box` helper sets `EXE_BOX_REPO_URL=https://example.invalid/repo` in place of `EXE_BOX_SETUP_URL`. Tests:
  - `test_exe_box_creates_waits_injects_and_installs`: `STUB_SSH_NOT_READY=2` → status `0`; log has `exe.dev new --name mybox --json`; `mybox.exe.xyz true` three times (the failed probe, one failed wait, one answered wait); `gh auth login --with-token && gh auth setup-git`; then exactly `mybox.exe.xyz { git -C ~/.dotfiles pull --ff-only || git clone https://example.invalid/repo ~/.dotfiles; } && ~/.dotfiles/install.sh && ~/.claude/sync-plugins.sh`; second-to-last output line `ready: mybox.exe.xyz https://mybox.exe.xyz/`; last line `optional: ssh mybox.exe.xyz ~/bin/setup-review-watcher`.
  - `test_exe_box_reuses_existing_box`: default stub (answers at once) → status `0`, output contains `using existing mybox.exe.xyz`, log has no `exe.dev new`, and the install command still runs.
  - `test_bad_token_ref_creates_nothing`: `op` stub fails → status nonzero, log has no `ssh` line at all. (Already true of `27a3f6e`; it pins the order against regression.)
  - `test_token_goes_over_stdin_only`, `test_exe_box_requires_name`: ported unchanged. `test_exe_box_times_out_waiting`: ported, still `STUB_SSH_NOT_READY=1000000`, so the probe fails and the wait times out.
- [ ] **Step 3:** `./test/test_exe_box.sh` → the first two FAIL; the rest PASS.
- [ ] **Step 4: Implement.** In `new-exe-box.sh`: after reading the token, probe `ssh $ssh_opts -o ConnectTimeout=5 "$host" true`; on success print `using existing $host` and skip `new` and the wait loop. Replace the curl step with `ssh $ssh_opts "$host" "{ git -C ~/.dotfiles pull --ff-only || git clone $EXE_BOX_REPO_URL ~/.dotfiles; } && ~/.dotfiles/install.sh && ~/.claude/sync-plugins.sh"`. A re-run pulls first, so it converges on current `main`; a pull that fails on an existing clone sends `git clone` into a non-empty directory, which fails and stops the chain. Print the `ready:` line, then the `optional:` line. Update the header comment: runs nonreagent/dotfiles' `install.sh`; no `setup.sh` downstream.
- [ ] **Step 5:** `./test/test_exe_box.sh` all PASS; `make preflight` passes.
- [ ] **Step 6:** Commit: `Add new-exe-box.sh: create or reuse an exe.dev VM and provision it as an @nonreagent host`.

### Task B2: Acceptance on a real throwaway box

Needs the operator's terminal on the Mac (exe.dev key, unlocked `op`); the agent hands over the commands.

- [ ] **Step 1:** Operator confirms `EXE_BOX_GH_TOKEN_REF`'s 1Password path and runs `ssh exe.dev help new` to confirm `--name` and `--json` still exist.
- [ ] **Step 2:** `make exe-box NAME=nr-probe-$(date +%m%d)`. Expected: exit 0 and the `ready:` line. Then `ssh nr-probe-….exe.xyz 'gh auth status && ~/.dotfiles/deploy.sh audit && command -v claude'` exits 0.
- [ ] **Step 3:** Run `make exe-box NAME=<same>` again. Expected: `using existing`, exit 0, no second VM in `ssh exe.dev ls`.
- [ ] **Step 4:** Any fix found here amends B1's commit (`git commit --fixup` + autosquash). Delete the probe box: `ssh exe.dev rm <name>`.

### Task B3: Open PR B

- [ ] **Step 1:** Push `exe-box`; open the PR titled `One command for a new @nonreagent exe.dev box`, body first line `Part of #28`. Feedback names: the token ref default; that B2's probe ran (with its output) or did not; that whichever of A and B merges second resolves a one-line conflict in the `test:` recipe by keeping both `./test/test_setup.sh` and `./test/test_exe_box.sh`.
- [ ] **Step 2:** `gh pr edit --add-reviewer nonrational`. Remove the worktree.

---

## Close PR #74

- [ ] **Step 1:** After A and B are open, comment on #74: `Split into #<A> (Mac setup, plus the four VM-run findings) and #<B> (exe box). Closing in favor of those.` Then `gh pr close 74`.
- [ ] **Step 2:** Leave `origin/setup-script` in place until both merge; the salvage SHAs above point into it. Delete it after.
