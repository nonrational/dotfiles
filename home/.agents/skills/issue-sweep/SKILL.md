---
name: issue-sweep
description: Sweep a queue of ready-for-agent issues into reviewed PRs in one unattended run — plan, build, adversarially review, fix and verify, one independent pipeline per issue.
argument-hint: "Which repo, which issues, and how many at once?"
disable-model-invocation: true
---

# Issue Sweep

Turn a queue of triaged issues into **reviewed PRs**, unattended, one independent pipeline per issue.

The output is not a pile of branches. It is a set of PRs, each carrying a posted adversarial review, each blocking finding either fixed with a proven regression test or answered with evidence. Every PR is opened draft and promoted out of draft only once it survives its own review with green checks, so the draft flag tells the human where to look last. The human wakes to reviews, not just diffs — and merges nothing they haven't read.

**Use when** the queue is already triaged and the repo has a green, runnable check suite. **Don't use** to triage (that's `triage`), to ship one attended slice with the human in the loop, to explore an unscoped idea, or on a repo where you can't run tests locally — a sweep with no verification just manufactures branches.

## Reference

- [references/stage-prompts.md](references/stage-prompts.md) — the harness contract, what each stage's dispatch prompt must contain, and the structured output it returns.
- [scripts/workflow.js](scripts/workflow.js) — a ready-to-run implementation of the pipeline for a Workflow-style harness: a worker pool holding recon's concurrency cap, each item chained plan → build → review → fix → verify with no barrier between items. Recon still happens first, in the orchestrator; its findings are the script's `args` (repo, default branch, shared context block, disclaimer, worker count, build model name, and the items with their hints, dependencies, and any committed plan). Run this rather than re-deriving a script from the prose, and fold any fix it needs back into the file so it survives the machine. Close of run (CI judged once, promotion, cleanup check, report) stays with the orchestrator.

## The pipeline

Each item flows through these stages independently. Nothing waits on a sibling.

| # | Stage | Model | Writes? | Returns |
|---|-------|-------|---------|---------|
| 1 | Plan | strong | issue comment + labels only | actionable + scoped slice, or a skip |
| 2 | Build | workhorse | own worktree; opens draft PR | `pr-opened` / `failed` |
| 3 | Review | strong | **one PR comment** | `clean` / `minor` / `blocking` |
| 4 | Fix | workhorse | own worktree; pushes to the branch | `fixed` / `partial` / `could-not-fix` |
| 5 | Verify | strong | comment only if still broken | `resolved` / `still-broken` |

**Strong** = the top reasoning tier at high effort; **workhorse** = the mid tier (see `~/.agents/rules/prudence.md` if it's loaded). Name the model on every dispatch or it inherits the session's.

**Control flow.** Stages 4–5 fire automatically for a `blocking` verdict, in the same per-item chain — the run is unattended, so nothing waits for a human to read a verdict. **One fix round, never two.** Every other state is terminal and gets its own row in the morning report: `clean` / `minor` (done), `partial` / `could-not-fix` (the fixer disputed the finding or gave up), `still-broken` (the PR carries a live blocking comment — flag it hardest). Split the run into two scripts, stages 1–3 then 4–5, only when a human is awake and wants that gate.

**Promotion out of draft is not a stage.** Every PR is born draft in stage 2 and no agent ever flips it; the orchestrator promotes in one pass at close of run, when it knows both the terminal verdict and the CI result (see "Close the run").

## 0. Recon before you dispatch anything

The orchestrator does this itself, read-only, in the main checkout. **Dispatching before recon is the most expensive mistake in this pattern** — a build agent that discovers mid-run that half its issue already shipped burns an hour and produces a confused PR.

Deliverables:

1. **Preflight.** `gh auth status` and push permission; the repo's default branch (`gh repo view --json defaultBranchRef` — don't assume `main`); the default branch's CI is green; and the verify commands from item 4 actually run in a throwaway worktree. A minute here, or a wasted night.
2. **A deduped queue.** Cross the queue against merged PRs, open PRs, and existing branches (`git log origin/<default>`, `gh pr list --state merged`, `git branch -a`). Phased issues are the trap: earlier slices often merged since triage, so the issue text describes work that is already done.
3. **Shared-resource hazards, each with three literal commands.** Anything the items contend over when run at once: a test database, a fixed port, a cache directory, a rate-limited API, a lockfile. For each, write down the **override knob**, the **create command** and the **drop command**, verbatim and ready to paste into a dispatch prompt. If a resource has no override, serialize the items that need it. Don't hope.
4. **The repo's verify commands and its own test policy**, read out of `CLAUDE.md` / `CONTRIBUTING.md` / the task runner: lint, typecheck, unit, integration/e2e — *and* what that repo says about narrow versus full local runs. Some repos push the slow suite to CI on purpose; some have no CI job for it, in which case the build agent runs it before opening the PR. Record any local-only gotcha by name — an unnamed gotcha can't be handed to an agent.
5. **Attribution facts.** The commit trailer format, whether the tracker requires a provenance disclaimer on issue comments (see "Where the disclaimer applies"), and the reviewer handle — which the orchestrator keeps to itself and spends at promotion, not in any stage prompt.
6. **A hint per item.** One or two sentences of prior-work context, verified against code and PR history, handed to that item's planner so it starts warm.
7. **A concurrency cap.** Set by machine headroom (each item is a worktree, a dependency install and a scratch database) and by API rate limits. Default to 4 concurrent items unless you've measured otherwise. Cap the dispatched queue at that; the remainder stays queued and **appears in the morning report as not-attempted** — never silently dropped.

