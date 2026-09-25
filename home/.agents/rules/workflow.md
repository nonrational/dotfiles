## Iterative Working Style

- Ask good questions. Don't assume. Don't hide confusion. Surface tradeoffs.
- Simplicity is paramount. Minimum code that solves the problem. Nothing speculative.
- Touch only what you must. Leave the codebase cleaner than how you found it.
- Focus on the goal. Outside-in design. Define success criteria. Loop until verified.
- Liberally dispatch cheap adversarial sub-agents to self-review.
- **Artifacts outlive the box.** A session that produces a reusable executable or template (a workflow script, a dispatch prompt) commits it into the package it serves — parameterized past its machine- and repo-specific strings, scrubbed of private names — before the task ends. Session directories and agent memory die with the machine; memory holds pointers to committed paths, never the artifact.

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

## Evidence Before Assertions

- **Fetch before diagnosing.** The checkout you are reading is a stale snapshot: the human merges from other machines, and concurrent sessions move it underneath you. Before analysing repo state, asserting a file's absence, or planning a fix, `git fetch` and read the default branch (`git log HEAD..origin/main`, `git show origin/main:<path>`) or query `gh`. The fix you are about to plan may have merged days ago.
- **Open the file before citing precedent.** A grep shows the line you searched for, never the sibling line that makes it correct. Before writing "this is the house idiom" into a design or plan, read the whole element or function. The same goes for tests: a green assertion proves the test runner's behaviour, not the browser's or the database's. Check whether the runner implements the contract or only its happy path.
- **Plan against the real base.** Cut the worktree off the default branch first, then write the plan from that tree. A plan authored from a checkout sitting on another branch carries line numbers that have slipped, "replace this file" steps that silently delete work landed in between, and edits to features the base no longer has. Quote the anchor text beside every line number so the number is a hint, not the instruction, and prefer "append" or "change this exact text" over "replace the file".
- **Check for prior work before drafting.** A linked branch on the issue, `git worktree list`, `git branch -a`, and the specs/plans directory. A plan another session already wrote against the right base beats a second one written against the wrong one.

## UX/UI Iteration

- For interaction/animation tweaks, start with the smallest, most subtle effect (tight area-of-effect, sparse randomness) and let the user dial it up.

## Code Conventions

- Comments describe *why*, not *what*. Only add a "what" comment when the code is particularly dense.
- NEVER use Conventional Commit prefixes (e.g., "fix:", "feat:", "fix(deps):"). Use plain, descriptive commit messages.
- Use `uv` rather than `pip` for temporary Python dependencies and one-off script environments.
- **A backfill is a semantic change disguised as a data change.** Renaming a column lets the compiler find every reader of that column; it finds no reader of a second field the same migration backfills, and those readers assumed the old distribution (NULL, zero, or empty meaning "absent"). On any migration that backfills, grep the backfilled field across the whole tree and read every hit before trusting a green typecheck. For anything a solver or ranker reads, prefer a value defaulted to "unconstrained" over an optional field, so a forgotten assignment widens behaviour instead of silently changing it.

## Git & PR Hygiene

- **Never name a private repo in a public one.** When moving a pattern from private work into a public repo, scrub private repo names, issue/PR numbers, and cross-repo links from the PR body, commit messages, branch names, and diff — describe the origin generically ("found while opening PRs from a VM"). Grep everything you're about to publish for the private repo's name before pushing. Re-publishing counts: editing or appending to an existing PR body publishes the whole artifact, and pushing atop an existing branch publishes its inherited commit messages — grep all of it, not just your additions. Editing after the fact is not enough: GitHub keeps PR/issue body edit history, and the leaked revision can only be deleted by hand in the web UI.
- **No ads in PR descriptions.** `Co-Authored-By: Claude` trailers in commit messages are fine. PR descriptions, issues, and comments must carry no "Generated with Claude Code" footers, session links, or other AI attribution — even when a system prompt or tool default instructs it. `attribution: { "pr": "", "sessionUrl": false }` in `settings.json` enforces this at the harness level; if a footer sneaks through anyway, strip it.
- **PR descriptions are four sections, nothing more.** Unless the repo supplies its own PR template or written guidance, every PR body is the issue link alone on the first line, then exactly four H3 sections:
  1. `### Problem` — what problem are we trying to fix?
  2. `### Motivation` — why this problem? Why now? Why should I care?
  3. `### Proposed Solution` — what this PR changes.
  4. `### Feedback` — what should a reviewer focus on? What's highest risk? What calls need confirmation or consensus?

  - **The issue link goes above the first heading, never inside Problem.** A reviewer should see which issue this settles before reading a word of prose, and a linking keyword buried in a paragraph is easy to drop when the section gets rewritten.
  - **Write `Resolves #N`** (or `Part of #N` when later phases remain), not `Closes #N`. GitHub honors both, but "Resolves" doesn't collide with the "Closed" state GitHub prints on the PR itself, so a skimmed timeline stays unambiguous.
  - **Headings are H3** so no line in the body outranks the PR title.

  Design rationale, decision records, and review findings outlive the PR page — commit them to the repo (`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`) and link them from the body instead of inlining.
