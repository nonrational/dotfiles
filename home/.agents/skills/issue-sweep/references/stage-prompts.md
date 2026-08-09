# Stage prompts and output schemas

Recipes, not templates. Each stage's dispatch prompt contains the listed parts, in order.

Everything the orchestrator learned in recon — repo path, default branch, stack, domain gotchas, the read-only rule for the main checkout, the verify commands, the per-item resource override with its literal create and drop commands, the reviewer handle and commit-trailer format — goes in a **shared context block** reused by every prompt. Below, "the resource override" means those three recon-collected commands pasted in verbatim.

Machine-wide conventions (commit style, attribution bans, worktree placement, model selection) are restated in these prompts on purpose: a dispatched agent may run under a harness that never loaded this machine's rule set. That's not drift.

## Harness notes

- The schemas below are JSON Schema, passed as the harness's structured-output spec. **If the harness has no structured output**, append to each prompt: write this JSON as the last action to `<scratch>/<issue>/<stage>.json`, and have the orchestrator read the file.
- Harness arguments arrive either as an object or as a JSON string; parse defensively (`typeof args === 'string' ? JSON.parse(args) : args`).

## 1. Plan

**Prompt parts, in order:**

1. Role: scoping one issue for a separate build agent that will not re-read the thread.
2. Shared context block.
3. The issue number and title, plus the orchestrator's verified prior-work hint.
4. How to read: fetch the issue with all comments; later comments re-scope earlier ones, ticked checkboxes usually mean shipped. Then check the thread against `git log origin/<default-branch>` and the actual code — **trust the code over the thread**.
5. Which repo docs to read (`CLAUDE.md`, domain context, the triage-label vocabulary).
6. The actionability question: can a well-defined remaining slice ship as ONE draft PR now? For a phased issue, the smallest coherent next phase.
7. **The skip branch, spelled out**: if blocked on an open dependency, already landed, or needing a human decision — post one concise comment on the issue citing PRs or commits, flip the labels per the repo's vocabulary, return `actionable: false` with `skipReason`. Plain prose; carry the tracker's provenance disclaimer if recon found the repo requires one, and nothing else.
8. **The actionable branch**: return a plan executable without re-reading the thread — scope including what is explicitly OUT, ordered steps, key files (verified to exist), which tests to add or extend, risks, a branch name that collides with no existing local or remote branch, and a plain PR title with no conventional-commit prefix.

```json
{
  "type": "object",
  "required": ["actionable", "summary"],
  "properties": {
    "actionable": { "type": "boolean" },
    "skipReason": { "type": "string" },
    "summary":    { "type": "string", "description": "the scoped slice: what is in, what is out" },
    "branchName": { "type": "string" },
    "prTitle":    { "type": "string" },
    "steps":      { "type": "array", "items": { "type": "string" } },
    "files":      { "type": "array", "items": { "type": "string" } },
    "tests":      { "type": "string" },
    "risks":      { "type": "string" }
  }
}
```

## 2. Build

**Prompt parts, in order:**

1. Role: ship the planned slice as a DRAFT PR for issue #N.
2. Shared context block.
3. The plan, serialized whole. "Follow it; deviate only with a reason you report back."
4. **Setup**, as literal commands: fetch; `git worktree add <repo>/.worktrees/<slug> -b <branch> origin/<default-branch>`; if that branch name is already taken (a sibling item claimed it since planning), suffix it with the issue number and report the change; copy in any local env file; install deps; read the repo's conventions docs from inside the worktree.
5. **Build**: implement the plan, write the tests it named, keep the diff minimal, nothing speculative.
6. **Verify**, as literal commands, all run inside the worktree — lint, typecheck, the unit suite with the resource override (run its create command first), then the formatter with its fallout included in the commit. For the slow suite, state the repo's own documented policy verbatim: if CI runs it on push, say so and say not to run it locally; **if CI does not, the build agent runs it here before opening the PR.** Name any local-env gotcha explicitly rather than alluding to one.
7. **Ship**: plain commit message with the model co-author trailer; push; `gh pr create --draft`; body states what changed, why, how it was verified, and the issue link (`Closes #N`, or `Part of #N` when phases remain); request the reviewer handle from the shared context. No AI-attribution lines, badges, or session links anywhere.
8. **Cleanup, mandatory on both paths**: remove the worktree, prune, run the resource drop command.
9. **Failure branch**: if checks won't go green or the slice proves infeasible — no PR, clean up, post one comment on the issue saying what was attempted and why it failed, and return `failed` with the reason. Never force-push; never touch branches you didn't create.

