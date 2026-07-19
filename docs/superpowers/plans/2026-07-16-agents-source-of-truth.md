# `.agents` Source-of-Truth Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `rules/`, `skills/`, and `ext/` out of `home/.claude/` into a vendor-neutral `home/.agents/`, leaving `.claude/rules` and `.claude/skills` as shims, so no vendor is privileged by the layout.

**Architecture:** A `git mv` of three directories, two new in-repo directory symlinks (shims), retargeting of the vendor links that pointed at `.claude`, deletion of one proven-dead link, and retargeting of two CI checks plus one test so they keep guarding the real thing. `manifest` and `deploy.sh` are untouched — the change is tracked files only. Existing clones need a one-time submodule fixup on pull because `core.worktree` is unversioned.

**Tech Stack:** bash, git 2.55 (submodule move mechanics), GNU-style `make`, filesystem symlinks.

**Spec:** `docs/superpowers/specs/2026-07-16-agents-source-of-truth-design.md` — read it; this plan assumes its findings.

## Global Constraints

- **Branch:** `agents-source-of-truth` (already exists, holds the spec commit). Do not work on `main`.
- **`rm` is aliased to `rm -v`** at `home/.bashrc:24`. Use `command rm` for any recursive delete to avoid flooding output.
- **`manifest` and `deploy.sh` must not change.** If a step seems to need them changed, stop — the design is wrong.
- **The submodule *name* stays `.claude/ext/mattpocock-skills`.** Only its worktree path moves. Never rename the module (that would require relocating `.git/modules/<name>` on every clone).
- **No Conventional Commit prefixes.** Plain descriptive commit messages. `Co-Authored-By` trailer is fine; no AI attribution in PR descriptions.
- **Final tracked symlink count is 30:** 29 existing − 1 deleted (`gemini …/rules`) + 2 shims.
- **Every `git mv` into `home/.agents/` needs its parent dir created first** (`git mv` does not auto-create parents — verified).

---

### Task 1: Perform the restructure (single atomic commit)

This is one commit because every intermediate state fails CI: once `rules/`/`skills/` move, the vendor links dangle until the shims and retargets land. Splitting would leave a red commit in history. Work in the tree, verify green, then commit once.

**Files:**
- Move: `home/.claude/{rules,skills}` → `home/.agents/{rules,skills}`; submodule `home/.claude/ext/mattpocock-skills` → `home/.agents/ext/mattpocock-skills`
- Create: `home/.claude/rules` (symlink), `home/.claude/skills` (symlink)
- Modify: `home/.claude/.gitignore`
- Retarget: `home/.copilot/instructions/*.instructions.md` (×7)
- Delete: `home/.gemini/antigravity-cli/rules` (proven-dead symlink)
- Retarget: `home/.gemini/antigravity-cli/skills`
- Modify: `Makefile` (`check-skills`, `check-copilot-instructions`)
- Modify: `test/test_deploy.sh` (manifest-coverage exclude list)

**Interfaces:**
- Produces for later tasks: the migrated tree on `agents-source-of-truth`, plus the committed SHA that Task 2 pulls into a simulated clone.

- [ ] **Step 1: Confirm a green baseline**

The submodule must be initialized or the skill links dangle and you cannot tell your breakage from pre-existing state.

```bash
cd ~/src/wip-dotfiles
git checkout agents-source-of-truth
git submodule update --init --recursive
make check-skills
```

Expected: `all skill symlinks resolve`. If it fails here, stop and fix the baseline first.

- [ ] **Step 2: Move the three directories**

`git mv` needs each destination parent to exist first. The submodule moves by its own path, not its parent `ext/`.

```bash
mkdir -p home/.agents home/.agents/ext
git mv home/.claude/rules home/.agents/rules
git mv home/.claude/skills home/.agents/skills
git mv home/.claude/ext/mattpocock-skills home/.agents/ext/mattpocock-skills
rmdir home/.claude/ext
```

- [ ] **Step 3: Verify the submodule survived the move**

```bash
git submodule status
git config -f .git/modules/.claude/ext/mattpocock-skills/config core.worktree
```