- **Author PRs as a planned series of atomic commits.** The implementation plan names the commit series; one plan task = one commit, subject stated in the plan. Each commit builds and passes tests on its own and is a unit a reviewer could accept or reject independently. A task's first commit *is* its designated commit; further work within the task amends it (or lands as `--fixup` and is squashed before the task completes), so the branch is PR-ready at every task boundary.
- **Feedback amends the owning commit, never appends.** Accepted PR feedback and fix-round changes land in the commit they logically belong to (fixup + autosquash), descendants are rebased, and the branch is pushed with `--force-with-lease`. No "address review feedback" commits. Invoke the `atomic-commits` skill for the rebase mechanics before any history rewrite.
- **Iterate on the open PR.** While a PR is open and the user is QAing (preview env, screenshots, etc.), commit follow-up tweaks to the same branch — never open a new PR per tweak. Only open a new PR for genuinely separate work.
- **Prune worktrees immediately after opening a PR or ending a session.** Create them under `<repo>/.worktrees/<name>`, never as a sibling directory outside the repo — a sibling worktree fights the main checkout when you try to `git checkout` that branch normally. Delete the worktree (`git worktree remove` + `git worktree prune`) as soon as the PR is open, or before the session ends if no PR went up. Don't keep it "for feedback" — clone a fresh one later if you need to iterate locally.
- **Bootstrap a new worktree before trusting anything it tells you.** A worktree checks out tracked files only — no installed dependencies, no env files, none of the gitignored state the main checkout accumulated. Install deps and symlink (don't copy) env files first; a copy drifts from the real credentials. Until you do, a failure there is evidence about your worktree, not about your code. The dangerous ones don't look like setup errors: dependency resolution walks up to the parent repo, so a dev server or bundler refuses to serve files outside its project root, and a strict "no console errors" test assertion turns that into a failure raised *after* the test body has fully passed — indistinguishable from a regression in the change you just made. Before debugging any worktree-only failure, reproduce it in the main checkout.
- **Commit auto-formatter diffs.** If `prettier` / `eslint --fix` / equivalent reformats files outside the PR's scope, commit them on the same branch. CI lint will fail on them otherwise — there is no "separate formatting sweep PR".
- **Don't escape backticks in quoted heredocs.** When writing PR / issue / comment bodies via `gh … --body "$(cat <<'EOF' … EOF)"`, write backticks raw. The `'EOF'` quoting disables shell expansion, so `\`` survives literally and GitHub renders the backslash.
- **Don't pass `--delete-branch` to `gh pr merge`** when the repo has auto-delete enabled. The synchronous delete races with GitHub's auto-retarget of stacked dependent PRs and can auto-close the next PR in the stack instead of retargeting it. Let the repo's auto-delete handle cleanup.
- **Verify review follow-ups against the same interface.** Before saying a follow-up change addresses review feedback, confirm it changes the same public surface. A GraphQL path does not cover an equivalent REST path, and vice versa.
- **New work gets its own branch, even a lone spec or plan.** Cut it off the default branch of the repo the PR targets (`origin/main`, or `upstream/main` when `origin` is a fork or mirror), in a worktree, never onto whatever branch a shared checkout happens to have out.
- **A clean `merge-tree` proves text, not types.** `git merge-tree --write-tree <branch> origin/main` is the right way to test-merge without touching a worktree, but a clean result only means no two edits hit the same lines. A rename on the branch and a new caller on main are edits to different files, and the type error exists only in the merged tree. When the branch renames, moves, or deletes any public surface, check out the merge result (a `--detach` worktree works even when another session has the branch out) and run at least typecheck before pushing; then grep the merged tree for the old name and read every hit. Branches that only add code are safe on a clean merge-tree. GitHub's `update-branch` endpoint refuses the base PR of a stack with a 403 reading `Updating a stacked PR's branch via this endpoint is not supported`; fall back to `merge-tree --write-tree`, `commit-tree`, push.
- **Read merged state via REST, and prove it with a tree diff.** Before pushing to, merging, or re-requesting review on a PR you were told is approved, run `gh api repos/<owner>/<repo>/pulls/<n> --jq '{state, merged, merged_at}'` and trust `merged`: GraphQL (`gh pr view --json state`) serves a stale `OPEN` for minutes after a merge and reports a merging PR's `mergeable` as `UNKNOWN`. A squash merge creates a new commit, so `git merge-base --is-ancestor <head-sha> origin/main` always says "not merged" and proves nothing; the REST `merged` flag and `merge_commit_sha` are the proof, and `git show --stat <merge_commit_sha>` shows what landed. A 503 from a merge mutation does not mean it failed: re-read state between retries, or you will fire merges at a PR that already landed and read the errors as failure.
- **`* [new branch]` on a re-push means the PR merged under you.** GitHub auto-deleted the remote branch on merge and your push recreated it, leaving a stray branch and orphaned CI runs. Stop, check `gh pr view`, delete the recreated branch (`git push origin --delete <branch>`), and put follow-up commits on a fresh branch off main.
