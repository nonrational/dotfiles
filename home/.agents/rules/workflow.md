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

## UX/UI Iteration

- For interaction/animation tweaks, start with the smallest, most subtle effect (tight area-of-effect, sparse randomness) and let the user dial it up.

## Code Conventions

- Comments describe *why*, not *what*. Only add a "what" comment when the code is particularly dense.
- NEVER use Conventional Commit prefixes (e.g., "fix:", "feat:", "fix(deps):"). Use plain, descriptive commit messages.
- Use `uv` rather than `pip` for temporary Python dependencies and one-off script environments.

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
- **Iterate on the open PR.** While a PR is open and the user is QAing (preview env, screenshots, etc.), commit follow-up tweaks to the same branch — never open a new PR per tweak. Only open a new PR for genuinely separate work.
- **Prune worktrees immediately after opening a PR or ending a session.** Create them under `<repo>/.worktrees/<name>`, never as a sibling directory outside the repo — a sibling worktree fights the main checkout when you try to `git checkout` that branch normally. Delete the worktree (`git worktree remove` + `git worktree prune`) as soon as the PR is open, or before the session ends if no PR went up. Don't keep it "for feedback" — clone a fresh one later if you need to iterate locally.
- **Bootstrap a new worktree before trusting anything it tells you.** A worktree checks out tracked files only — no installed dependencies, no env files, none of the gitignored state the main checkout accumulated. Install deps and symlink (don't copy) env files first; a copy drifts from the real credentials. Until you do, a failure there is evidence about your worktree, not about your code. The dangerous ones don't look like setup errors: dependency resolution walks up to the parent repo, so a dev server or bundler refuses to serve files outside its project root, and a strict "no console errors" test assertion turns that into a failure raised *after* the test body has fully passed — indistinguishable from a regression in the change you just made. Before debugging any worktree-only failure, reproduce it in the main checkout.
- **Commit auto-formatter diffs.** If `prettier` / `eslint --fix` / equivalent reformats files outside the PR's scope, commit them on the same branch. CI lint will fail on them otherwise — there is no "separate formatting sweep PR".
- **Don't escape backticks in quoted heredocs.** When writing PR / issue / comment bodies via `gh … --body "$(cat <<'EOF' … EOF)"`, write backticks raw. The `'EOF'` quoting disables shell expansion, so `\`` survives literally and GitHub renders the backslash.
- **Don't pass `--delete-branch` to `gh pr merge`** when the repo has auto-delete enabled. The synchronous delete races with GitHub's auto-retarget of stacked dependent PRs and can auto-close the next PR in the stack instead of retargeting it. Let the repo's auto-delete handle cleanup.
- **Verify review follow-ups against the same interface.** Before saying a follow-up change addresses review feedback, confirm it changes the same public surface. A GraphQL path does not cover an equivalent REST path, and vice versa.
