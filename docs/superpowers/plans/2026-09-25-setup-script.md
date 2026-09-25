# Setup Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One re-runnable `setup.sh` that brings a Mac or a Linux host to the state this repo describes, and one `scripts/new-exe-box.sh` that creates and provisions an exe.dev VM for @nonreagent.

**Architecture:** `scripts/setup-lib.sh` is the harness (step runner, first-run gate, checkpoints, dry-run, OS dispatch) and is written so nonreagent/dotfiles can vendor it beside `deploy.sh`. `setup.sh` at the repo root holds the self-bootstrap (which must be inline, since under `curl | bash` no lib exists yet) and the ordered step list, each step a guard plus an existing make target. The make targets gain guards so each is re-runnable on its own.

**Tech Stack:** bash 3.2-compatible shell (`/bin/bash` on a fresh Mac is 3.2), GNU make, the repo's existing sandboxed test style (`test/test_deploy.sh`), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-25-setup-script-design.md`

## Global Constraints

- Every script is `#!/bin/bash` with `set -euf -o pipefail`, runnable by bash 3.2: no associative arrays, no `${var,,}`, no `mapfile`, no `declare -A`.
- Four-space indentation in shell, tabs in the Makefile (`.editorconfig`; `make check-editorconfig` enforces it).
- `scripts/setup-lib.sh` names nothing specific to this repo (no `nonrational`, no target names); it is vendored downstream verbatim.
- Exit codes from `setup.sh`: 0 converged, 1 halted at a checkpoint, 2 a step failed (make's own exit code) or bad usage.
- The self-clone is the only thing that sets `SETUP_FIRST_RUN=1`. No flag forces it.
- Tests never touch the real `$HOME`; every test runs under a `mktemp -d` sandbox with stubs on `PATH`.
- Commit messages are plain descriptive sentences (no `feat:` prefixes) and end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Markdown edits (README, CLAUDE.md, spec) never hard-wrap prose.

## Review Focus

1. **`curl | bash` on a machine that already has `~/.dotfiles`.** Expected: exec the existing clone with `SETUP_FIRST_RUN` unset, so the Dock and preference files are untouched. Pinned in Task 3 (`test_pipe_reuses_existing_clone`).
2. **`curl | bash -s -- --dry-run` outside any checkout.** Expected: print what it would clone and exit 0 without cloning. Pinned in Task 3 (`test_pipe_dry_run_does_not_clone`).
3. **A run with no tty at all (CI, cron).** Expected: the `/dev/tty` reopen is skipped rather than killing the shell. Pinned in Task 2 (`test_run_without_tty_survives`).
4. **A step fails mid-run** (say `make deploy` exits 2). Expected: the run stops there with make's exit code, later steps do not run, and the exit code is not the checkpoint's 1. Pinned in Task 3 (`test_failed_step_stops_run`).
5. **The token passed to a new exe box.** Expected: it travels only over ssh stdin, never as an argument, so it is absent from process listings and shell history. Pinned in Task 5 (`test_token_goes_over_stdin_only`).

---

### Task 1: Make the five make targets re-runnable and add the `setup` alias

**Files:**
- Modify: `Makefile:7-8` (`brew-install`), `Makefile:173-181` (`link-karabiner`, `link-sublime`), `Makefile:204-209` (`macos-disable-restore-apps-on-login`), `Makefile:80-85` (`test`), `Makefile:218` (`.PHONY`)
- Create: `test/test_setup.sh` (harness plus the Makefile tests; later tasks append to it)

**Interfaces:**
- Consumes: nothing new.
- Produces: make targets `brew-install` (honors `BREW`), `set-shell` (honors `BREW_BASH`, `SHELLS_FILE`), `link-karabiner`, `link-sublime`, `macos-disable-restore-apps-on-login`, all safe to run twice; `make setup ARGS=...`; the `test/test_setup.sh` harness with `sandbox`, `stub`, `ok`, `bad`.

- [ ] **Step 1: Write the failing tests and the harness**

Create `test/test_setup.sh`:

```bash
#!/bin/bash
# Tests for setup.sh, scripts/setup-lib.sh, and the make targets they call.
# Everything runs under a mktemp sandbox with stub commands on PATH, so no
# test touches the real $HOME, brew, gh, or exe.dev.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-setup.XXXXXX")"
BASE="$(cd "$BASE" && pwd)"
trap 'rm -rf "$BASE"' EXIT

pass=0
fail=0
sb_count=0

ok()  { pass=$((pass + 1)); echo "PASS: $1"; }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

# Fresh sandbox: $FAKEHOME is $HOME, $SB/bin holds stubs, $SB/calls.log records
# every stub invocation as "<name> <args>".
sandbox() {
    sb_count=$((sb_count + 1))
    SB="$BASE/$sb_count"
    FAKEHOME="$SB/home"
    LOG="$SB/calls.log"
    mkdir -p "$FAKEHOME" "$SB/bin"
    : > "$LOG"
}

# stub <name> [stdout]: a command on PATH that logs its invocation, prints the
# given stdout, and exits 1 when "<name> <args...>" starts with any '|'-separated
# entry of $STUB_FAIL (e.g. STUB_FAIL='make -C /r macos-doctor|gh auth status').
stub() {
    cat > "$SB/bin/$1" <<EOF
#!/bin/bash
me="\$(basename "\$0")"
echo "\$me \$*" >> "$LOG"
IFS='|'
for f in \${STUB_FAIL:-}; do
    case "\$me \$*" in "\$f"*) exit 1 ;; esac
done
printf '%s\n' '${2:-}'
EOF
    chmod +x "$SB/bin/$1"
}

# Run make in the real repo with the sandbox HOME and stubs first on PATH.
mk() {
    set +e
    out="$(cd "$ROOT" && HOME="$FAKEHOME" PATH="$SB/bin:$PATH" make "$@" 2>&1)"
    status=$?
    set -e
}

test_link_karabiner_is_idempotent() {
    sandbox
    mk link-karabiner
    mk link-karabiner
    if [ "$status" -eq 0 ] && [ "$(readlink "$FAKEHOME/.config/karabiner")" = "$ROOT/karabiner" ]; then
        ok "link-karabiner runs twice and leaves the link pointing at the repo"
    else
        bad "link-karabiner second run: status=$status out=$out"
    fi
}

test_link_karabiner_refuses_real_directory() {
    sandbox
    mkdir -p "$FAKEHOME/.config/karabiner"
    mk link-karabiner
    if [ "$status" -ne 0 ] && echo "$out" | grep -q "not a symlink" && [ -d "$FAKEHOME/.config/karabiner" ]; then
        ok "link-karabiner refuses to replace a real directory"
    else
        bad "link-karabiner real dir: status=$status out=$out"
    fi
}

test_link_sublime_skips_existing_clone() {
    sandbox
    stub git
    mkdir -p "$FAKEHOME/.sublime3/.git" "$FAKEHOME/Library/Application Support"
    mk link-sublime
    mk link-sublime
    if [ "$status" -eq 0 ] && ! grep -q '^git clone' "$LOG" \
        && [ "$(readlink "$FAKEHOME/Library/Application Support/Sublime Text")" = "$FAKEHOME/.sublime3" ]; then
        ok "link-sublime skips the clone when ~/.sublime3 exists and links once"
    else
        bad "link-sublime existing: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_brew_install_skips_when_present() {
    sandbox
    stub curl
    printf '#!/bin/bash\n' > "$SB/brew"; chmod +x "$SB/brew"
    mk brew-install BREW="$SB/brew"
    if [ "$status" -eq 0 ] && echo "$out" | grep -q "already installed" && ! grep -q '^curl' "$LOG"; then
        ok "brew-install skips the installer when brew exists"
    else
        bad "brew-install skip: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_set_shell_skips_when_already_set() {
    sandbox
    stub sudo
    stub chsh
    stub dscl "UserShell: $SB/bash"
    printf '#!/bin/bash\n' > "$SB/bash"; chmod +x "$SB/bash"
    echo "$SB/bash" > "$SB/shells"
    mk set-shell BREW_BASH="$SB/bash" SHELLS_FILE="$SB/shells"
    if [ "$status" -eq 0 ] && ! grep -q '^chsh' "$LOG" && ! grep -q '^sudo' "$LOG"; then
        ok "set-shell does nothing when /etc/shells and the login shell already match"
    else
        bad "set-shell skip: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_set_shell_appends_and_changes() {
    sandbox
    stub chsh
    stub dscl "UserShell: /bin/zsh"
    # sudo stub that actually runs its command so `sudo tee -a` appends.
    printf '#!/bin/bash\necho "sudo $*" >> "%s"\nexec "$@"\n' "$LOG" > "$SB/bin/sudo"; chmod +x "$SB/bin/sudo"
    printf '#!/bin/bash\n' > "$SB/bash"; chmod +x "$SB/bash"
    : > "$SB/shells"
    mk set-shell BREW_BASH="$SB/bash" SHELLS_FILE="$SB/shells"
    if [ "$status" -eq 0 ] && grep -qx "$SB/bash" "$SB/shells" && grep -q "^chsh -s $SB/bash" "$LOG"; then
        ok "set-shell appends the shell and runs chsh when they differ"
    else
        bad "set-shell change: status=$status out=$out shells=$(cat "$SB/shells") log=$(cat "$LOG")"
    fi
}

test_set_shell_requires_brew_bash() {
    sandbox
    mk set-shell BREW_BASH="$SB/missing" SHELLS_FILE="$SB/shells"
    if [ "$status" -ne 0 ] && echo "$out" | grep -q "brew-bundle"; then
        ok "set-shell fails with a pointer to brew-bundle when the shell is missing"
    else
        bad "set-shell missing: status=$status out=$out"
    fi
}

test_link_karabiner_is_idempotent
test_link_karabiner_refuses_real_directory
test_link_sublime_skips_existing_clone
test_brew_install_skips_when_present
test_set_shell_skips_when_already_set
test_set_shell_appends_and_changes
test_set_shell_requires_brew_bash

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

Make it executable: `chmod +x test/test_setup.sh`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `./test/test_setup.sh`
Expected: `link-karabiner` second run FAILs (`ln: File exists`), `link-sublime` FAILs on the clone, `brew-install` FAILs (no `BREW` variable; the stub curl is called), `set-shell` FAILs three times (no such target). Seven FAIL lines, exit 1.

- [ ] **Step 3: Rewrite the five targets and add `setup`**

Replace `Makefile` lines 7-8 with:

```makefile
BREW ?= /opt/homebrew/bin/brew
BREW_BASH ?= /opt/homebrew/bin/bash
SHELLS_FILE ?= /etc/shells

brew-install:
	@if [ -x "$(BREW)" ]; then \
		echo "brew already installed at $(BREW)"; \
	else \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	fi

# Make the brew bash the login shell. Replaces the README's inline block;
# safe to re-run, and the only step of setup.sh that needs sudo without a
# defaults write behind it.
set-shell:
	@[ -x "$(BREW_BASH)" ] || { echo "error: $(BREW_BASH) missing; run make brew-bundle first" >&2; exit 1; }
	@grep -qx "$(BREW_BASH)" "$(SHELLS_FILE)" || echo "$(BREW_BASH)" | sudo tee -a "$(SHELLS_FILE)" >/dev/null
	@if [ "$$(dscl . -read ~ UserShell | awk '{print $$2}')" = "$(BREW_BASH)" ]; then \
		echo "login shell already $(BREW_BASH)"; \
	else \
		chsh -s "$(BREW_BASH)"; \
	fi

# setup.sh is the one entry point for a new or existing machine; `make setup`
# is the alias, ARGS passes flags through (make setup ARGS=--dry-run).
setup:
	./setup.sh $(ARGS)
```

Replace `Makefile` lines 173-181 (`link-karabiner` and `link-sublime`) with:

```makefile
link-karabiner:
	# don't link entire .config directory because it may contain secrets
	@mkdir -p $$HOME/.config
	@if [ "$$(readlink $$HOME/.config/karabiner 2>/dev/null)" = "$$PWD/karabiner" ]; then \
		echo "karabiner already linked"; \
	elif [ -e $$HOME/.config/karabiner ] && [ ! -L $$HOME/.config/karabiner ]; then \
		echo "error: $$HOME/.config/karabiner exists and is not a symlink; move it aside" >&2; exit 1; \
	else \
		ln -sfn $$PWD/karabiner $$HOME/.config/karabiner; \
	fi

link-sublime:
	@[ -d $$HOME/.sublime3/.git ] || git clone https://github.com/nonrational/sublime3 $$HOME/.sublime3
	@if [ "$$(readlink "$$HOME/Library/Application Support/Sublime Text" 2>/dev/null)" != "$$HOME/.sublime3" ]; then \
		rm -rf "$$HOME/Library/Application Support/Sublime Text"; \
		ln -s $$HOME/.sublime3 "$$HOME/Library/Application Support/Sublime Text"; \
	fi
```

In `macos-disable-restore-apps-on-login`, insert a line before the `tee` so a re-run can write the immutable file:

```makefile
macos-disable-restore-apps-on-login:
	# See https://apple.stackexchange.com/a/322787
	# clear the file if it isn't empty (lifting the flag a previous run set)
	find ~/Library/Preferences/ByHost/ -name 'com.apple.loginwindow*' -exec chflags nouimmutable {} \;
	find ~/Library/Preferences/ByHost/ -name 'com.apple.loginwindow*' ! -size 0 -exec tee {} \; < /dev/null
	# set the user immutable flag
	find ~/Library/Preferences/ByHost/ -name 'com.apple.loginwindow*' -exec chflags uimmutable {} \;
```

Add `./test/test_setup.sh` as the last line of the `test:` target. In `.PHONY`, remove `macos-setup` and `init-post-reboot` (they name no target) and add `setup set-shell`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./test/test_setup.sh && make check-editorconfig`
Expected: `7 passed, 0 failed`, editorconfig clean. Then `make test` still passes end to end.

- [ ] **Step 5: Commit**

```bash
git add Makefile test/test_setup.sh
git commit -F - <<'EOF'
Make the setup targets re-runnable and add the setup alias

link-karabiner and link-sublime failed on a second run, brew-install
re-ran the installer, and the login shell block lived only in the README.
Each target now checks its own end state first, set-shell owns the
/etc/shells and chsh logic, and macos-disable-restore-apps-on-login lifts
the immutable flag it set last time before writing.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 2: The harness, `scripts/setup-lib.sh`

**Files:**
- Create: `scripts/setup-lib.sh`
- Modify: `test/test_setup.sh` (append the lib tests before the call list)

**Interfaces:**
- Consumes: `scripts/host-id.sh` (`os_id`).
- Produces, for a sourcing script that has set `SETUP_ROOT` and defines `setup_darwin` and `setup_linux`:
  - `step <name> <guard-fn> <run-fn>`: prints `skip: <name>` when the guard exits 0; else `would: <name>` under dry-run or `run: <name>` then runs.
  - `first_run_step <name> <run-fn>`: as `step`, gated on `SETUP_FIRST_RUN=1`; prints `skip: <name> (first run only)` otherwise.
  - `checkpoint <n> <message...>`: prints `checkpoint <n>: <message>` and `re-run setup.sh when done.`, exits 1.
  - `run_setup "$@"`: parses `--dry-run`/`-h`/`--help` (anything else: usage, exit 2), sets `SETUP_DRY_RUN`, reopens stdin from `/dev/tty` when stdin is not a tty and `/dev/tty` opens, dispatches on `os_id`, prints `setup: converged (<os>)`.
  - Variables `SETUP_DRY_RUN` (0/1) and `SETUP_FIRST_RUN` (0/1).

- [ ] **Step 1: Write the failing tests**

Append to `test/test_setup.sh`, above the call list. The fixture is a tiny script that sources the lib the way `setup.sh` will.

```bash
# --- setup-lib.sh ----------------------------------------------------------

# A minimal sourcing script: two guards, three runs, and both OS entry points.
lib_fixture() {
    mkdir -p "$SB/repo/scripts"
    cp "$ROOT/scripts/setup-lib.sh" "$SB/repo/scripts/"
    cp "$ROOT/scripts/host-id.sh" "$SB/repo/scripts/"
    cat > "$SB/repo/fixture.sh" <<'EOF'
#!/bin/bash
set -euf -o pipefail
SETUP_ROOT="$(cd "$(dirname "$0")" && pwd)"
. "$SETUP_ROOT/scripts/setup-lib.sh"
holds() { return 0; }
fails() { return 1; }
run_a() { echo "ran a"; }
run_b() { echo "ran b"; }
run_c() { echo "ran c"; }
setup_darwin() {
    step "a" holds run_a
    step "b" fails run_b
    first_run_step "c" run_c
    if [ "${FIXTURE_CHECKPOINT:-0}" = 1 ]; then checkpoint 7 "do the thing"; fi
    echo "after checkpoint"
}
setup_linux() { echo "linux path"; }
run_setup "$@"
EOF
    chmod +x "$SB/repo/fixture.sh"
}

# Run the fixture with a stubbed uname and the sandbox HOME.
fixture() {
    set +e
    out="$(HOME="$FAKEHOME" PATH="$SB/bin:$PATH" "$SB/repo/fixture.sh" "$@" 2>&1 </dev/null)"
    status=$?
    set -e
}

test_step_skips_runs_and_reports() {
    sandbox; lib_fixture; stub uname Darwin
    fixture
    if [ "$status" -eq 0 ] && echo "$out" | grep -q '^skip: a$' && echo "$out" | grep -q '^run: b$' \
        && echo "$out" | grep -q '^ran b$' && ! echo "$out" | grep -q 'ran a'; then
        ok "step skips when the guard holds and runs when it fails"
    else
        bad "step: status=$status out=$out"
    fi
}

test_dry_run_would_not_run() {
    sandbox; lib_fixture; stub uname Darwin
    fixture --dry-run
    if [ "$status" -eq 0 ] && echo "$out" | grep -q '^would: b$' && ! echo "$out" | grep -q 'ran b'; then
        ok "--dry-run prints would: and runs nothing"
    else
        bad "dry-run: status=$status out=$out"
    fi
}

test_first_run_step_is_gated() {
    sandbox; lib_fixture; stub uname Darwin
    fixture
    local off="$out"
    SETUP_FIRST_RUN=1 fixture
    if echo "$off" | grep -q '^skip: c (first run only)$' && echo "$out" | grep -q '^ran c$'; then
        ok "first_run_step runs only when SETUP_FIRST_RUN=1"
    else
        bad "first_run: off=$off on=$out"
    fi
}

test_checkpoint_halts_with_exit_1() {
    sandbox; lib_fixture; stub uname Darwin
    FIXTURE_CHECKPOINT=1 fixture
    if [ "$status" -eq 1 ] && echo "$out" | grep -q '^checkpoint 7: do the thing$' \
        && echo "$out" | grep -q '^re-run setup.sh when done.$' && ! echo "$out" | grep -q 'after checkpoint'; then
        ok "checkpoint prints its instruction and exits 1 before later steps"
    else
        bad "checkpoint: status=$status out=$out"
    fi
}

test_converged_line_and_linux_dispatch() {
    sandbox; lib_fixture; stub uname Linux
    fixture
    if [ "$status" -eq 0 ] && echo "$out" | grep -q '^linux path$' && echo "$out" | grep -q '^setup: converged (Linux)$'; then
        ok "run_setup dispatches on uname and prints the converged line"
    else
        bad "dispatch: status=$status out=$out"
    fi
}

test_unknown_flag_is_usage_error() {
    sandbox; lib_fixture; stub uname Darwin
    fixture --bogus
    if [ "$status" -eq 2 ] && echo "$out" | grep -q '^usage: setup.sh'; then
        ok "an unknown flag prints usage and exits 2"
    else
        bad "usage: status=$status out=$out"
    fi
}

test_unsupported_os_fails() {
    sandbox; lib_fixture; stub uname Plan9
    fixture
    if [ "$status" -eq 1 ] && echo "$out" | grep -q 'unsupported OS Plan9'; then
        ok "an unsupported OS exits 1 with its name"
    else
        bad "unsupported: status=$status out=$out"
    fi
}

test_run_without_tty_survives() {
    # fixture() already redirects stdin from /dev/null; with no controlling
    # terminal (CI) the /dev/tty reopen must be skipped, not fatal.
    sandbox; lib_fixture; stub uname Linux
    fixture
    if [ "$status" -eq 0 ]; then
        ok "a run with stdin not a tty completes"
    else
        bad "no-tty: status=$status out=$out"
    fi
}
```

Add these eight names to the call list before the summary lines.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `./test/test_setup.sh`
Expected: the seven Task 1 tests PASS; the eight lib tests FAIL with `setup-lib.sh: No such file`.

- [ ] **Step 3: Write the lib**

Create `scripts/setup-lib.sh`:

```bash
#!/bin/bash
# setup-lib.sh: the harness behind setup.sh. A step runner with guards, a
# first-run gate, checkpoints that halt for a human, --dry-run, and OS
# dispatch. Sourced by a setup.sh that sets SETUP_ROOT and defines
# setup_darwin and setup_linux; never executed directly. Vendored downstream
# beside deploy.sh, so nothing here names a repo or a make target.
# Spec: docs/superpowers/specs/2026-09-25-setup-script-design.md

: "${SETUP_ROOT:?setup-lib.sh: the sourcing script must set SETUP_ROOT}"
. "$SETUP_ROOT/scripts/host-id.sh"

SETUP_DRY_RUN=0
SETUP_FIRST_RUN="${SETUP_FIRST_RUN:-0}"

# step <name> <guard> <run>: skip when the guard exits 0; otherwise run, or
# under --dry-run say what would run. Guards and runs are function names.
step() {
    local name="$1" guard="$2" run="$3"
    if "$guard"; then
        echo "skip: $name"
        return 0
    fi
    if [ "$SETUP_DRY_RUN" = 1 ]; then
        echo "would: $name"
        return 0
    fi
    echo "run: $name"
    "$run"
}

# first_run_step <name> <run>: runs only when the self-clone marked this run
# as the first on the machine. There is no guard: these steps are the
# destructive ones, and the clone is the only evidence they are wanted.
first_run_step() {
    local name="$1" run="$2"
    if [ "$SETUP_FIRST_RUN" != 1 ]; then
        echo "skip: $name (first run only)"
        return 0
    fi
    if [ "$SETUP_DRY_RUN" = 1 ]; then
        echo "would: $name"
        return 0
    fi
    echo "run: $name"
    "$run"
}

# checkpoint <n> <message...>: halt for a human. Exit 1 so a wrapper can tell
# "halted" (1) from "converged" (0) and from a failed step (make exits 2).
checkpoint() {
    local n="$1"
    shift
    echo
    echo "checkpoint $n: $*"
    echo "re-run setup.sh when done."
    exit 1
}

setup_usage() {
    echo "usage: setup.sh [--dry-run]"
}

run_setup() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run) SETUP_DRY_RUN=1 ;;
            -h | --help) setup_usage; exit 0 ;;
            *) setup_usage >&2; exit 2 ;;
        esac
    done
    # Under `curl | bash` stdin is the script itself. Give sudo and gh their
    # prompts back when there is a terminal to give; CI has none, so skip.
    if [ ! -t 0 ] && [ "$SETUP_DRY_RUN" != 1 ] && ( : </dev/tty ) 2>/dev/null; then
        exec </dev/tty
    fi
    case "$(os_id)" in
        Darwin) setup_darwin ;;
        Linux) setup_linux ;;
        *)
            echo "error: unsupported OS $(os_id)" >&2
            exit 1
            ;;
    esac
    echo
    echo "setup: converged ($(os_id))"
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./test/test_setup.sh && make check-editorconfig && grep -n 'nonrational\|make ' scripts/setup-lib.sh`
Expected: `15 passed, 0 failed`, editorconfig clean, and the grep prints nothing (the lib names no repo and no target).

- [ ] **Step 5: Commit**

```bash
git add scripts/setup-lib.sh test/test_setup.sh
git commit -F - <<'EOF'
Add the setup harness: steps, first-run gate, checkpoints, dry-run

