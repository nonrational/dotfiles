# Atomic Commits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install the atomic-commit discipline — a new `atomic-commits` mechanics skill, two rule bullets in Git & PR hygiene, and `address-pr-feedback` edits that route accepted feedback into its owning commit.

**Architecture:** Pure markdown config changes in the live dotfiles checkout: one new skill directory, two existing files edited. No code. Verification is the repo's make checks plus a scratch-repo exercise of every git recipe.

**Tech Stack:** Markdown, git (2.43 on this machine — recipes must not require ≥ 2.44), GNU make checks.

**Spec:** `docs/superpowers/specs/2026-08-25-atomic-commits-design.md`

## Global Constraints

- **This plan executes under the discipline it installs.** One task = one commit, subject exactly as stated in the task. Fixes within a task amend its commit (`git commit --amend --no-edit`); never add checkpoint or fix commits.
- **Branch:** `atomic-commits` (exists, tracks `origin/atomic-commits`, carries the spec commit). Work in the main checkout — changes are additive; do not rename or delete existing files (the `home/` tree is live-symlinked into `$HOME`).
- **Commit messages:** plain descriptive subjects, no Conventional Commit prefixes. Footer: `Co-Authored-By: Claude <executing model name> <noreply@anthropic.com>`.
- **Markdown prose is never hard-wrapped:** each paragraph or bullet is one source line, matching the existing files.
- **Recipes must work on git 2.43:** the `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash` form is the primary recipe; plain `git rebase --autosquash` is a ≥ 2.44 aside. `-m` cannot combine with `--fixup=reword:` (verified: git rejects it) — reword goes through edit-then-amend.
- **No project-specific identifiers in the new skill** (skill-authoring rule). The running example is generic: emitting a field in a JSON payload.

---

### Task 1: The `atomic-commits` skill

**Commit subject:** `Add atomic-commits skill with non-interactive history-rewrite mechanics`

**Files:**
- Create: `home/.agents/skills/atomic-commits/SKILL.md`

**Interfaces:**
- Produces: a skill invocable by the exact name `atomic-commits` — Tasks 2 and 3 reference this name in prose; changing it breaks them.

- [ ] **Step 1: Create the skill file** with exactly this content:

~~~markdown
---
name: atomic-commits
description: 'Non-interactive git history-rewrite mechanics: landing a change into the commit that owns it, fixup + autosquash, reword, split, proving every commit green, and force-pushing a rewritten series. Use before any history rewrite on an unmerged branch — amending an earlier commit, squashing checkpoints into a designated commit, applying accepted PR feedback to the commit it belongs to, or any urge to reach for `git rebase -i`.'
---

# Atomic Commits

A PR is a planned series of atomic commits: each builds and tests green on its own and is a unit a reviewer could accept or reject independently. Work and accepted feedback land in the commit that owns them — amend and rebase, never append. The policy lives in the always-loaded rules; this skill is the mechanics.

## Safety preamble

Rewrite history only when all three hold: the commits are yours, they are unmerged, and nobody else builds on the branch. Never rewrite the default branch — `main`, `master`, or whatever `git symbolic-ref refs/remotes/origin/HEAD` names.

Before any rewrite, record the escape hatch:

```bash
git rev-parse HEAD    # note it; `git reset --hard <sha>` undoes everything
```

`git reflog` keeps every pre-rewrite state — a botched rebase loses nothing that was committed.

All recipes below use `$BASE`, the commit the series grows from:

```bash
BASE=$(git merge-base origin/HEAD HEAD)
```

If `origin/HEAD` is missing (a remote added by hand rather than cloned), `git remote set-head origin -a` restores it; on a stacked branch, use the parent branch as `$BASE` instead.

## Find the owning commit

The owning commit is where a reviewer's mental context for the change lives — the commit they would comment on. When it isn't obvious:

```bash
git log --oneline "$BASE"..HEAD                    # the series
git log -S 'identifier' --oneline "$BASE"..HEAD    # which commit introduced this content
git blame -L 10,20 -- path/to/file                 # which commit last touched these lines
```

Example: a PR changing how a field is emitted in a JSON payload might be three commits — add the serialization library, emit the field with it, remove the deprecated path. A reviewer challenging the library choice is challenging commit 1; the fix lands in commit 1, not in a fourth commit. Accepted feedback that no existing commit owns becomes a new atomic commit positioned sensibly in the series — additions to the series are legal, "address feedback" grab-bags are not.

## Land a change into an earlier commit

The core recipe. This harness has no interactive `git rebase -i`; `GIT_SEQUENCE_EDITOR=true` accepts the generated todo list untouched, so nothing opens:

```bash
git add -p                    # stage exactly the fix
git commit --fixup=<sha>      # marks it for squashing into <sha>
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash "$BASE"
```

Batch freely: create several `--fixup` commits targeting different owners, then run one autosquash — each lands in its own target. On git ≥ 2.44, plain `git rebase --autosquash "$BASE"` does the same without the wrapper.