Then **order the queue bugs-first**, high-certainty before speculative. A run can be cut short; the surviving PRs should be the ones most likely to merge.

## How the run is driven

The pattern needs three things from the harness: spawn agents concurrently, name the model per dispatch, and get parseable output back.

- **Per-item chaining, never a stage barrier.** Whatever the harness calls it — a `pipeline()` per item, a promise chain, a shell job — each item walks its own stages end to end. Stage-by-stage batching means one slow planner stalls every build, and a cut-short run yields zero PRs instead of five.
- **If the harness has no structured output** (plain parallel `Task` dispatches, for instance), have each stage agent write its JSON to `<scratch>/<issue>/<stage>.json` as its last action and tell the orchestrator to read the file. Prose returned in a chat message is not a contract.
- **Pass forward, don't re-derive.** Each stage gets the previous stage's output in its prompt. No build agent should re-read the issue thread to learn its own scope.
- **One shared context block** in every prompt: repo path, default branch, stack, recon's hazard commands and verify commands, attribution facts, and the read-only rule for the main checkout.

## The disciplines

Each is enforced in the stage prompt it belongs to; here is the judgment behind it.

- **The planner may refuse, and that is a successful outcome.** "Sweep each issue" does not mean "each issue gets a PR". Blocked, already landed, or needs a human decision → comment on the issue citing PRs and commits, flip the labels, return `actionable: false`. Cheaper than a PR that has to be closed.
- **Isolation and cleanup are per item, not per run.** One worktree under `<repo>/.worktrees/<slug>` (see `superpowers:using-git-worktrees`), its own copy of every shared resource, torn down before the item returns on *either* path. A run that gets cut short leaves nothing behind. Verify at close with `git worktree list` and recon's resource-listing command.
- **The review is a posted artifact.** The structured verdict dies with the run; the PR comment is what the human reads. Post one even when clean. Written in the `code-review-register` voice — if that skill isn't installed, fall back to the repo's review conventions and plain declarative prose.
- **A `blocking` finding requires an empirical reproduction, not an argument.** Concrete inputs, the wrong output. Anything unreproduced is `minor`, phrased as a question.
- **The regression test must be proven to bite.** Revert the fixed file, run the test, watch it fail, restore. A test that has never been red proves nothing.
- **The verifier distrusts the fixer.** Re-derive every finding against the pushed code. Two questions each: does the failure scenario still exist, and would the new test have failed before? And when the PR merged mid-round, a third: is the fix commit an ancestor of the default branch? A squash-merge that lands seconds before the fixer pushes strands the fix on the closed branch — where its checks still run green and gate nothing.

### Where the disclaimer applies

Stage 1 writes to the **issue tracker**, which is triage territory: if the repo's triage convention requires a provenance disclaimer on tracker comments (`triage` mandates one), stage 1's comment carries it. Stages 3–5 write to **pull requests**, where the operator's rules ban AI-attribution lines, badges and session links. Provenance on the tracker; nothing on the PR. Commits keep only the model co-author trailer.

## 6. Close the run

