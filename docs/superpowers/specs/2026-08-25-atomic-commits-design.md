# Atomic commits: authoring and preserving them through review

**Date:** 2026-08-25\
**Status:** Implemented — home/.agents/skills/atomic-commits/

## Problem

PRs authored here should read as a planned series of atomic commits — each one an independently reviewable unit that builds and tests green on its own (e.g. foundation → implementation → cleanup of the old path). Today nothing encodes that discipline, and the feedback loop actively fights it: `address-pr-feedback` step 5 says "make all accepted changes in one commit" and push, so review feedback lands as appended commits even when it logically belongs in an earlier one. A reviewer who challenges the library choice in commit 1 should see commit 1 change, not a fourth "address feedback" commit stacked on top.

## Decisions

Made during brainstorming, recorded here so the implementation doesn't re-litigate them:

- **Amend immediately.** When accepted feedback belongs in an earlier commit, rewrite that commit as soon as the feedback is accepted, rebase descendants, and push with `--force-with-lease`. History is atomic at every instant. The cost — GitHub's "changes since your last review" view degrades across force-pushes — is accepted; the reviewer re-reads commit-by-commit.
- **Plan-time commits.** The implementation plan names the commit series; one plan task = one commit, subject stated in the plan. A task's first commit *is* its designated commit; further work within the task amends it or lands as `--fixup` squashed before the task completes. The branch is PR-ready at every task boundary — no restructuring pass at PR-open.
- **Universal.** Applies to every PR authored, in every repo, regardless of the repo's merge style. Atomic commits are primarily a reviewability tool; they pay off even where the merge squashes the series.
- **Rule + mechanics skill, no extension framework.** See the placement rationale below.

## Placement rationale: why a rule plus a reference skill, not skill extension

There is no defined skill extension or inheritance mechanism — skills are markdown loaded into context, with no `extends:` frontmatter, override registry, or dispatch chain. What passes for extension is prose precedence claims, fill-in seams in prompt templates, and user rules formally outranking skills (per `superpowers:using-superpowers` itself). An "overlay skill" that restates superpowers with atomic deltas would also have a bootstrapping hole: something must load it mid-workflow, and that something is a rule — so the overlay's strength rests on the rule anyway.