To amend the tip commit, skip all of this: `git commit --amend --no-edit`.

## Reword an earlier commit

`-m` cannot combine with `--fixup=reword:` (git rejects the pairing), so reword by stopping at the commit and amending:

```bash
SHA7=$(git rev-parse --short <sha>)
GIT_SEQUENCE_EDITOR="sed -i.bak 's/^pick $SHA7/edit $SHA7/'" git rebase -i "$BASE"
git commit --amend -m "New message"
git rebase --continue
```

## Split a commit

Stop at the commit the same way, then unstage and recommit in pieces:

```bash
SHA7=$(git rev-parse --short <sha>)
GIT_SEQUENCE_EDITOR="sed -i.bak 's/^pick $SHA7/edit $SHA7/'" git rebase -i "$BASE"
git reset HEAD^
git add -p                    # stage the first piece
git commit -m "First unit"
git add <rest>
git commit -m "Second unit"
git rebase --continue
```

## Ripple conflicts are expected

When an early commit changes under its descendants (the library swap under the field implementation), the rebase stops at each conflicting descendant. Resolve each conflict in service of *that commit's* intent — the descendant should read as if it had been written against the new ancestor all along. Mid-rebase, the `resolving-merge-conflicts` skill applies; `git rebase --abort` plus the recorded SHA is always a clean exit.

## Prove every commit green

After any rewrite, replay the series running the repo's cheapest meaningful check at every commit:

```bash
git rebase -x '<cheap check>' "$BASE"    # e.g. `make test`, `npm test`
```

A failure stops at the offending commit — fix it there (`git commit --amend`, then `git rebase --continue`), so atomicity is restored where it broke, not papered over at the tip.

## Push a rewritten series

```bash
git push --force-with-lease
```

Never bare `--force`: `--force-with-lease` refuses to overwrite work that appeared on the remote since your last fetch. After a force-push, GitHub review threads survive marked "outdated"; replies cite the post-rewrite SHAs.

## Context notes

- Implementation plans name the commit series; one plan task = one commit (see the Git & PR hygiene rules).
- Subagent fix-round commits are `--fixup` of their task's commit, squashed before the task completes.
- `address-pr-feedback` routes each accepted comment to its owning commit during triage; its steps carry the specifics.
- If a reviewer asks to see incremental changes during a round, `--fixup` commits may stay visible until the round settles, then autosquash — the exception, not the default.
~~~

- [ ] **Step 2: Run the frontmatter and symlink checks**

Run: `make check-skill-frontmatter && make check-skills`
Expected: both pass silently (exit 0).

- [ ] **Step 3: Exercise every recipe in a scratch repo**

Run this script; it builds a three-commit series, then exercises fixup + autosquash, edit-then-amend reword, and the `-x` replay exactly as the skill states them:

```bash
LAB=$(mktemp -d) && cd "$LAB" && git init -q -b main && git config user.email t@t && git config user.name t
echo lib=v1 > lib.txt && git add . && git commit -qm "Add serialization library"
echo field > field.txt && git add . && git commit -qm "Emit field via library"
echo cleanup > old.txt && git add . && git commit -qm "Remove deprecated path"
SHA_A=$(git rev-parse HEAD~2)
echo lib=v2 > lib.txt && git add lib.txt && git commit -q --fixup=$SHA_A
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash --root
test "$(git rev-list --count HEAD)" = 3 && grep -q v2 lib.txt && echo FIXUP-OK
SHA7=$(git rev-parse --short HEAD~2)
GIT_SEQUENCE_EDITOR="sed -i 's/^pick $SHA7/edit $SHA7/'" git rebase -i --root
git commit -q --amend -m "Add JSON serialization library" && git rebase --continue
git log --format=%s HEAD~2 -1 | grep -qx "Add JSON serialization library" && echo REWORD-OK
git rebase -x 'test -f lib.txt' --root && echo EXEC-OK
cd - && rm -rf "$LAB"
```

Expected: `FIXUP-OK`, `REWORD-OK`, `EXEC-OK` all print. If any recipe fails on this machine's git, fix the skill text to match reality — the skill must never document a command that doesn't work here.

- [ ] **Step 4: Scrub gate (skill-authoring rule)**

Run: `grep -rniE 'nonrational|nonreagent|exedev|exe\.dev|norton' home/.agents/skills/atomic-commits/`
Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add home/.agents/skills/atomic-commits/SKILL.md
git commit -m "Add atomic-commits skill with non-interactive history-rewrite mechanics"
```

(Append the Co-Authored-By footer per Global Constraints.)

---

### Task 2: Rule bullets in Git & PR hygiene

**Commit subject:** `Require atomic commit series in Git & PR hygiene rules`

**Files:**
- Modify: `home/.agents/rules/workflow.md` (the `## Git & PR Hygiene` section)