- **A `failed` build is recorded, not swallowed.** Comment on the issue with the reason and what was tried, so the next sweep doesn't re-attempt it blind. No automatic retry — a second attempt at a higher tier is the human's call, made from the report.
- **CI is judged once, at close of run, never per stage** (which is why stages 3 and 5 never wait on pending checks). `gh pr checks` across every PR opened; re-run failures once, since a flake is not a regression. A CI failure that survives the re-run is a fix round dispatched against the **CI log** as its source of truth rather than a review comment — same discipline, including the proven-red regression test.
- **A PR merged mid-run gets a reachability check.** A human awake and merging while a fix round is in flight is a race the sweep must assume, not a surprise: for every PR that merged during the run, confirm each commit the run pushed to its branch is contained in the default branch (`git branch -r --contains <sha>`). A stranded fix is re-landed by cherry-picking it onto a fresh branch off the default and opening a follow-up PR that cites the tracking issue — never by pushing to the merged branch.
- **Promote what earned it, in one pass, after CI is judged.** `gh pr ready <n>` then `gh pr edit <n> --add-reviewer <handle>` on every PR whose item ended `clean`, `minor` or `resolved` **and** whose checks are green. Everything else stays draft with no reviewer on it — `partial`, `could-not-fix`, `still-broken`, or CI still red after its fix round. Promotion and the review request are the same act: the ping is what pulls a human in, so it fires once, on work an agent is willing to vouch for. Draft then carries information — it means an agent knows something is wrong with this PR, so the human reads the ready ones first and the drafts last. A run cut short before this pass leaves everything draft and unassigned, which is the right failure mode; nobody is summoned to work nobody checked.
- **Confirm nothing survives**: no worktrees, no scratch databases, with the literal commands, not from memory.
- **Write a morning report that leads with the outcome table** — one row per queued issue: issue, PR, verdict, state (including skips, not-attempted, `still-broken`). The narrative goes underneath with the re-triage reasoning. The human should be able to decide what to open first from the first ten lines.

Before declaring the run done, apply `superpowers:verification-before-completion` — every claim in the report is backed by a command you ran.

## Red flags — stop

- About to dispatch without a deduped queue, without a concurrency cap, or without per-item overrides for a shared resource.
- A `blocking` verdict whose comment contains no concrete failure scenario.
- A regression test you never watched fail.
- Marking findings resolved on the fixer's word.
- A review that only exists in structured output.
- Worktrees or scratch databases still alive after an item finished.
- A `failed` build or a `still-broken` verdict that reached no one.
- A `still-broken` PR marked ready for review, or a `clean` PR with green checks left in draft.
- A reviewer requested by a stage agent, or sitting on a PR that never got promoted.
- A PR body with the issue link buried in a section, or with sections the four-part shape doesn't name.
- Every issue in the queue produced a PR. (Possible — but check that no planner forced one.)

## Rationalizations

| Excuse | Reality |
|---|---|
| "The queue is triaged, so every item is actionable" | Triage happened before tonight's merges. Recon, then let planners skip. |
| "The bug is obvious, a repro is ceremony" | Confident findings dissolve under a repro more often than you'd like. No repro, no `blocking`. |
| "The fix is right and the test passes" | A test that has never been red is decoration. Revert, run, watch it fail, restore. |
| "The fixer says all three are resolved" | The fixer is the least reliable witness available. Re-derive against the pushed code. |
| "The fixer pushed and its checks are green, so the fix shipped" | Green checks on a branch whose PR already merged gate nothing. Prove the commit is an ancestor of the default branch. |
| "Posting the review duplicates the structured output" | The structured output dies with the run. The PR comment is the deliverable. |
| "I'll clean up worktrees at the end" | Runs get cut short; the end never arrives. Clean up per item. |
| "Two items can share the test database, they won't overlap" | Per-item chaining means they will. |
| "Batch all plans, then all builds — it's tidier" | It's a barrier. One stalled planner costs you the whole run. |
| "All twelve issues can run at once" | Twelve dependency installs and twelve agents against one rate limit. Cap it; queue the rest. |
| "The build failed, the report will mention it" | The report is read once. The issue is read every sweep. Write it there. |
| "Taking it out of draft is the human's call" | The human's call is merging. Draft means an agent found something wrong; leaving every clean PR in it makes the flag mean nothing and adds a click to each one. |
| "The reviewer agent may as well promote its own PR" | It doesn't know CI yet, and a self-promoting reviewer is the fixer problem again. One pass, at close, by the orchestrator. |
| "Request the reviewer at create — GitHub only notifies on ready anyway" | It notifies on request, draft or not. Four hours before the sweep has anything to show, you've pinged someone about a PR no agent has read yet. |