The runner is separate from the step list so nonreagent/dotfiles can vendor
it beside deploy.sh. A checkpoint exits 1, a converged run 0, and a failed
step keeps make's 2, so a wrapper can tell the three apart.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 3: `setup.sh`: self-bootstrap and the step lists

**Files:**
- Create: `setup.sh` (repo root, executable)
- Modify: `test/test_setup.sh` (append), `docs/superpowers/specs/2026-09-25-setup-script-design.md` (the "Split" section: self-bootstrap lives in `setup.sh`)

**Interfaces:**
- Consumes: `step`, `first_run_step`, `checkpoint`, `run_setup` from Task 2; the make targets from Task 1 plus the existing `brew-bundle`, `init-submodules`, `deploy`, `clipboard-bridge`, `restore-preferences`, `macos-reset-dock`, `macos-doctor`, `macos-apply`; `scripts/macos-bootstrap.sh`; `deploy.sh audit`.
- Produces: `setup.sh [--dry-run]`, honoring `SETUP_REPO_URL`, `SETUP_CLONE_DIR`, `SETUP_BREW`, `SETUP_BREW_BASH`, `SETUP_ETC_SHELLS` (all with production defaults; tests override them).

- [ ] **Step 1: Write the failing tests**

Append to `test/test_setup.sh` above the call list:

```bash
# --- setup.sh --------------------------------------------------------------

# A sandbox repo: the real setup.sh and lib, a stub deploy.sh whose audit
# result is $STUB_DEPLOY_AUDIT (0/1), a stub macos-bootstrap.sh, a karabiner
# dir, one declared submodule, and a .git dir so the checkout detection holds.
setup_repo() {
    REPO="$SB/repo"
    mkdir -p "$REPO/scripts" "$REPO/karabiner" "$REPO/.git" "$REPO/etc/sub"
    cp "$ROOT/setup.sh" "$REPO/setup.sh"
    cp "$ROOT/scripts/setup-lib.sh" "$ROOT/scripts/host-id.sh" "$REPO/scripts/"
    printf '[submodule "sub"]\n\tpath = etc/sub\n\turl = x\n' > "$REPO/.gitmodules"
    printf '#!/bin/bash\necho "deploy.sh $*" >> "%s"\n[ "$1" = audit ] && exit "${STUB_DEPLOY_AUDIT:-1}"\nexit 0\n' "$LOG" > "$REPO/deploy.sh"
    printf '#!/bin/bash\necho "macos-bootstrap.sh" >> "%s"\n' "$LOG" > "$REPO/scripts/macos-bootstrap.sh"
    chmod +x "$REPO/deploy.sh" "$REPO/scripts/macos-bootstrap.sh"
    printf '#!/bin/bash\n[ "$1" = shellenv ] && exit 0\n' > "$SB/brew"; chmod +x "$SB/brew"
    printf '#!/bin/bash\n' > "$SB/bash"; chmod +x "$SB/bash"
    echo "$SB/bash" > "$SB/shells"
}

# Stubs describing a fully converged Mac; tests knock out one at a time.
converged_mac() {
    stub uname Darwin
    stub xcode-select
    stub make
    stub dscl "UserShell: $SB/bash"
    stub launchctl "org.nonrational.clipboard-bridge"
    stub gh
    stub osascript
    echo x > "$REPO/etc/sub/file"
    mkdir -p "$FAKEHOME/.config" "$FAKEHOME/.sublime3/.git" "$FAKEHOME/Library/Application Support" "$FAKEHOME/Library/Preferences/ByHost"
    ln -s "$REPO/karabiner" "$FAKEHOME/.config/karabiner"
    ln -s "$FAKEHOME/.sublime3" "$FAKEHOME/Library/Application Support/Sublime Text"
    : > "$FAKEHOME/Library/Preferences/ByHost/com.apple.loginwindow.ABC.plist"
    export STUB_DEPLOY_AUDIT=0
}

setup_run() {
    set +e
    out="$(HOME="$FAKEHOME" PATH="$SB/bin:$PATH" SETUP_BREW="$SB/brew" SETUP_BREW_BASH="$SB/bash" \
        SETUP_ETC_SHELLS="$SB/shells" "$REPO/setup.sh" "$@" 2>&1 </dev/null)"
    status=$?
    set -e
}

# The make targets, in the order setup.sh must call them on a Mac that has
# nothing yet (first run, deploy audit failing, every guard false).
MAC_ORDER="brew-install brew-bundle set-shell init-submodules deploy link-karabiner clipboard-bridge link-sublime restore-preferences macos-reset-dock macos-disable-restore-apps-on-login macos-doctor macos-apply"

test_mac_runs_every_target_in_order_on_first_run() {
    sandbox; setup_repo
    stub uname Darwin; stub xcode-select; stub make; stub dscl "UserShell: /bin/zsh"; stub launchctl; stub gh; stub osascript
    export STUB_DEPLOY_AUDIT=1 STUB_FAIL='gh auth status'
    SETUP_FIRST_RUN=1 setup_run
    unset STUB_FAIL
    local targets
    targets="$(grep '^make -C' "$LOG" | awk '{print $4}' | tr '\n' ' ' | sed 's/ $//')"
    if [ "$status" -eq 0 ] && [ "$targets" = "$MAC_ORDER" ] && grep -q '^gh auth login$' "$LOG" \
        && grep -q '^macos-bootstrap.sh$' "$LOG" && grep -q '^osascript' "$LOG"; then
        ok "first run on a bare Mac calls every target in order, then bootstrap and reboot"
    else
        bad "mac order: status=$status targets=[$targets] out=$out"
    fi
}

test_mac_converged_is_all_skips() {
    sandbox; setup_repo; converged_mac
    setup_run
    if [ "$status" -eq 0 ] && ! grep -q '^make -C .* \(brew-install\|set-shell\|init-submodules\|deploy\|link-karabiner\|clipboard-bridge\|link-sublime\|macos-disable-restore-apps-on-login\)$' "$LOG" \
        && ! grep -q '^gh auth login' "$LOG" && ! grep -q 'restore-preferences\|macos-reset-dock' "$LOG" \
        && echo "$out" | grep -q '^skip: restore-preferences (first run only)$'; then
        ok "a converged Mac skips every guarded target and the first-run steps"
    else
        bad "converged: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_mac_dry_run_runs_nothing() {
    sandbox; setup_repo
    stub uname Darwin; stub xcode-select; stub make; stub dscl "UserShell: /bin/zsh"; stub launchctl; stub gh; stub osascript
    export STUB_DEPLOY_AUDIT=1
    setup_run --dry-run
    if [ "$status" -eq 0 ] && ! grep -q '^make' "$LOG" && ! grep -q '^osascript' "$LOG" \
        && echo "$out" | grep -q '^would: deploy$' && echo "$out" | grep -q '^would: reboot$'; then
        ok "--dry-run reports every pending step and calls no target"
    else
        bad "dry-run: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_missing_clt_is_checkpoint_1() {
    sandbox; setup_repo
    stub uname Darwin; stub xcode-select; stub make
    STUB_FAIL='xcode-select -p' setup_run
    if [ "$status" -eq 1 ] && echo "$out" | grep -q '^checkpoint 1: ' && grep -q '^xcode-select --install' "$LOG" && ! grep -q '^make' "$LOG"; then
        ok "missing Command Line Tools halts at checkpoint 1 before any target"
    else
        bad "clt: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_doctor_failure_is_checkpoint_2() {
    sandbox; setup_repo; converged_mac
    STUB_FAIL="make -C $REPO macos-doctor" setup_run
    if [ "$status" -eq 1 ] && echo "$out" | grep -q '^checkpoint 2: .*Full Disk Access' && ! grep -q 'macos-apply' "$LOG"; then
        ok "a failing macos-doctor halts at checkpoint 2 before apply"
    else
        bad "doctor: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_failed_step_stops_run() {
    sandbox; setup_repo; converged_mac
    export STUB_DEPLOY_AUDIT=1
    STUB_FAIL="make -C $REPO deploy" setup_run
    if [ "$status" -ne 0 ] && [ "$status" -ne 1 ] && ! grep -q 'link-karabiner\|macos-doctor' "$LOG"; then
        ok "a failing step stops the run with its own exit code, not the checkpoint's"
    else
        bad "failed step: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_linux_runs_only_submodules_and_deploy() {
    sandbox; setup_repo
    stub uname Linux; stub make
    export STUB_DEPLOY_AUDIT=1
    SETUP_FIRST_RUN=1 setup_run
    local targets
    targets="$(grep '^make -C' "$LOG" | awk '{print $4}' | tr '\n' ' ' | sed 's/ $//')"
    if [ "$status" -eq 0 ] && [ "$targets" = "init-submodules deploy" ]; then
        ok "Linux runs init-submodules and deploy and nothing else"
    else
        bad "linux: status=$status targets=[$targets] out=$out"
    fi
}

# Piped runs: `cat setup.sh | bash` from outside any checkout.
pipe_run() {
    set +e
    out="$(cd "$SB" && cat "$ROOT/setup.sh" | HOME="$FAKEHOME" PATH="$SB/bin:$PATH" \
        SETUP_REPO_URL="https://example.invalid/dotfiles" bash -s -- "$@" 2>&1)"
    status=$?
    set -e
}

# A git stub whose clone creates a fake checkout with a setup.sh that reports
# how it was exec'd.
stub_git_clone() {
    cat > "$SB/bin/git" <<EOF
#!/bin/bash
echo "git \$*" >> "$LOG"
if [ "\$1" = clone ]; then
    mkdir -p "\$3/.git"
    cat > "\$3/setup.sh" <<'INNER'
#!/bin/bash
echo "exec-ed first_run=\${SETUP_FIRST_RUN:-0} args=\$*"
INNER
    chmod +x "\$3/setup.sh"
fi
EOF
    chmod +x "$SB/bin/git"
}

test_pipe_clones_and_execs_as_first_run() {
    sandbox; stub uname Linux; stub_git_clone
    pipe_run
    if [ "$status" -eq 0 ] && grep -q "^git clone https://example.invalid/dotfiles $FAKEHOME/.dotfiles$" "$LOG" \
        && echo "$out" | grep -q '^exec-ed first_run=1 args=$'; then
        ok "piped from outside a checkout, setup.sh clones and execs the clone as a first run"
    else
        bad "pipe clone: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_pipe_reuses_existing_clone() {
    sandbox; stub uname Linux; stub_git_clone
    mkdir -p "$FAKEHOME/.dotfiles/.git"
    printf '#!/bin/bash\necho "exec-ed first_run=${SETUP_FIRST_RUN:-0} args=$*"\n' > "$FAKEHOME/.dotfiles/setup.sh"
    chmod +x "$FAKEHOME/.dotfiles/setup.sh"
    pipe_run
    if [ "$status" -eq 0 ] && ! grep -q '^git clone' "$LOG" && echo "$out" | grep -q '^exec-ed first_run=0 args=$'; then
        ok "piped with ~/.dotfiles present, setup.sh execs it without marking a first run"
    else
        bad "pipe reuse: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_pipe_dry_run_does_not_clone() {
    sandbox; stub uname Linux; stub_git_clone
    pipe_run --dry-run
    if [ "$status" -eq 0 ] && ! grep -q '^git clone' "$LOG" && echo "$out" | grep -q '^would: clone https://example.invalid/dotfiles'; then
        ok "piped --dry-run reports the clone and does nothing"
    else
        bad "pipe dry-run: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_pipe_on_mac_without_clt_is_checkpoint_1() {
    sandbox; stub uname Darwin; stub xcode-select; stub_git_clone
    STUB_FAIL='xcode-select -p' pipe_run
    if [ "$status" -eq 1 ] && echo "$out" | grep -q '^checkpoint 1: ' && ! grep -q '^git clone' "$LOG"; then
        ok "piped on a Mac without Command Line Tools halts at checkpoint 1 before cloning"
    else
        bad "pipe clt: status=$status out=$out log=$(cat "$LOG")"
    fi
}
```

