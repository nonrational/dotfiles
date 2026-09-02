// Reference implementation of the issue-sweep pipeline for the Claude Code
// Workflow harness. The prose in ../references/stage-prompts.md is canonical —
// on any conflict, the prose wins and this file has a bug.
//
// The orchestrator still does recon itself (see SKILL.md §0), then invokes:
//   Workflow({ scriptPath: <this file>, args: {
//     repo:           "owner/name",
//     repoPath:       "/abs/path/to/the/main/checkout",
//     defaultBranch:  "main",
//     ctx:            "<shared context block from recon>",  // stack; the read-only
//                       // rule for the main checkout; literal worktree setup; verify
//                       // commands and the repo's own narrow-vs-full test policy; every
//                       // shared-resource hazard with its override knob, create and drop
//                       // commands; local gotchas by name; commit-trailer rule; PR body
//                       // shape; tracker-comment disclaimer rule; label vocabulary
//     disclaimer:     "> *…*",   // line every ISSUE comment must start with ("" if none)
//     workers:        2,         // items in flight at once — recon's concurrency cap
//     buildModelName: "Claude …",// what build/fix agents write in the co-author trailer
//     models:         { plan: 'opus', build: 'sonnet', fix: 'sonnet' },  // optional;
//                       // a missing key inherits the session model. Review and verify
//                       // are omitted on purpose: they must run on the strongest tier
//                       // available, which is the session model when the orchestrator
//                       // is on it.
//     items: [ {
//       n:            42,                       // issue number
//       title:        "…",
//       slug:         "short-name-42",           // worktree dir: <repoPath>/.worktrees/<slug>
//       branch:       "feature/42-short-name",
//       branchExists: false,                    // true → build ON the existing branch
//                                               // (e.g. one carrying a committed plan doc)
//       hint:         "…",                      // recon's verified prior-work context
//       deps:         "…",                      // PRs/issues whose state the planner confirms
//       planPath:     "docs/plans/….md",        // optional: a committed plan on the branch;
//                                               // stage 1 then confirms it instead of scoping
//       overrides:    "…",                      // optional: orchestrator overrides to that plan
//       verifyExtra:  "…",                      // optional: item-specific verify commands
//     } ]
//   }})
//
// Every string above must come from recon at run time. Nothing repo- or
// machine-specific may be hardcoded here — this file ships in a public repo.

export const meta = {
  name: 'issue-sweep',
  description: 'Turn triaged issues into reviewed PRs: plan, build a draft PR, adversarial review, one fix round, independent verify; N items in flight',
  phases: [
    { title: 'Plan', detail: 'scope one shippable slice, or skip with a tracker comment' },
    { title: 'Build', detail: 'implement in an isolated worktree; open a draft PR' },
    { title: 'Review', detail: 'adversarial review, reproduced before escalating, posted to the PR' },
    { title: 'Fix', detail: 'one round against blocking findings, regression tests proven red' },
    { title: 'Verify', detail: 'independent re-derivation of every blocking finding' },
  ],
}

const A = typeof args === 'string' ? JSON.parse(args) : args
for (const k of ['repo', 'repoPath', 'defaultBranch', 'ctx', 'buildModelName', 'items']) {
  if (!A?.[k]) throw new Error(`issue-sweep workflow: missing args.${k}`)
}
const DISCLAIMER = A.disclaimer || ''
const WORKERS = Math.max(1, Number(A.workers) || 2)
const MODELS = A.models || { plan: 'opus', build: 'sonnet', fix: 'sonnet' }
const opt = (model) => (model ? { model } : {})