Expected: status line has **no leading `-`** and reads `home/.agents/ext/mattpocock-skills`; `core.worktree` is `../../../../../home/.agents/ext/mattpocock-skills`. The module path under `.git/modules` is still `.claude/ext/...` (keyed by name — correct).

- [ ] **Step 4: Create the two shims**

```bash
ln -s ../.agents/rules home/.claude/rules
ln -s ../.agents/skills home/.claude/skills
readlink home/.claude/rules   # ../.agents/rules
readlink home/.claude/skills  # ../.agents/skills
```

- [ ] **Step 5: Fix `home/.claude/.gitignore` (must precede `git add`)**

Git treats a symlink as a file, so a trailing-slash re-include won't match the shims. Without this edit, `git add` of the shims exits 1 ("paths are ignored").

Edit `home/.claude/.gitignore`:
- line 14: `!rules/` → `!rules`
- line 17: `!skills/` → `!skills`
- delete line 21 `!ext/`
- delete `!ext/*` (was line 43)
- delete `!skills/**` (was line 47)

- [ ] **Step 6: Retarget the 7 Copilot instruction links**

```bash
for f in home/.copilot/instructions/*.instructions.md; do
  n=$(basename "$f" .instructions.md)
  command rm "$f"
  ln -s "../../.agents/rules/$n.md" "$f"
done
for f in home/.copilot/instructions/*.instructions.md; do echo "$(basename "$f") -> $(readlink "$f")"; done
```

Expected: all 7 read `../../.agents/rules/<name>.md`.

- [ ] **Step 7: Delete the dead Gemini rules link, retarget the live skills link**

`antigravity-cli/rules` is proven dead (Antigravity reads global rules only from `~/.gemini/GEMINI.md`). `antigravity-cli/skills` is proven live.

```bash
git rm home/.gemini/antigravity-cli/rules
command rm home/.gemini/antigravity-cli/skills
ln -s ../../.agents/skills home/.gemini/antigravity-cli/skills
readlink home/.gemini/antigravity-cli/skills   # ../../.agents/skills
```

- [ ] **Step 8: Retarget `check-skills` in the `Makefile`**

Line 43 scopes the check to `home/.claude/skills`, which becomes a single resolving shim after the move — the check would pass over 18 dangling links (vacuous). Repoint it to where the real links now live.

Change `Makefile:43` from `git ls-files -z -- home/.claude/skills` to `git ls-files -z -- home/.agents/skills`.

- [ ] **Step 9: Retarget `check-copilot-instructions` in the `Makefile`**

It passes unmodified (realpath resolves through the shim) but regenerates links from `.claude/rules`, silently rewriting them back to `.claude` (and failing CI under `$CI`). Retarget every `.claude/rules` reference:
- line 63 (comment): `home/.claude/rules/*.md` → `home/.agents/rules/*.md`
- line 64 (comment): `.claude/rules/` → `.agents/rules/`
- line 70: `for rule in .claude/rules/*.md` → `for rule in .agents/rules/*.md`
- line 83: `rule=".claude/rules/$$(basename ...)` → `rule=".agents/rules/$$(basename ...)`
- line 98: `echo "copilot instructions mirror home/.claude/rules"` → `... home/.agents/rules"`

Line 77 (`ln -s "../../$$rule"`) needs no change: `$rule` now expands to `.agents/rules/x.md`, so the link becomes `../../.agents/rules/x.md`, which is correct.

- [ ] **Step 10: Add `.agents` to the manifest-coverage test exclude list**

`test/test_deploy.sh:344` asserts the manifest covers every non-wholly-ignored `home/.*`; `home/.agents` is tracked and not a deploy target, so `make test` fails without this. Add `! -name '.agents'` to the find exclusion and a short comment saying `.agents` is an in-repo root, not a deploy target.

Change `test/test_deploy.sh:344` from:
`! -name '.gitmodules' ! -name '.macos' -exec basename {} \; | sort)"`
to:
`! -name '.gitmodules' ! -name '.macos' ! -name '.agents' -exec basename {} \; | sort)"`

- [ ] **Step 11: Stage and verify the full suite**