Add these eleven names to the call list.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `./test/test_setup.sh 2>&1 | grep -c FAIL`
Expected: `11` (the new tests fail with `setup.sh: No such file`; the fifteen earlier tests pass).

- [ ] **Step 3: Write `setup.sh`**

Create `setup.sh` at the repo root and `chmod +x` it:

```bash
#!/bin/bash
# setup.sh: bring this machine to the state the repo describes. Re-runnable:
# every step skips when its guard holds, three checkpoints halt for a human,
# and the two destructive steps run only when this script had to clone.
# Spec: docs/superpowers/specs/2026-09-25-setup-script-design.md
#
#   curl -fsSL https://raw.githubusercontent.com/nonrational/dotfiles/main/setup.sh | bash
#   ./setup.sh [--dry-run]
set -euf -o pipefail

SETUP_REPO_URL="${SETUP_REPO_URL:-https://github.com/nonrational/dotfiles}"
SETUP_CLONE_DIR="${SETUP_CLONE_DIR:-$HOME/.dotfiles}"
SETUP_BREW="${SETUP_BREW:-/opt/homebrew/bin/brew}"
SETUP_BREW_BASH="${SETUP_BREW_BASH:-/opt/homebrew/bin/bash}"
SETUP_ETC_SHELLS="${SETUP_ETC_SHELLS:-/etc/shells}"

# Under `curl | bash` there is no file on disk and no lib to source, so this
# part cannot live in setup-lib.sh. Clone, mark the first run, and exec the
# on-disk copy; everything after this runs from a checkout.
setup_self_bootstrap() {
    local here=""
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    if [ -n "$here" ] && [ -f "$here/scripts/setup-lib.sh" ]; then
        SETUP_ROOT="$here"
        return 0
    fi
    case " $* " in
        *" --dry-run "*)
            echo "would: clone $SETUP_REPO_URL -> $SETUP_CLONE_DIR"
            exit 0
            ;;
    esac
    if [ "$(uname)" = Darwin ] && ! xcode-select -p >/dev/null 2>&1; then
        xcode-select --install >/dev/null 2>&1 || true
        echo
        echo "checkpoint 1: finish the Command Line Tools installer."
        echo "re-run setup.sh when done."
        exit 1
    fi
    if [ ! -d "$SETUP_CLONE_DIR/.git" ]; then
        git clone "$SETUP_REPO_URL" "$SETUP_CLONE_DIR"
        export SETUP_FIRST_RUN=1
    fi
    exec "$SETUP_CLONE_DIR/setup.sh" "$@"
}

mk() {
    make -C "$SETUP_ROOT" "$@"
}

# --- guards: exit 0 when the step's end state already holds -----------------

have_clt() { xcode-select -p >/dev/null 2>&1; }
have_brew() { [ -x "$SETUP_BREW" ]; }
shell_is_brew() {
    grep -qx "$SETUP_BREW_BASH" "$SETUP_ETC_SHELLS" 2>/dev/null \
        && [ "$(dscl . -read ~ UserShell 2>/dev/null | awk '{print $2}')" = "$SETUP_BREW_BASH" ]
}
submodules_present() {
    local path
    while read -r path; do
        [ -n "$(ls -A "$SETUP_ROOT/$path" 2>/dev/null)" ] || return 1
    done < <(git config -f "$SETUP_ROOT/.gitmodules" --get-regexp '\.path$' | awk '{print $2}')
    return 0
}
deployed() { "$SETUP_ROOT/deploy.sh" audit >/dev/null 2>&1; }
karabiner_linked() { [ "$(readlink "$HOME/.config/karabiner" 2>/dev/null)" = "$SETUP_ROOT/karabiner" ]; }
bridge_loaded() { launchctl list 2>/dev/null | grep -q org.nonrational.clipboard-bridge; }
gh_authed() { gh auth status >/dev/null 2>&1; }
sublime_linked() {
    [ -d "$HOME/.sublime3/.git" ] \
        && [ "$(readlink "$HOME/Library/Application Support/Sublime Text" 2>/dev/null)" = "$HOME/.sublime3" ]
}
restore_disabled() {
    [ -d "$HOME/Library/Preferences/ByHost" ] \
        && [ -z "$(find "$HOME/Library/Preferences/ByHost" -name 'com.apple.loginwindow*' ! -size 0 2>/dev/null)" ]
}
never() { return 1; }

# --- runs -------------------------------------------------------------------

clt_checkpoint() {
    xcode-select --install >/dev/null 2>&1 || true
    checkpoint 1 "finish the Command Line Tools installer."
}
brew_install() { mk brew-install; }
brew_bundle() { mk brew-bundle; }
set_shell() { mk set-shell; }
init_submodules() { mk init-submodules; }
deploy() { mk deploy; }
link_karabiner() { mk link-karabiner; }
clipboard_bridge() { mk clipboard-bridge; }
gh_login() { gh auth login; }
link_sublime() { mk link-sublime; }
restore_preferences() { mk restore-preferences; }
reset_dock() { mk macos-reset-dock; }
disable_restore() { mk macos-disable-restore-apps-on-login; }
doctor_or_halt() {
    mk macos-doctor \
        || checkpoint 2 "grant Full Disk Access to this terminal (System Settings > Privacy & Security), then restart the terminal."
}
apply_macos() {
    mk macos-apply
    "$SETUP_ROOT/scripts/macos-bootstrap.sh"
}
reboot_mac() {
    echo "checkpoint 3: rebooting. Run setup.sh once more afterwards; it should report every step as skip."
    osascript -e 'tell app "loginwindow" to «event aevtrrst»'
}

setup_darwin() {
    step "command line tools" have_clt clt_checkpoint
    step "brew-install" have_brew brew_install
    if have_brew; then
        eval "$("$SETUP_BREW" shellenv)"
    fi
    step "brew-bundle" never brew_bundle
    step "set-shell" shell_is_brew set_shell
    step "init-submodules" submodules_present init_submodules
    step "deploy" deployed deploy
    step "link-karabiner" karabiner_linked link_karabiner
    step "clipboard-bridge" bridge_loaded clipboard_bridge
    step "gh auth login" gh_authed gh_login
    step "link-sublime" sublime_linked link_sublime
    first_run_step "restore-preferences" restore_preferences
    first_run_step "macos-reset-dock" reset_dock
    step "macos-disable-restore-apps-on-login" restore_disabled disable_restore
    step "macos-doctor" never doctor_or_halt
    step "macos-apply + macos-bootstrap" never apply_macos
    step "reboot" never reboot_mac
}

setup_linux() {
    step "init-submodules" submodules_present init_submodules
    step "deploy" deployed deploy
}

main() {
    setup_self_bootstrap "$@"
    # shellcheck source=scripts/setup-lib.sh
    . "$SETUP_ROOT/scripts/setup-lib.sh"
    run_setup "$@"
}

main "$@"
```