const PLAN_SCHEMA = {
  type: 'object',
  required: ['actionable', 'summary'],
  properties: {
    actionable: { type: 'boolean' },
    skipReason: { type: 'string' },
    summary: { type: 'string', description: 'the scoped slice: what is in, what is out' },
    branchName: { type: 'string' },
    prTitle: { type: 'string' },
    steps: { type: 'array', items: { type: 'string' } },
    files: { type: 'array', items: { type: 'string' } },
    tests: { type: 'string' },
    risks: { type: 'string' },
  },
}
const BUILD_SCHEMA = {
  type: 'object',
  required: ['status', 'summary'],
  properties: {
    status: { enum: ['pr-opened', 'failed'] },
    prNumber: { type: 'number' },
    prUrl: { type: 'string' },
    branch: { type: 'string' },
    summary: { type: 'string', description: 'what shipped, what was verified locally' },
    deviations: { type: 'string' },
    failReason: { type: 'string' },
  },
}
const REVIEW_SCHEMA = {
  type: 'object',
  required: ['verdict'],
  properties: {
    verdict: { enum: ['clean', 'minor', 'blocking'] },
    findings: { type: 'array', items: { type: 'string' } },
    commentUrl: { type: 'string' },
  },
}
const FIX_SCHEMA = {
  type: 'object',
  required: ['status', 'summary'],
  properties: {
    status: { enum: ['fixed', 'partial', 'could-not-fix'] },
    summary: { type: 'string' },
    commit: { type: 'string' },
    failReason: { type: 'string' },
  },
}
const VERIFY_SCHEMA = {
  type: 'object',
  required: ['verdict'],
  properties: {
    verdict: { enum: ['resolved', 'still-broken'] },
    notes: { type: 'string' },
  },
}

const SHARED = `
=== SHARED CONTEXT (from the orchestrator's recon) ===
REPO: ${A.repoPath} (GitHub ${A.repo}). Default branch: ${A.defaultBranch}.
${A.ctx}

ISSUE TRACKER: read with \`gh issue view N --comments\`. ${DISCLAIMER ? `Any comment you post on an ISSUE begins with the line  ${DISCLAIMER}` : 'Issue comments carry no provenance line.'} Comments on PULL REQUESTS carry no provenance line and no AI attribution of any kind.

PULL REQUEST: \`gh pr create --draft --base ${A.defaultBranch} --head <branch> --title "<plain sentence, no prefix>" --body "$(cat <<'EOF' … EOF)"\`. Body: \`Resolves #N\` alone on the first line, above the first heading (\`Part of #N\` when later phases remain); then exactly four H3 sections: ### Problem, ### Motivation, ### Proposed Solution (fold in how it was verified and what was deliberately skipped), ### Feedback (what a reviewer should focus on, what is riskiest, which calls need a second opinion). Nothing else: no AI-attribution footer, no "Generated with" line, no session link. If the repo ships its own PR template, that wins; say so in your report. Request NO reviewer and add NO labels; the orchestrator does both at close of run.
`

function branchSetup(it) {
  return it.branchExists
    ? `git worktree add .worktrees/${it.slug} ${it.branch}   # the branch ALREADY EXISTS on origin; never -b a new one, never rebase or force-push it
    cd .worktrees/${it.slug} && git merge --ff-only origin/${it.branch}`
    : `git worktree add .worktrees/${it.slug} -b ${it.branch} origin/${A.defaultBranch}   # if the name is already taken, suffix it with -${it.n} and report the change
    cd .worktrees/${it.slug}`
}