```json
{
  "type": "object",
  "required": ["status", "summary"],
  "properties": {
    "status":     { "enum": ["pr-opened", "failed"] },
    "prNumber":   { "type": "number" },
    "prUrl":      { "type": "string" },
    "branch":     { "type": "string" },
    "summary":    { "type": "string", "description": "what shipped, what was verified locally" },
    "deviations": { "type": "string" },
    "failReason": { "type": "string" }
  }
}
```

## 3. Review

**Prompt parts, in order:**

1. Role: adversarial self-review of PR #N, which claims to resolve the planned slice of issue #M.
2. Shared context block, plus the builder's own report — including its stated deviations.
3. **Load the `code-review-register` skill before drafting any comment text**, and write in that register. If it isn't installed, follow the repo's review conventions in plain declarative prose.
4. Read: the PR, its diff, and the issue thread.
5. Read whole changed files in context, not just hunks (`git show origin/<branch>:<path>` from the read-only main checkout). Name the defect classes worth hunting in this repo — edge cases, races, domain-encoding mistakes, spec mismatches against the thread, dishonest or missing tests, migration hazards, documented-convention violations.
6. **Reproduce before escalating**: a `blocking` finding needs concrete inputs and the wrong output it produces. Anything unreproduced is `minor`, phrased as a question.
7. Note CI state if available; **don't wait on pending checks** — CI is judged once at close of run.
8. Post exactly one comment with `gh pr comment` (not `gh pr review`, which can leave a pending review) — including when clean, saying what was checked. Do not approve, merge, or push fixes.

```json
{
  "type": "object",
  "required": ["verdict"],
  "properties": {
    "verdict":    { "enum": ["clean", "minor", "blocking"] },
    "findings":   { "type": "array", "items": { "type": "string" } },
    "commentUrl": { "type": "string" }
  }
}
```

## 4. Fix

Dispatched only for `blocking` verdicts, with an orchestrator scope note naming which findings are in this round. One round per item. (A CI failure surviving the close-of-run re-run dispatches the same prompt with the **CI log** as source of truth in place of the review comment.)

**Prompt parts, in order:**

1. Role: resolve the blocking review findings on PR #N.
2. Shared context block; the orchestrator's scope note as orientation, with **the posted review comment named as the source of truth** for the findings.
3. Read the review, the diff, and the issue thread.
4. Worktree on the **existing** branch; confirm local matches `origin/<branch>` and hard-reset to origin if it diverged; copy env; install deps.
5. **Verify the claim yourself before coding.** Reproduce it, turn the repro into a failing test, then fix. If the finding turns out to be wrong, don't code around it — say so on the PR with evidence and return `partial`.
6. **Every blocking finding fixed gets a regression test proven to fail on the pre-fix code**: stash or revert the fixed file, run the test, watch it fail, restore. State in the reply that you did this.
7. Keep the diff minimal — no non-blocking nits beyond those the scope note names.
8. Verify with the same commands and the resource override; commit plainly with the co-author trailer; push (**never force-push**).
9. Reply on the PR in the `code-review-register` voice: what was addressed, how, and what was deliberately left with reasons.
10. Cleanup, mandatory. If checks won't go green: clean up, push nothing, return `could-not-fix`, leave the branch as found.

```json
{
  "type": "object",
  "required": ["status", "summary"],
  "properties": {
    "status":     { "enum": ["fixed", "partial", "could-not-fix"] },
    "summary":    { "type": "string", "description": "what changed and how it was verified" },
    "commit":     { "type": "string" },
    "failReason": { "type": "string" }
  }
}
```

## 5. Verify

**Prompt parts, in order:**

1. Role: independently confirm the blocking findings on PR #N are resolved. **State the distrust explicitly** — quote the fixer's report and instruct the agent not to take it on faith.
2. Shared context block.
3. Read the PR comments: identify the original blocking findings and the fixer's reply.
4. Fetch the branch and read the updated code directly. **Re-derive each blocking finding against the new code**: does the failure scenario still exist, and would the new regression tests have failed on the pre-fix code?
5. Check CI state; don't wait on pending runs.
6. Post a follow-up comment **only if a finding is still live**, with the concrete failure scenario, in the `code-review-register` voice, and return `still-broken` — the orchestrator gives it its own row in the morning report. If everything is resolved, post nothing; the fixer's reply already closed the loop.

```json
{
  "type": "object",
  "required": ["verdict"],
  "properties": {
    "verdict": { "enum": ["resolved", "still-broken"] },
    "notes":   { "type": "string" }
  }
}
```