Two notes for the implementer. `brew-bundle` has no guard on purpose: `brew bundle` is its own guard and the step line stays so `--dry-run` lists it. The `eval "$(brew shellenv)"` is inside `if have_brew` so a dry run on a machine without brew does not fail there.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./test/test_setup.sh && make check-editorconfig && ./setup.sh --dry-run`
Expected: `26 passed, 0 failed`, editorconfig clean, and the real dry run on this Mac prints a `skip:` or `would:` line per step and `setup: converged (Darwin)` without running anything. If any real step prints `would:` unexpectedly, that is a guard reading this machine wrong; fix the guard, not the machine.

- [ ] **Step 5: Amend the spec for where the self-bootstrap lives**

In `docs/superpowers/specs/2026-09-25-setup-script-design.md`, under "Split: `scripts/setup-lib.sh` holds the harness", replace the sentence beginning "The harness is the reusable part and the tricky shell: self-clone, `/dev/tty` prompts," with:

```
The harness is the reusable part and the tricky shell: `/dev/tty` prompts, the first-run flag, `step`, `checkpoint`, the runner, `--dry-run`. The self-clone is the one piece that cannot live there, because under `curl | bash` no lib exists on disk yet; it is a short function at the top of each `setup.sh`, parameterized by `SETUP_REPO_URL` and `SETUP_CLONE_DIR`.
```

And in the four-function list, change the `run_setup` bullet to:

```
- `run_setup`: argument parsing, the `/dev/tty` reopen, the OS dispatch to `setup_darwin` or `setup_linux`, and the summary line.
```

- [ ] **Step 6: Commit**

```bash
git add setup.sh test/test_setup.sh docs/superpowers/specs/2026-09-25-setup-script-design.md
git commit -F - <<'EOF'
Add setup.sh: one re-runnable entry point for a Mac or a Linux host