function planPrompt(it) {
  const planMode = it.planPath
    ? `A committed implementation plan already exists: ${it.planPath} on branch ${it.branch}. Read it in full (\`git show origin/${it.branch}:${it.planPath}\`). Your job is to confirm it is still current against the tree and the thread, fold in anything that changed since it was written, and hand the builder a brief that names the plan as the source of truth plus every deviation. Do not re-plan what the plan already settles.`
    : `No plan exists yet. Scope the smallest coherent slice that can ship as ONE draft PR now (for a phased issue, the next phase).`
  return `You are scoping GitHub issue #${it.n} ("${it.title}") in ${A.repo} for a separate build agent that will NOT re-read the issue thread. You are READ-ONLY throughout: no worktree, no edits, no mutating git commands, no tests.
${SHARED}
${planMode}

ORCHESTRATOR'S VERIFIED HINT: ${it.hint || 'none'}

HOW TO READ: \`gh issue view ${it.n} --comments\`. Later comments re-scope earlier ones; ticked checkboxes usually mean shipped. Then check the thread against \`git log origin/${A.defaultBranch}\` and the actual code, and TRUST THE CODE OVER THE THREAD. Read the repo's conventions docs and domain context named in the shared context.

CHECK, with commands, not memory:
1. Is any part already landed? \`gh pr list --state all --search "${it.n} in:title,body" --json number,title,state,headRefName\` and \`gh pr list --state all --head ${it.branch} --json number,state\`, plus \`git log --oneline origin/${A.defaultBranch}\` for the area.
2. Dependencies the work relies on: ${it.deps || 'none named; check the thread for any'}. Confirm each with \`gh pr view <n> --json state,mergedAt\` / \`gh issue view <n> --json state,labels\`.
3. Every file or symbol your brief cites exists on origin/${A.defaultBranch} (\`git ls-tree\`, \`git show origin/${A.defaultBranch}:<path> | grep -n\`).${it.planPath ? ' Spot-verify the plan\'s most load-bearing anchors the same way and report anything missing or moved.' : ''}

SKIP BRANCH (blocked on an open dependency, already landed, or needs a human decision): post one concise comment on the issue${DISCLAIMER ? ' beginning with the disclaimer line' : ''} citing the PRs, commits or comments that decide it; flip the labels per the repo's vocabulary in the shared context; return actionable:false with skipReason.

ACTIONABLE BRANCH: return a brief executable without re-reading the thread. branchName = "${it.branch}"${it.branchExists ? ' (existing; never a new one)' : ' (must collide with no existing local or remote branch; check `git branch -a`)'}. summary = what is IN, what is explicitly OUT, and every deviation you found. steps = ordered, concrete. files = verified to exist (or explicitly new). tests = which tests to add or extend and the exact local commands. risks = what could go wrong. prTitle = one plain sentence in this repo's register (\`gh pr list --state merged --limit 8 --json title\`), no conventional-commit prefix.`
}

function buildPrompt(it, plan) {
  return `You are shipping the planned slice of issue #${it.n} ("${it.title}") as a DRAFT PR. You are running as ${A.buildModelName}, so every commit ends with the trailer exactly:  Co-Authored-By: ${A.buildModelName} <noreply@anthropic.com>
${SHARED}
THE BRIEF (from the plan agent; its scope and deviations are binding — follow it, deviate only with a reason you report back):
${JSON.stringify(plan, null, 2)}
${it.planPath ? `\nTHE PLAN is the source of truth for WHAT to build and in what order: ${it.planPath} (at that path inside your worktree). Follow it task by task, in order, exactly as written, with its own commit subjects. Do not spawn subagents; execute it yourself.` : ''}
${it.overrides ? `\nORCHESTRATOR OVERRIDES (they win where they conflict with the plan or the brief):\n${it.overrides}` : ''}

SETUP, literally:
    cd ${A.repoPath} && git fetch origin
    ${branchSetup(it)}
    <copy or symlink the env file, install dependencies, and read the conventions docs exactly as the shared context says>
    <run the shared context's verify commands on the untouched baseline; it MUST be green before you write code — a red baseline is a finding to report, not something to fix>

BUILD: implement the brief, write the tests it names, keep the diff minimal, nothing speculative. Commit as you go with plain descriptive subjects (no conventional-commit prefix) and the trailer above.

VERIFY, inside the worktree, with the shared context's commands: lint, typecheck, the unit/integration suite against your own resource override (create it first), then the formatter with its fallout included in the commit. For the slow suite follow the repo's own documented policy from the shared context verbatim: if CI runs it on every PR, do not run it locally; if CI does not, run it here before opening the PR.${it.verifyExtra ? `\nItem-specific verification: ${it.verifyExtra}` : ''}

SHIP: \`git push -u origin ${it.branch}\` (a plain push; never force). Then \`gh pr create --draft\` per PULL REQUEST above, title from the brief. Return prNumber, prUrl, branch, a summary of what shipped and what was verified locally (name the commands and their results), and deviations.

CLEANUP, mandatory on both paths: run the shared context's resource drop command(s) from inside the worktree, then from the main checkout \`git worktree remove --force .worktrees/${it.slug} && git worktree prune\`.

FAILURE: if the baseline is red, checks will not go green after honest effort, or the slice proves infeasible — push NOTHING, open no PR, clean up, post one comment on the issue${DISCLAIMER ? ' beginning with the disclaimer line' : ''} stating what was attempted and exactly where it failed (command and error text), and return status failed with failReason. Never force-push. Never touch branches or worktrees you were not assigned.`
}