**Interfaces:**
- Consumes: the skill name `atomic-commits` from Task 1 (referenced in prose).

- [ ] **Step 1: Insert two bullets** into the `## Git & PR Hygiene` bullet list, immediately BEFORE the bullet beginning `- **Iterate on the open PR.**`. Each bullet is ONE source line (no hard-wrapping). Exact text:

```markdown
- **Author PRs as a planned series of atomic commits.** The implementation plan names the commit series; one plan task = one commit, subject stated in the plan. Each commit builds and passes tests on its own and is a unit a reviewer could accept or reject independently. A task's first commit *is* its designated commit; further work within the task amends it (or lands as `--fixup` and is squashed before the task completes), so the branch is PR-ready at every task boundary.
- **Feedback amends the owning commit, never appends.** Accepted PR feedback and fix-round changes land in the commit they logically belong to (fixup + autosquash), descendants are rebased, and the branch is pushed with `--force-with-lease`. No "address review feedback" commits. Invoke the `atomic-commits` skill for the rebase mechanics before any history rewrite.
```

- [ ] **Step 2: Verify placement and integrity**

Run: `grep -n 'atomic commits\|Iterate on the open PR' home/.agents/rules/workflow.md`
Expected: the two new bullets' line numbers directly precede the `Iterate on the open PR` line; every other Git & PR Hygiene bullet still present (`grep -c '^- \*\*' home/.agents/rules/workflow.md` increased by exactly 2).

- [ ] **Step 3: Run the mirror and repo checks**

Run: `make check-copilot-instructions && make test`
Expected: mirror reports no changes needed (`workflow.md` is already linked); test suite passes.

- [ ] **Step 4: Commit**

```bash
git add home/.agents/rules/workflow.md
git commit -m "Require atomic commit series in Git & PR hygiene rules"
```

(Append the Co-Authored-By footer per Global Constraints.)

---

### Task 3: Route accepted feedback into its owning commit

**Commit subject:** `Route accepted PR feedback into its owning commit`

**Files:**
- Modify: `home/.agents/skills/address-pr-feedback/SKILL.md` (steps 2, 3, 5, 6)

**Interfaces:**
- Consumes: the skill name `atomic-commits` from Task 1 (referenced in prose).

- [ ] **Step 1: Extend step 2 (triage) with owning-commit identification.** Find the paragraph:

> Before deciding, verify against the codebase. Grep for the relevant code, read the surrounding context, check for prior usage patterns elsewhere. Don't triage from the comment alone.

Append to that same paragraph (one source line):

> For each comment you expect to accept, also identify the **owning commit** — the commit in the PR's series the comment is really about (`git log --oneline <base>..HEAD`, `git blame` on the touched lines).

- [ ] **Step 2: Extend the step 3 plan format with the destination.** After the existing per-comment format block (the blockquote ending `_One sentence explaining the proposed action and why._`), add this paragraph (one source line):

> For accepts, the explanation names the destination: "lands in `<sha7> <subject>`" — or "new commit: `<subject>`" when no existing commit owns the change (genuinely new scope accepted into the PR becomes its own atomic commit, positioned sensibly in the series). Mistriaged ownership gets caught at this gate alongside mistriaged buckets.

- [ ] **Step 3: Rewrite step 5.** Replace the entire body of `### 5. Commit and push` — currently:

> Make all accepted changes in one commit (or logically grouped commits if the changes are unrelated). Push before replying, so the replies can reference what's already live.

with (one source line):

> Land each accepted change in the commit that owns it — invoke the `atomic-commits` skill for the fixup + autosquash mechanics and ripple-conflict handling; feedback no commit owns becomes a new atomic commit in the series. Never append an "address review feedback" commit. After the rewrite, prove the series (`git rebase -x '<cheap check>' <base>`), then push with `--force-with-lease` before replying, so the replies can reference what's already live.

- [ ] **Step 4: Update the step 6 accepted-reply format.** Replace the line:

> > Fixed — [what changed].

with:

> > Fixed in `<sha7>` — [what changed].

and append to the preceding **Accepted:** guidance sentence (same source line): `Cite the post-rewrite SHA — the force-push renumbered the series.`

- [ ] **Step 5: Verify the old behavior is gone**

Run: `grep -c 'Make all accepted changes in one commit' home/.agents/skills/address-pr-feedback/SKILL.md; grep -c 'force-with-lease\|owning commit' home/.agents/skills/address-pr-feedback/SKILL.md`
Expected: first count 0; second count ≥ 2.

- [ ] **Step 6: Run the checks**

Run: `make check-skill-frontmatter && make check-skills`
Expected: both pass.

- [ ] **Step 7: Commit**

```bash
git add home/.agents/skills/address-pr-feedback/SKILL.md
git commit -m "Route accepted PR feedback into its owning commit"
```

(Append the Co-Authored-By footer per Global Constraints.)