Piped from curl it clones the repo and execs the clone as a first run;
from a checkout it walks the ordered step list, skipping each step whose
guard already holds. Three checkpoints halt for a human: the Command Line
Tools installer, Full Disk Access, and the reboot. The Dock reset and
preference restore run only on the first run the self-clone marks.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 4: CI, README, CLAUDE.md, and the bootstrap header

**Files:**
- Modify: `.github/workflows/ci.yml:36-39`, `README.md:9-56`, `CLAUDE.md:13-18` (Commands), `scripts/macos-bootstrap.sh:3-8`

**Interfaces:**
- Consumes: `setup.sh --dry-run` and the Linux path from Task 3.
- Produces: nothing code-facing.

- [ ] **Step 1: Wire CI**

Replace the final `run` step of `.github/workflows/ci.yml` (the `export HOME` block that calls `deploy.sh apply` and `audit`) with:

```yaml
      - run: ./setup.sh --dry-run

      # The real Linux path, twice: the second run must find nothing to do.
      - if: runner.os == 'Linux'
        run: |
          export HOME="$(mktemp -d)"
          ./setup.sh
          ./setup.sh | tee second-run.log
          grep -q '^skip: deploy$' second-run.log

      # The macOS path needs brew and sudo; keep exercising the deploy engine alone.
      - if: runner.os == 'macOS'
        run: |
          export HOME="$(mktemp -d)"
          ./deploy.sh apply
          ./deploy.sh audit
```