The rule alone is stronger than it first appears because superpowers is already aligned. `superpowers:writing-plans` defines task boundaries as "split only where a reviewer could meaningfully reject one task while approving its neighbor" — that is the atomic-commit boundary verbatim. The rule adds one column (each task names its commit subject) and redirects one behavior (fix rounds amend the task's commit rather than appending). Where skill text genuinely contradicts the discipline — `address-pr-feedback` step 5 — the file is local and gets edited directly.

What earns a standalone skill is mechanics, not steering: non-interactive rebase choreography is a page of procedure shared by three contexts (authoring, PR feedback, subagent fix rounds), and the Claude Code harness has no `git rebase -i`, which is exactly the recipe a session re-derives badly. If drift shows up mid-workflow in practice, that is the evidence to escalate to something heavier — not before.

## Design

### 1. Rule: two bullets in `home/.agents/rules/workflow.md`, Git & PR Hygiene

```markdown
- **Author PRs as a planned series of atomic commits.** The implementation plan names the commit series; one plan task = one commit, subject stated in the plan. Each commit builds and passes tests on its own and is a unit a reviewer could accept or reject independently. A task's first commit *is* its designated commit; further work within the task amends it (or lands as `--fixup` and is squashed before the task completes), so the branch is PR-ready at every task boundary.
- **Feedback amends the owning commit, never appends.** Accepted PR feedback and fix-round changes land in the commit they logically belong to (fixup + autosquash), descendants are rebased, and the branch is pushed with `--force-with-lease`. No "address review feedback" commits. Invoke the `atomic-commits` skill for the rebase mechanics before any history rewrite.
```

The first bullet steers `superpowers:writing-plans` and `superpowers:subagent-driven-development`; the second is the invariant plus the routing hook into the mechanics skill. The existing "Iterate on the open PR" bullet is compatible and stays untouched.

### 2. New skill: `home/.agents/skills/atomic-commits/SKILL.md`

A pure mechanics reference. Frontmatter description triggers on: rewriting branch history, amending an earlier commit, landing a change into the commit that owns it, squash/split/reword, autosquash, force-push, or any urge to reach for `git rebase -i`.

Body outline:

1. **Safety preamble.** Only rewrite commits that are yours, unmerged, and on a branch nobody builds on. Record `git rev-parse HEAD` before any rewrite (reflog is the undo). Never rewrite the default branch — `main`, `master`, or whatever the remote HEAD names.
2. **Find the owning commit.** `git log --oneline <base>..HEAD` for the series; `git log -S` / `git blame` on the touched lines when it isn't obvious. The owning commit is where a reviewer's mental context for the change lives.
3. **Land a change into an earlier commit** — the core recipe: stage the fix, `git commit --fixup=<sha>` (`--fixup=amend:<sha>` to also reword), then `git rebase --autosquash <base>` (git ≥ 2.44), with `GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash <base>` as the older-git fallback; no editor actually opens.
4. **Reword / split.** Reword via edit-then-amend — mark the commit `edit`, `git commit --amend -m`, `git rebase --continue`; `-m` cannot combine with `--fixup=reword:` (git rejects the pairing, verified on git 2.43). Split via `GIT_SEQUENCE_EDITOR` marking the commit `edit`, then `git reset HEAD^` + `git add -p` + commit the pieces + `git rebase --continue`.
5. **Prove atomicity after any rewrite.** `git rebase -x '<cheap check>' <base>` replays the series running the check at every commit. Use the repo's cheapest meaningful check.
6. **Ripple conflicts are expected.** When an early commit changes under its descendants, resolve each conflict in service of *that commit's* intent; mid-rebase, the `resolving-merge-conflicts` skill applies.
7. **Push and threads.** Always `--force-with-lease`, never bare `--force`. After a force-push, GitHub review threads survive as "outdated"; reference the new SHAs in replies.
8. **Context notes.** Three lines, not an overlay framework: plans name the series per the rule; subagent-driven-development fix-round commits are `--fixup` of the task's commit, squashed before the task completes; `address-pr-feedback` carries its own step text.

Examples in the skill stay generic per the skill-authoring rule (the running example is emitting a field in a JSON payload: add library → implement field → remove deprecated path).

### 3. Edits to `home/.agents/skills/address-pr-feedback/SKILL.md`

1. **Step 2 (triage):** verification also answers "which commit owns this?" For each Accept, identify the owning commit while checking the codebase (`git log --oneline <base>..HEAD`, blame on the touched lines).
2. **Step 3 (present plan):** the Accept format gains the destination — **[Accept]** — @reviewer on `path:line` → *lands in `<sha7> <subject>`* — so mistriaged ownership is caught at the same confirmation gate as mistriaged buckets. Accepted feedback that no existing commit owns becomes a **new atomic commit** positioned sensibly in the series; an addition to the series is legal, an "address feedback" grab-bag is not.
3. **Step 5 (commit and push):** rewritten from "make all accepted changes in one commit" to: land each accepted change in its owning commit via the `atomic-commits` skill, prove the series with `git rebase -x '<cheap check>'`, then push `--force-with-lease` before replying.
4. **Step 6 (replies):** accepted-reply format becomes "Fixed in `<sha7>` — [what changed]", citing the post-rewrite SHA since the force-push renumbered the series.

The precedence note against `superpowers:receiving-code-review` stays as is.

## Verification

- `make check-skill-frontmatter` passes with the new skill.
- `make check-skills` passes after adding the directory.
- `workflow.md` is already mirrored into `home/.copilot/instructions/`; no new symlink needed.
- Grep the new skill for project-specific identifiers before finishing, per the skill-authoring rule.

## Parked decisions

- **Enforcement hooks** (e.g. a PreToolUse guard rejecting `git commit` messages like "address review feedback"): brittle; wait for observed drift before building enforcement.
- **Fixup-during-review mode** (append `--fixup` commits visibly during a review round, autosquash at approval, for incremental-diff ergonomics): rejected in favor of immediate amend; the skill may mention it in one line as an alternative a reviewer can request.
- **Merge-style guidance** in `superpowers:finishing-a-development-branch` (prefer rebase-merge so the series survives into the default branch): out of scope; the discipline is universal and does not condition on merge style.
- **Skill extension/inheritance pattern**: deliberately not built; see the placement rationale.