function reviewPrompt(it, plan, build) {
  return `You are the adversarial reviewer of draft PR #${build.prNumber} (${build.prUrl}), which claims to resolve the planned slice of issue #${it.n} ("${it.title}"). You are the last independent check before a human is asked to look; assume the builder is wrong somewhere and go find it.
${SHARED}
YOU ARE READ-ONLY WITH RESPECT TO GIT AND THE PR: read from the main checkout with \`git fetch origin\`, \`git diff origin/${A.defaultBranch}...origin/${it.branch}\`, \`git show origin/${it.branch}:<path>\` (whole files, not just hunks), and \`gh pr diff ${build.prNumber}\`. To RUN anything (a reproduction, a test), create your own throwaway worktree on a DETACHED checkout — \`git worktree add --detach .worktrees/review-${it.slug} origin/${it.branch}\` — set it up per the shared context, and before you return run the resource drop command(s), \`git worktree remove --force .worktrees/review-${it.slug}\`, \`git worktree prune\`. Never commit, push, or edit files in it.

THE BUILDER'S REPORT (including its stated deviations):
${JSON.stringify(build, null, 2)}
THE BRIEF the builder worked from:
${JSON.stringify(plan, null, 2)}
${it.planPath ? `THE PLAN: ${it.planPath} on the branch (it states the intended behaviour and the explicit non-goals).` : ''}

Load the code-review-register skill before drafting any comment text (Skill tool, name "code-review-register") and write in that register; if it is unavailable, plain declarative prose per the repo's review conventions.

READ: the issue thread (\`gh issue view ${it.n} --comments\`), the PR body, the full diff, and every changed file WHOLE. Hunt the defect classes the shared context names for this repo, plus the universal ones: edge cases, races, domain-encoding mistakes, spec mismatches against the thread, dishonest or missing tests (asserting on the fixture they built, mocked-away behaviour, no red step), migration hazards, documented-convention violations, a PR body missing the four sections or with the issue link buried. Decisions the orchestrator or the brief made on purpose are not defects.

REPRODUCE BEFORE ESCALATING: a blocking finding needs concrete inputs and the wrong output they produce, obtained by running code or a test. Anything you could not reproduce is minor, phrased as a question.

CI: note \`gh pr checks ${build.prNumber}\` if available; do NOT wait on pending checks — CI is judged once at close of run.

POST exactly one comment with \`gh pr comment ${build.prNumber} --body "$(cat <<'EOF' … EOF)"\` (never gh pr review, which can leave a pending review). Even when clean, say what you checked and how. No attribution line. Do not approve, merge, push, edit the PR, request reviewers, add labels, or take it out of draft.

Return verdict (clean / minor / blocking), findings (one line each, blocking ones first and marked BLOCKING), commentUrl.`
}