- [ ] **Step 2: Shrink the README**

Replace the `## macOS` and `## GNU/Linux` sections of `README.md` (from `## macOS` through the end of the Linux code block) with:

~~~markdown
## Any machine

```shell
curl -fsSL https://raw.githubusercontent.com/nonrational/dotfiles/main/setup.sh | bash
```

That is the whole sequence, for a new Mac, a Linux host, or a machine catching up after months. `setup.sh` clones this repo into `~/.dotfiles` if it has to, then runs every step whose end state does not already hold; re-run it any time with `./setup.sh` or `make setup` (`make setup ARGS=--dry-run` shows what a run would do). On a Mac it halts at three checkpoints, each printed with a number and the instruction to re-run when done:

1. The Command Line Tools installer, on a machine without them.
2. Full Disk Access for the terminal, which the `defaults` audit needs.
3. The reboot at the end.

The Dock reset and the iTerm, Amphetamine and Moom preference restore run only when `setup.sh` had to clone, so a re-run on an existing machine never wipes either. Linux runs only the submodule init and the deploy.
~~~

Leave the `# Clipboard bridge` section and everything after it as is.

- [ ] **Step 3: One line in CLAUDE.md and the bootstrap header**

In `CLAUDE.md`, add to the Commands list, after the `make test` line:

```
- `./setup.sh [--dry-run]` (alias `make setup ARGS=...`) — the one entry point for a new or existing machine, also the target of the README's curl line. Steps are guarded make targets in order; `scripts/setup-lib.sh` is the harness and is vendored by nonreagent/dotfiles, so it names no repo or target. Design: `docs/superpowers/specs/2026-09-25-setup-script-design.md`.
```

In `scripts/macos-bootstrap.sh`, change the header's last sentence from `Re-runnable; \`make macos\` runs it after applying the table.` to:

```
# app restarts. Re-runnable; setup.sh (and `make macos`) runs it after the
# table applies, immediately before the reboot.
```

- [ ] **Step 4: Verify**

Run: `make preflight`
Expected: every check passes, including `check-editorconfig` on the edited markdown and YAML. Then `./setup.sh --dry-run` once more to confirm nothing in this task changed its output.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml README.md CLAUDE.md scripts/macos-bootstrap.sh
git commit -F - <<'EOF'
Run setup.sh in CI and make it the README's whole install sequence

The ubuntu leg runs the real Linux path twice and requires the second run
to skip deploy, which proves convergence rather than just success. Both
legs dry-run the script. The README's two shell blocks become the curl
line and the three checkpoints.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 5: `scripts/new-exe-box.sh` and `make exe-box`

This task can ship as its own PR. The script is testable now with stubs, but it has nothing real to run until nonreagent/dotfiles has its `setup.sh` (a change in that repo, after this branch merges).

**Design deviation from the spec, to accept or reject at review.** The spec provisions through exe.dev's `--setup-script` at first boot and then re-runs `setup.sh` after injecting the token. That races: the wrapper cannot tell when the first-boot run has finished, and a second `setup.sh` starting while the first is still cloning collides in `~/.dotfiles`. This task instead creates the box bare, waits for ssh, injects the token, then runs the curl line over ssh itself. It is strictly sequential, needs no first-boot marker, runs as the ssh login user (so the "which user does first boot run as" question disappears), and costs nothing, since the human is waiting either way. Step 6 amends the spec.

**Files:**
- Create: `scripts/new-exe-box.sh` (executable)
- Modify: `Makefile` (add `exe-box` beside `setup`; `.PHONY`), `test/test_setup.sh` (append), `docs/superpowers/specs/2026-09-25-setup-script-design.md` (the `new-exe-box.sh` section)

**Interfaces:**
- Consumes: `ssh`, `op` on PATH; exe.dev's `ssh exe.dev new --name <n> --json`.
- Produces: `scripts/new-exe-box.sh <name>` honoring `EXE_BOX_SETUP_URL`, `EXE_BOX_GH_TOKEN_REF`, `EXE_BOX_WAIT` (seconds), `EXE_BOX_POLL` (seconds); exit 0 with `ready: <name>.exe.xyz https://<name>.exe.xyz/` on the last line; `make exe-box NAME=<name>`.

- [ ] **Step 1: Write the failing tests**

Append to `test/test_setup.sh` above the call list:

```bash
# --- new-exe-box.sh --------------------------------------------------------

# An ssh stub that logs each call, saves whatever arrived on stdin for the
# call that ran `gh auth login`, and fails `<host> true` the first
# $STUB_SSH_NOT_READY times so the wait loop has something to wait for.
stub_ssh() {
    cat > "$SB/bin/ssh" <<EOF
#!/bin/bash
echo "ssh \$*" >> "$LOG"
case "\$*" in
    *" true")
        n=\$(cat "$SB/notready" 2>/dev/null || echo 0)
        if [ "\$n" -lt "\${STUB_SSH_NOT_READY:-0}" ]; then echo \$((n + 1)) > "$SB/notready"; exit 255; fi
        ;;
    *"gh auth login"*) cat > "$SB/token.stdin" ;;
esac
exit 0
EOF
    chmod +x "$SB/bin/ssh"
}

exe_box() {
    set +e
    out="$(HOME="$FAKEHOME" PATH="$SB/bin:$PATH" EXE_BOX_POLL=0 EXE_BOX_WAIT="${EXE_BOX_WAIT:-5}" \
        EXE_BOX_SETUP_URL="https://example.invalid/setup.sh" \
        EXE_BOX_GH_TOKEN_REF="op://Vault/item/token" "$ROOT/scripts/new-exe-box.sh" "$@" 2>&1)"
    status=$?
    set -e
}

test_exe_box_creates_waits_injects_and_runs_setup() {
    sandbox; stub_ssh; stub op "tok-123"
    STUB_SSH_NOT_READY=2 exe_box mybox
    if [ "$status" -eq 0 ] \
        && grep -q '^ssh .*exe.dev new --name mybox --json$' "$LOG" \
        && [ "$(grep -c '^ssh .*mybox.exe.xyz true$' "$LOG")" -eq 3 ] \
        && grep -q '^op read op://Vault/item/token$' "$LOG" \
        && grep -q '^ssh .*mybox.exe.xyz gh auth login --with-token && gh auth setup-git$' "$LOG" \
        && grep -q '^ssh .*mybox.exe.xyz curl -fsSL https://example.invalid/setup.sh | bash$' "$LOG" \
        && [ "$(tail -1 <<<"$out")" = "ready: mybox.exe.xyz https://mybox.exe.xyz/" ]; then
        ok "new-exe-box creates the VM, waits for ssh, injects the token, runs setup, prints the URL"
    else
        bad "exe-box flow: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_token_goes_over_stdin_only() {
    sandbox; stub_ssh; stub op "tok-123"
    exe_box mybox
    if [ "$(cat "$SB/token.stdin")" = "tok-123" ] && ! grep -q 'tok-123' "$LOG" && ! echo "$out" | grep -q 'tok-123'; then
        ok "the token reaches ssh on stdin and appears in no argument or output"
    else
        bad "token: stdin=$(cat "$SB/token.stdin" 2>&1) log=$(cat "$LOG") out=$out"
    fi
}

test_exe_box_times_out_waiting() {
    sandbox; stub_ssh; stub op "tok-123"
    STUB_SSH_NOT_READY=99 EXE_BOX_WAIT=1 exe_box mybox
    if [ "$status" -eq 1 ] && echo "$out" | grep -q 'did not answer within 1s' && ! grep -q '^op read' "$LOG"; then
        ok "a box that never answers ssh fails with a timeout before any secret is read"
    else
        bad "timeout: status=$status out=$out log=$(cat "$LOG")"
    fi
}

test_exe_box_requires_name() {
    sandbox; stub_ssh; stub op
    exe_box
    if [ "$status" -ne 0 ] && echo "$out" | grep -q 'usage: new-exe-box.sh <name>' && ! grep -q '^ssh' "$LOG"; then
        ok "new-exe-box without a name prints usage and creates nothing"
    else
        bad "usage: status=$status out=$out log=$(cat "$LOG")"
    fi
}
```