```bash
git add -A
git ls-files -s | awk '$1=="120000"' | wc -l          # expect 30
git submodule status                                    # no leading '-'
make check-skills                                        # all skill symlinks resolve
make check-symlinks                                      # all tracked symlinks resolve
make check-copilot-instructions                          # copilot instructions mirror home/.agents/rules
make test                                                # 2 suites, 0 failed (incl. manifest-coverage)
```

All must pass and the count must be 30. If `git add` errors with "paths are ignored", Step 5 was skipped or wrong.

- [ ] **Step 12: Prove `check-skills` is not vacuous**

Deliberately dangle a link and confirm the retargeted check now catches it (it would not have, scoped to `.claude/skills`).

```bash
mv home/.agents/skills/tdd /tmp/tdd.bak && ln -s ../ext/DOES-NOT-EXIST home/.agents/skills/tdd
make check-skills; echo "exit: $?"    # expect failure, exit 1
command rm home/.agents/skills/tdd && mv /tmp/tdd.bak home/.agents/skills/tdd
make check-skills                      # back to green
```

- [ ] **Step 13: Prove Claude Code still loads rules through the shim**

Not just that the link resolves — that a rule file is actually read. Uses an unguessable token in a real file behind the symlinked directory.

```bash
echo 'The passphrase is: ZEBRA-4417' > home/.agents/rules/probe.md
env CLAUDE_CONFIG_DIR="$PWD/home/.claude" claude -p "What is the passphrase? Reply with only the passphrase." --model haiku
command rm home/.agents/rules/probe.md
```

Expected: `ZEBRA-4417`. (If your environment blocks `CLAUDE_CONFIG_DIR`, run the equivalent check the way the nyx rules probe was run.) Delete the probe before committing.

- [ ] **Step 14: Confirm `deploy.sh audit` is still clean against the live checkout**

The move is tracked-files-only, so nothing deployed should drift.

```bash
./deploy.sh audit
```

Expected: 25 ok, 2 skip, 0 drift, 0 missing.

- [ ] **Step 15: Commit**

```bash
git add -A
git commit -m "Make .agents the source of truth for agent config

Move rules/, skills/ and ext/ from home/.claude into home/.agents, leaving
.claude/rules and .claude/skills as shims. ext/ travels with skills/ so the 18
submodule links keep their relative depth unedited. Retarget the 7 copilot
instruction links and the live gemini skills link to .agents; delete the
gemini rules link, which Antigravity never reads (global rules load only from
~/.gemini/GEMINI.md). Retarget check-skills and check-copilot-instructions so
they keep guarding the real files, and exclude the in-repo .agents root from
the manifest-coverage test.

manifest and deploy.sh are unchanged. Existing clones need a one-time submodule
fixup on pull; see the PR description.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Prove the clone-pull fixup on a simulated clone

Existing clones break on pull because `core.worktree` lives in unversioned `.git/modules/<name>/config`. On this machine (nyx) that means `~/.dotfiles` and `~/src/wip-dotfiles`; any other machine's clone is the same. This task proves the fixup before anyone runs it for real, and produces the exact commands for the PR description. It creates no repo changes.

**Files:** none in the repo. Works entirely in a scratch clone.

**Interfaces:**
- Consumes: the committed SHA from Task 1.
- Produces: the verified fixup command block for Task 3's PR description.

- [ ] **Step 1: Build a pre-move consumer clone with the submodule initialized**

```bash
SB=/tmp/agents-fixup-test; command rm -rf "$SB"
git clone ~/src/wip-dotfiles "$SB"
cd "$SB"
git checkout "$(git rev-parse HEAD~1)"   # the commit before Task 1's move
git submodule update --init --recursive
git submodule status                      # no leading '-', links resolve
```

- [ ] **Step 2: Pull the move and observe the breakage**

```bash
git checkout agents-source-of-truth
git submodule status                      # expect leading '-'
make check-skills; echo "exit: $?"        # retargeted check fails: exit 1
```

Expected: leading `-` at `home/.agents/ext/mattpocock-skills`, 18 dangling links, `check-skills` exits 1. (Confirms the retargeted check catches consumer breakage.)

- [ ] **Step 3: Apply the fixup and confirm recovery to green**

```bash
command rm -rf .git/modules/.claude/ext/mattpocock-skills home/.claude/ext
git submodule update --init --recursive
git submodule status                      # no leading '-'
git config -f .git/modules/.claude/ext/mattpocock-skills/config core.worktree   # ../../../../../home/.agents/ext/mattpocock-skills
make check-skills                          # all skill symlinks resolve
make check-symlinks                        # all tracked symlinks resolve
```

All green. Record this exact block for the PR. Then `command rm -rf "$SB"`.

---

### Task 3: Open the PR and document the post-merge runbook

**Files:** none in the repo (PR description only).

**Interfaces:**
- Consumes: Task 1's commit, Task 2's verified fixup block.

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin agents-source-of-truth
gh pr create --title "Make .agents the source of truth for agent config" --body "$(cat <<'EOF'
Moves rules/, skills/, and ext/ out of home/.claude into a vendor-neutral home/.agents,
with .claude/rules and .claude/skills left as shims. No vendor is privileged by the layout.

Tracked-files-only: manifest and deploy.sh are unchanged.

## Verified
- make check-skills / check-symlinks / check-copilot-instructions / test all pass
- check-skills fails on a deliberately dangled link (not vacuous)
- 30 tracked symlinks; git submodule status clean; deploy.sh audit clean
- Claude Code loads rules through the shim (token probe)
- agy still enumerates skills through the retargeted gemini skills link

## One-time fixup on every existing clone after pull
core.worktree lives in unversioned .git/modules, so `git mv` fixes only the authoring
repo. After pulling this, each clone (including ~/.dotfiles) must run:

    command rm -rf .git/modules/.claude/ext/mattpocock-skills home/.claude/ext
    git submodule update --init --recursive
    make check-skills

## Notes
- Deletes the home/.gemini/antigravity-cli/rules link: verified dead (Antigravity reads
  global rules only from ~/.gemini/GEMINI.md). Rules reaching Antigravity is parked.
EOF
)"
```