function fixPrompt(it, build, review) {
  const findings = review.findings || []
  const blocking = findings.filter((f) => /blocking/i.test(f))
  const scope = (blocking.length ? blocking : findings).map((f) => '- ' + f).join('\n')
  return `You are resolving the BLOCKING review findings on draft PR #${build.prNumber} (${build.prUrl}) for issue #${it.n}. You are running as ${A.buildModelName}, so every commit ends with the trailer exactly:  Co-Authored-By: ${A.buildModelName} <noreply@anthropic.com>
${SHARED}
ORCHESTRATOR'S SCOPE NOTE: the review comment at ${review.commentUrl || '(the first review comment on the PR)'} is the source of truth. This round covers these findings and nothing else:
${scope}
Non-blocking nits are out of scope unless the review explicitly ties one to a blocking finding. One round only.

SETUP: \`cd ${A.repoPath} && git fetch origin && git worktree add .worktrees/fix-${it.slug} ${it.branch}\`; inside it \`git reset --hard origin/${it.branch}\` (local must equal origin), then the shared context's env/dependency setup, then the verify commands on the untouched branch.

READ: the review comment, the PR diff, the issue thread${it.planPath ? `, and the plan (${it.planPath})` : ''}.

FOR EACH blocking finding: (1) reproduce it yourself first and turn the reviewer's scenario into a failing test; (2) if it does not reproduce, do not code around it — reply on the PR with your evidence and mark that finding disputed; (3) fix minimally; (4) prove the regression test bites: stash or revert the fix, run the test, watch it FAIL, restore, watch it pass, and say in your PR reply that you did this, naming the test. Keep the diff minimal.

VERIFY with the shared context's commands and your own resource override.${it.verifyExtra ? ` Item-specific verification: ${it.verifyExtra}` : ''}

SHIP: commit plainly with the trailer; \`git push origin ${it.branch}\` (never force). Reply ONCE on the PR in the code-review-register voice (load the skill): what was addressed and how, which regression test was seen red, what was deliberately left and why. No attribution line.

CLEANUP: the resource drop command(s) inside the worktree, then \`git worktree remove --force .worktrees/fix-${it.slug} && git worktree prune\`.

RETURN: fixed (every blocking finding fixed with a proven-red test), partial (some fixed, some disputed with evidence posted), or could-not-fix (checks will not go green: push nothing, clean up, leave the branch as found). Include the pushed commit SHA in "commit".`
}

function verifyPrompt(it, build, review, fix) {
  return `You are independently confirming that the blocking findings on draft PR #${build.prNumber} (${build.prUrl}, issue #${it.n}) are resolved. The fixer reported:
${JSON.stringify(fix, null, 2)}
Do NOT take that on faith; the fixer is the least reliable witness available. Re-derive each finding against the pushed code.
${SHARED}
READ-ONLY GIT: \`git fetch origin\`; read origin/${it.branch} via \`git show\` / \`git diff\` and \`gh pr diff ${build.prNumber}\`. To RUN anything, use a detached throwaway worktree \`git worktree add --detach .worktrees/verify-${it.slug} origin/${it.branch}\` set up per the shared context, and before you return run the resource drop command(s), \`git worktree remove --force .worktrees/verify-${it.slug}\`, \`git worktree prune\`. Never commit or push.

THE ORIGINAL REVIEW: ${review.commentUrl || '(the first review comment on the PR)'}; its findings were:
${(review.findings || []).map((f) => '- ' + f).join('\n')}

FOR EACH original blocking finding: (a) does the failure scenario still exist on the new code? Re-run the reviewer's reproduction. (b) Would the new regression test have failed on the pre-fix code? Check out the pre-fix commit in your throwaway worktree (or revert the fix hunk there) and run that test; it must go red. (c) Merge race: \`gh pr view ${build.prNumber} --json state,mergedAt,mergeCommit\`; if the PR merged while this round was in flight, confirm the fix commit ${fix.commit || '(from the fixer report)'} is an ancestor of origin/${A.defaultBranch} with \`git branch -r --contains <sha>\`. A fix stranded on the closed branch is still-broken in shipped code, and your comment must name the stranded commit and the cherry-pick re-land.

CI: note \`gh pr checks ${build.prNumber}\`; do not wait on pending runs.

If every finding is resolved: post NOTHING and return resolved with notes (what you re-ran and what you saw). If any finding is still live: post ONE follow-up comment on the PR in the code-review-register voice (load the skill) with the concrete failure scenario, no attribution line, and return still-broken. Leave the PR in draft either way; never request reviewers or add labels.`
}