Add the four names to the call list.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `./test/test_setup.sh 2>&1 | grep -c FAIL`
Expected: `4`.

- [ ] **Step 3: Write the script and the make target**

Create `scripts/new-exe-box.sh` and `chmod +x` it:

```bash
#!/bin/bash
# new-exe-box.sh <name>: create an exe.dev VM and bring it up as an
# @nonreagent host in one go. Creates the box, waits for ssh, hands
# @nonreagent's GitHub token from 1Password to gh over ssh stdin (never as an
# argument, never through exe.dev's --env or setup-script), then runs
# nonreagent/dotfiles' setup.sh on the box. Runs from the Mac: it needs the
# human's exe.dev ssh key and an unlocked `op`.
# Spec: docs/superpowers/specs/2026-09-25-setup-script-design.md
set -euf -o pipefail

name="${1:-}"
[ -n "$name" ] || { echo "usage: new-exe-box.sh <name>" >&2; exit 2; }

EXE_BOX_SETUP_URL="${EXE_BOX_SETUP_URL:-https://raw.githubusercontent.com/nonreagent/dotfiles/main/setup.sh}"
EXE_BOX_GH_TOKEN_REF="${EXE_BOX_GH_TOKEN_REF:-op://Private/nonreagent-github/token}"
EXE_BOX_WAIT="${EXE_BOX_WAIT:-300}"
EXE_BOX_POLL="${EXE_BOX_POLL:-5}"

host="$name.exe.xyz"
# accept-new: a fresh box has an unknown host key, and a non-interactive ssh
# would otherwise hang on the prompt (exe.dev's own skill file warns of this).
ssh_opts="-o StrictHostKeyChecking=accept-new"

echo "creating $name"
# shellcheck disable=SC2086
ssh $ssh_opts exe.dev new --name "$name" --json >/dev/null

echo "waiting for $host"
deadline=$(( $(date +%s) + EXE_BOX_WAIT ))
# shellcheck disable=SC2086
until ssh $ssh_opts -o ConnectTimeout=5 "$host" true 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "error: $host did not answer within ${EXE_BOX_WAIT}s" >&2
        exit 1
    fi
    sleep "$EXE_BOX_POLL"
done

echo "authenticating gh as @nonreagent"
# shellcheck disable=SC2086
op read "$EXE_BOX_GH_TOKEN_REF" | ssh $ssh_opts "$host" 'gh auth login --with-token && gh auth setup-git'

echo "running setup on $host"
# shellcheck disable=SC2086
ssh $ssh_opts "$host" "curl -fsSL $EXE_BOX_SETUP_URL | bash"

echo "ready: $host https://$host/"
```

In the `Makefile`, after the `setup` target:

```makefile
# One command for a new exe.dev VM as an @nonreagent host; see the script.
exe-box:
	@test -n "$(NAME)" || { echo "usage: make exe-box NAME=<name>"; exit 1; }
	./scripts/new-exe-box.sh "$(NAME)"
```

Add `exe-box` to `.PHONY`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `./test/test_setup.sh && make check-editorconfig`
Expected: `30 passed, 0 failed`, editorconfig clean.

- [ ] **Step 5: Probe the real service once, by hand**

These need the human's terminal (the lobby hangs for a non-interactive ssh from an agent session). Ask the human to run them with the `!` prefix and paste the result into the PR's Feedback section:

```
! ssh exe.dev help new
! ssh exe.dev new --name probe --json
! ssh probe.exe.xyz 'command -v git curl gh claude; id -un; echo $HOME'
! ssh exe.dev rm probe
```

What to learn: that `new --name <n> --json` is the accepted form; that `git`, `curl` and `gh` exist at first login (the script needs all three; `claude` is needed later by `sync-plugins.sh`, and if it is missing that is nonreagent's `setup.sh`'s problem, not this wrapper's); and the login user's `$HOME`, where the clone lands. If `new` needs a different flag shape, change the one `ssh ... new` line and its test assertion together.

- [ ] **Step 6: Amend the spec**

In `docs/superpowers/specs/2026-09-25-setup-script-design.md`, replace the numbered list 1-5 under "`scripts/new-exe-box.sh`: one command for a new VM" with:

```
1. `ssh exe.dev new --name <name> --json`. The box comes up bare; no `--setup-script`, so nothing runs before the wrapper can watch it.
2. Poll `ssh -o StrictHostKeyChecking=accept-new <name>.exe.xyz true` until the box answers, within `EXE_BOX_WAIT` seconds (default 300).
3. Inject the token over stdin, never through `--env` or an argument, so it lands only in `gh`'s config on the VM, the same state an interactive login leaves:

   ```
   op read "op://<vault>/<item>/token" \
     | ssh <name>.exe.xyz 'gh auth login --with-token && gh auth setup-git'
   ```

4. `ssh <name>.exe.xyz 'curl -fsSL <nonreagent setup.sh URL> | bash'`. The run is sequential and as the login user, so there is no first-boot race and no second pass.
5. Print the name and `https://<name>.exe.xyz/`.
```

And replace the sentence beginning "exe.dev's `new` command takes `--setup-script`" in that section's opening paragraph with:

```
exe.dev's `new` command offers `--setup-script` for first boot, but a first-boot run cannot be watched and a second `setup.sh` started before it finishes would collide in `~/.dotfiles`; the wrapper runs the provisioning itself over ssh instead, sequentially.
```

- [ ] **Step 7: Commit**

```bash
git add scripts/new-exe-box.sh Makefile test/test_setup.sh docs/superpowers/specs/2026-09-25-setup-script-design.md
git commit -F - <<'EOF'
Add new-exe-box.sh: create and provision an exe.dev VM in one command

Creates the box, waits for ssh, pipes @nonreagent's GitHub token from
1Password into gh over stdin, and runs nonreagent/dotfiles' setup.sh on
the box. Provisioning runs over ssh rather than exe.dev's first-boot hook
so the wrapper can watch it and nothing races the clone.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

## Plan self-review

**Spec coverage.** Entry and self-bootstrap: Task 3. Lib split and its four functions: Task 2 (self-bootstrap moved into `setup.sh`, spec amended in Task 3). macOS and Linux step lists, checkpoints, first run, dry-run: Task 3. Makefile changes: Task 1. Tests: Tasks 1-3 and 5. CI: Task 4. Docs: Task 4. Downstream: no task here by design; the spec's Downstream section describes the nonreagent change and the lib's constraints are enforced by the grep in Task 2 Step 4. `new-exe-box.sh`: Task 5, with the sequential deviation stated and the spec amended.

**Type consistency.** Guard and run function names in Task 3 match the `step` signature from Task 2 (`step <name> <guard> <run>`, both bare function names). Environment variable names (`SETUP_BREW`, `SETUP_BREW_BASH`, `SETUP_ETC_SHELLS`, `SETUP_FIRST_RUN`, `EXE_BOX_*`) are spelled the same in scripts and tests. Make variables `BREW`, `BREW_BASH`, `SHELLS_FILE` match between Task 1's targets and tests. The stub `make` logs `make -C <root> <target>`, and both order tests read field 4.

**Review Focus.** Items 1, 2 and 4 pinned in Task 3; item 3 in Task 2; item 5 in Task 5.