- [ ] **Step 2: After merge — fix the live `~/.dotfiles`**

```bash
cd ~/.dotfiles
git pull
command rm -rf .git/modules/.claude/ext/mattpocock-skills home/.claude/ext
git submodule update --init --recursive
make check-skills
./deploy.sh audit
```

Then confirm this Claude session's rules and skills still resolve (`~/.claude -> ~/.dotfiles/home/.claude`, so `~/.claude/rules` follows the shim to `.agents/rules`).

- [ ] **Step 3: Other clones / hosts**

`nyx` (this machine) is already on the `home/` layout, so it just needs the Step 2 fixup — on `~/.dotfiles` and on `~/src/wip-dotfiles` (the working copy) after each pulls. How many other hosts this repo runs on is not knowable from here, so make no blanket claim: a host already on `home/` needs only the fixup; a host still on the pre-`home/` layout runs `scripts/migrate-to-home.sh` first, then pulls `.agents` and applies the fixup. The script is **retained** for exactly that case; updating it to be `.agents`-aware is possible future work.

---

## Self-Review

**Spec coverage:** every spec section maps to a step — the move (Task 1 §2), submodule mechanics (§3), shims (§4), `.gitignore` (§5), copilot retarget (§6), gemini split delete+retarget (§7), the two check retargets (§8–9), test exclude (§10), the non-vacuous-check proof (§12), the Claude rules-load proof (§13), the clone fixup (Task 2), and the post-merge runbook for existing clones (Task 3). Parked items (GEMINI.md, manifest-concat) are correctly absent.

**Placeholder scan:** no TBD/TODO; every edit cites a concrete file, line, and before/after value.

**Type/line consistency:** symlink count is 30 everywhere; the submodule name `.claude/ext/mattpocock-skills` is used consistently for the `.git/modules` path while the worktree path moves to `.agents`; `check-skills` retarget target (`home/.agents/skills`) matches between Task 1 §8 and the non-vacuous proof in §12.

**Ambiguity:** Step 5 fixes `.gitignore` before Step 11's `git add` — the ordering constraint is explicit. Step 2's `mkdir -p` precedes each `git mv`.