async function runItem(item) {
  const plan = await agent(planPrompt(item), { label: `plan:#${item.n}`, phase: 'Plan', schema: PLAN_SCHEMA, effort: 'high', ...opt(MODELS.plan) })
  if (!plan) return { n: item.n, state: 'failed', stage: 'plan', reason: 'plan agent returned nothing' }
  if (!plan.actionable) return { n: item.n, state: 'skipped', reason: plan.skipReason || plan.summary, plan }
  const build = await agent(buildPrompt(item, plan), { label: `build:#${item.n}`, phase: 'Build', schema: BUILD_SCHEMA, effort: 'high', ...opt(MODELS.build) })
  if (!build) return { n: item.n, state: 'failed', stage: 'build', reason: 'build agent returned nothing', plan }
  if (build.status !== 'pr-opened') return { n: item.n, state: 'failed', stage: 'build', reason: build.failReason || build.summary, plan, build }
  const base = { n: item.n, pr: build.prNumber, prUrl: build.prUrl, branch: build.branch || item.branch, plan, build }
  const review = await agent(reviewPrompt(item, plan, build), { label: `review:#${item.n}`, phase: 'Review', schema: REVIEW_SCHEMA, effort: 'high', ...opt(MODELS.review) })
  if (!review) return { ...base, state: 'review-missing' }
  if (review.verdict !== 'blocking') return { ...base, state: review.verdict, review }
  const fix = await agent(fixPrompt(item, build, review), { label: `fix:#${item.n}`, phase: 'Fix', schema: FIX_SCHEMA, effort: 'high', ...opt(MODELS.fix) })
  if (!fix) return { ...base, state: 'fix-missing', review }
  if (fix.status !== 'fixed') return { ...base, state: fix.status, review, fix }
  const verify = await agent(verifyPrompt(item, build, review, fix), { label: `verify:#${item.n}`, phase: 'Verify', schema: VERIFY_SCHEMA, effort: 'high', ...opt(MODELS.verify) })
  if (!verify) return { ...base, state: 'verify-missing', review, fix }
  return { ...base, state: verify.verdict, review, fix, verify }
}

// A worker pool rather than pipeline(): the number of items in flight is recon's
// concurrency cap (worktrees, dependency installs, scratch resources per item), and
// each item still walks its own stages end to end with no barrier between items.
const queue = A.items.slice()
const results = []
async function worker(id) {
  while (queue.length) {
    const item = queue.shift()
    log(`worker ${id}: #${item.n} starts (${queue.length} queued)`)
    let r
    try {
      r = await runItem(item)
    } catch (e) {
      r = { n: item.n, state: 'failed', stage: 'unknown', reason: String((e && e.message) || e) }
    }
    results.push(r)
    log(`worker ${id}: #${item.n} -> ${r.state}${r.pr ? ' (PR #' + r.pr + ')' : ''}`)
  }
}

log(`Sweep: ${A.items.map((i) => '#' + i.n).join(' ')} in order, ${WORKERS} in flight`)
await Promise.all(Array.from({ length: WORKERS }, (_, i) => worker(String.fromCharCode(65 + i))))

// Close of run stays with the orchestrator: judge CI once across every PR, check
// reachability for anything merged mid-run, promote what earned it, confirm no
// worktrees or scratch resources survive, write the report. This script only
// returns the raw per-item outcomes.
return results
