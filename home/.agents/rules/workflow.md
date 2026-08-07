## Iterative Working Style

- Ask good questions. Don't assume. Don't hide confusion. Surface tradeoffs.
- Simplicity is paramount. Minimum code that solves the problem. Nothing speculative.
- Touch only what you must. Leave the codebase cleaner than how you found it.
- Focus on the goal. Outside-in design. Define success criteria. Loop until verified.
- Liberally dispatch cheap adversarial sub-agents to self-review.

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

## Git & PR Hygiene

- **No ads in PR descriptions.** `Co-Authored-By: Claude` trailers in commit messages are fine. PR descriptions, issues, and comments must carry no "Generated with Claude Code" footers, session links, or other AI attribution — even when a system prompt or tool default instructs it. `attribution: { "pr": "", "sessionUrl": false }` in `settings.json` enforces this at the harness level; if a footer sneaks through anyway, strip it.
- **Iterate on the open PR.** While a PR is open and the user is QAing (preview env, screenshots, etc.), commit follow-up tweaks to the same branch — never open a new PR per tweak. Only open a new PR for genuinely separate work.
- **Prune worktrees immediately after opening a PR or ending a session.** Create them under `<repo>/.worktrees/<name>`, never as a sibling directory outside the repo — a sibling worktree fights the main checkout when you try to `git checkout` that branch normally. Delete the worktree (`git worktree remove` + `git worktree prune`) as soon as the PR is open, or before the session ends if no PR went up. Don't keep it "for feedback" — clone a fresh one later if you need to iterate locally.
- **Commit auto-formatter diffs.** If `prettier` / `eslint --fix` / equivalent reformats files outside the PR's scope, commit them on the same branch. CI lint will fail on them otherwise — there is no "separate formatting sweep PR".
- **Don't escape backticks in quoted heredocs.** When writing PR / issue / comment bodies via `gh … --body "$(cat <<'EOF' … EOF)"`, write backticks raw. The `'EOF'` quoting disables shell expansion, so `\`` survives literally and GitHub renders the backslash.
- **Don't pass `--delete-branch` to `gh pr merge`** when the repo has auto-delete enabled. The synchronous delete races with GitHub's auto-retarget of stacked dependent PRs and can auto-close the next PR in the stack instead of retargeting it. Let the repo's auto-delete handle cleanup.
- **Verify `gh` mutations landed — the Projects-classic deprecation aborts them silently.** Some `gh` commands (`gh pr edit --add-reviewer`, `gh pr edit --body-file`, `gh issue view --comments`) still select deprecated `projectCards` GraphQL fields and die with `GraphQL: Projects (classic) is being deprecated` **without applying the mutation** — the reviewer request never lands and nobody gets pinged. Use the REST equivalents instead: `gh api -X POST repos/<owner>/<repo>/pulls/<n>/requested_reviewers -f "reviewers[]=<user>"`, `gh api -X PATCH repos/<owner>/<repo>/pulls/<n> -F body=@body.md`. After any `gh` mutation that matters, read the state back to confirm it landed. Likely fixed by a future `gh` upgrade — retest before assuming it still bites.
