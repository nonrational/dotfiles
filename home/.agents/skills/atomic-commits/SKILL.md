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
