---
name: triage-sweep
description: Sweep the untriaged issue queue toward ready-for-agent in one run — investigate, adjudicate, and gate each issue in parallel, batch the questions only a human can answer into one interview, apply the answers, repeat.
argument-hint: "Which repo, and how many issues at once?"
disable-model-invocation: true
---

# Triage Sweep

Move a queue of untriaged issues through the `triage` state machine **in bulk**, flipping as many as possible to `ready-for-agent` and compressing everything that genuinely needs the maintainer into one batched interview instead of forty scattered pings.

The output is not a pile of labels. It is a set of issues that each carry a gated artifact — an agent brief, a set of needs-info questions, or a close recommendation with evidence — plus a report the maintainer can act on in one sitting. Downstream, `issue-sweep` turns the `ready-for-agent` yield into draft PRs.

**Use when** a backlog of unlabeled or `needs-triage` issues has piled up and the repo has a triage-label vocabulary. **Don't use** for one contentious issue with the maintainer present (that's `triage`, interactively), to implement anything (that's `issue-sweep`), on pull requests (`triage` handles a PR as an issue with attached code, interactively — this sweep triages issues only), or on a repo with no label vocabulary — establish one first, or the sweep has no states to move between.

**REQUIRED BACKGROUND:** the `triage` skill defines the roles, states, transitions, the brief format (its `AGENT-BRIEF.md` reference) and the `.out-of-scope/` KB (its `OUT-OF-SCOPE.md` reference). This skill parallelizes that machine; it does not redefine it.

## Reference

- [references/stage-prompts.md](references/stage-prompts.md) — the harness contract, per-stage dispatch recipes, output schemas, and the interview and close-of-run mechanics.

## The pipeline

Each issue flows through these stages independently. Nothing waits on a sibling until the interview.

| # | Stage | Model | Writes? | Returns |
|---|-------|-------|---------|---------|
| 1 | Investigate | workhorse | nothing | evidence dossier: claim verification, redundancy, prior rejections |
| 2 | Adjudicate | strong | nothing | category + target state + the draft artifact |
| 3 | Gate | strong | nothing | `approved` (possibly edited) / `revise` / `disputed` |
| 4 | Apply | workhorse | labels + **one comment** | `applied` / `failed` |

**Strong** = the top reasoning tier at high effort; **workhorse** = the mid tier (see `~/.agents/rules/prudence.md` if it's loaded). Name the model on every dispatch or it inherits the session's.

**Control flow.** The gate may strike or edit questions and still return `approved` with the edited artifact. A `revise` verdict loops back through stage 2 once, with the gate's instructions attached — **one revision per round, never two**; a re-dispatched issue gets a fresh revision budget because its input materially changed. Still unapproved after the revision — or unsalvageable on the first pass because the dossier itself failed — → the item is `disputed`: nothing posts from the chain, and the disagreement goes to the interview and the report. Only gate-`approved` artifacts reach stage 4; stages 1–3 never touch the tracker.

**The autonomy boundary.** Unattended, the sweep applies category and state labels and posts comments — briefs, needs-info notes, close recommendations. It **never closes an issue and never writes `.out-of-scope/`** on its own judgment. A `wontfix` close — whether a rejection or an already-implemented request — becomes a posted recommendation with the evidence and a draft closing comment; the state label stays `needs-triage`. The one exception: a close the maintainer explicitly confirms **during the interview** is human-authorized — apply the `wontfix` label, post the closing comment, close. Even then the sweep writes no `.out-of-scope/` entry; for a rejected enhancement it drafts the entry into the report as a maintainer action item.

## Rounds and the interview

The sweep runs in rounds. Within a round, per-item chains; between rounds, one deliberate barrier — the only barrier in this pattern, and the point of it: **batching the maintainer's interruptions is the feature**. Waking them per-issue is what this skill exists to prevent, and no dispatched agent may notify the maintainer by any channel — the interview is the orchestrator's alone.

When every chain settles (or the round's deadline passes — a hung repro must not hold the interview hostage), the orchestrator interviews the maintainer with the batched agenda — surviving maintainer-audience questions, close confirmations, disputes — writes each answer back to its issue, and re-dispatches answered issues into the next round. Mechanics, agenda ordering, caps, and the dispute question form live in [references/stage-prompts.md](references/stage-prompts.md) §5. Freed concurrency slots backfill from the `not-attempted` queue each round.

**Bounds.** At most one re-dispatch per issue, and the run defaults to a cap of 3 rounds. The loop ends early when a round moves no issue to a new terminal state, or when the maintainer disengages — and the round they disengage in still completes: every answer already given is written back and carried through stages 2–4 before the run ends. **If the harness has no interactive ask tool, skip the interview entirely** — the needs-info comments and the report are the degraded output, and the answers arrive as issue replies before the next sweep.

Terminal states, each with its own report row: `ready-for-agent`, `ready-for-human`, `needs-info` (questions posted, unanswered), `close-recommend` (unconfirmed), `closed` (interview-confirmed), `disputed`, `failed`, and `not-attempted` (still queued at run end). Issues recon excluded get an exclusions row with the reason — never silently dropped.

## 0. Recon before you dispatch anything

The orchestrator does this itself, read-only, in the main checkout. A planner discovering mid-run that the repo has no label mapping wastes the whole night.

1. **Preflight.** `gh auth status` and label-edit permission; the repo's default branch (`gh repo view --json defaultBranchRef` — don't assume `main`); the repo's **actual label strings** for the canonical roles (from the repo's triage docs — if no mapping exists, stop and say so); whether an interactive ask tool is available this session.
2. **The queue, snapshotted and deduped** — **open issues only**, in `triage`'s three buckets: unlabeled, `needs-triage`, and `needs-info` with reporter activity since the last triage notes. Exclude, and report with reasons: issues with an open PR attached (that's review work, not triage), and issues whose latest triage note is a prior sweep's un-actioned close recommendation or dispute record (the maintainer hasn't ruled; re-deriving changes nothing). An issue carrying a prior sweep's gated artifact whose labels don't match it goes straight to stage 4 to fix the labels — don't re-derive, don't re-post.
3. **Verification affordances.** The repo's verify commands and any shared-resource override with literal create/drop commands (as `issue-sweep` recon defines them) — stage 1 needs these to reproduce bug claims. If claims can't be verified locally, say so in every dossier rather than silently downgrading.
4. **Context worth pre-reading once:** the repo's conventions docs, domain glossary, ADR index, `.out-of-scope/` filenames — distilled into the shared context block rather than re-read by every agent.
5. **Attribution facts.** The tracker's provenance disclaimer (mandatory on every comment this sweep posts, whether from stage 4 or from the orchestrator itself), the maintainer's handle, and the reporter handle per issue.
6. **A hint per item** — one or two sentences of prior-work context, verified against code and PR history.
7. **A concurrency cap.** Default 4 concurrent items; bug-heavy queues cost a worktree and dependency install per repro. Queue the remainder as `not-attempted`; backfill as slots free.

Then **order the queue by unblock value**: bugs before enhancements, old `needs-info` with fresh replies first — answered questions are the cheapest flips available.

## The disciplines

- **Investigation is empirical, not textual.** A bug claim gets a reproduction attempt from the reporter's steps; an enhancement gets a redundancy check by domain concept, not by the request's wording, with "where I looked" reported. A dossier that only paraphrases the thread is a failed investigation.
- **A question must earn its place in the interview.** The gate strikes any question answerable from the code, the docs, or the thread — asking the maintainer what the codebase already knows is the failure mode that makes bulk triage annoying instead of useful. Every surviving question names what was checked first, and questions for the **reporter** post to the issue instead of spending the maintainer's interview budget.
- **The brief is written for an agent that arrives weeks later.** Behavioral contract, acceptance criteria, scope boundaries; interfaces and types, never file paths or line numbers (`triage`'s `AGENT-BRIEF.md`).
- **The gate re-derives, it does not proofread.** For a brief: could an agent execute this without the thread? For a close recommendation: does the cited evidence actually hold? The gate reads the code the dossier cites.
- **Writer and gate are different dispatches.** The adjudicator never gates its own draft.
- **One state role, one category role — enforced at write time.** Stage 4 replaces the old state label and reads the result back; two state roles on one issue is the base machine's halt condition, not a cosmetic bug.
- **Every posted comment carries the tracker's provenance disclaimer** — the orchestrator's own posts included. Interview answers are posted as quotes attributed to the maintainer, under the same disclaimer.
- **Isolation and cleanup are per item.** A repro worktree lives under `<repo>/.worktrees/`, detached, forbidden to commit or push, and is torn down with its scratch resources before the item returns, either path. A cut-short run leaves nothing behind.

## Close the run

- Post the record for anything that ended without one: unresolved disputes get a disclaimed comment stating both positions, and any unlabeled issue the sweep touched ends with at least `needs-triage` applied — the queue must shrink monotonically across sweeps.
- Verify nothing survives: `git worktree list` shows only the main checkout, and every scratch resource's drop command has run.
- **Write a report that leads with the outcome table** — one row per queued issue: issue, before → after state, category, artifact link, and for the non-terminal rows what unblocks them. Close recommendations and `disputed` items flagged loudest; drafted `.out-of-scope/` entries attached as action items; the maintainer should be able to act from the first ten lines.
- A `failed` item names exactly which writes landed (comment, labels, neither), so the next sweep repairs instead of re-deriving blind.

Before declaring the run done, apply `superpowers:verification-before-completion` — every state in the report links the comment or label change that justifies it.

## Red flags — stop

- About to dispatch without the label mapping, without a deduped queue snapshot, or without a concurrency cap.
- A comment, label, or close about to happen in stages 1–3.
- An artifact that @-mentions the maintainer — that's a per-issue ping wearing a comment's clothes.
- An interview question you didn't check the codebase for first, or one only the reporter can answer.
- A close executed without an explicit interview confirmation.
- An issue about to end the run with two state labels, or with none.
- A brief containing file paths or line numbers.
- An issue flipped to `ready-for-agent` whose claim was never verified and whose brief the gate never saw.

## Rationalizations

| Excuse | Reality |
|---|---|
| "The issue is obviously a bug, skip the repro" | Obvious claims dissolve under a repro often enough. Unverified → the brief says so, or it's a question. |
| "The maintainer filed it, so no questions needed" | The maintainer three weeks ago is not the codebase today. Verify anyway. |
| "Closing this duplicate is harmless" | Closing is outward-facing and unattended closes erode trust in every label the sweep applied. Recommend; let the interview confirm. |
| "Asking is faster than checking the code" | One lazy question costs maintainer attention; forty make the sweep net-negative. Check first. |
| "The gate is a rubber stamp, the draft looks fine" | The gate that re-derives is the only thing standing between a plausible brief and a wasted `issue-sweep` night. |
| "Batch all investigations, then all adjudications" | A stage barrier stalls every issue behind the slowest dossier. Chain per item; the interview is the only barrier. |
| "Interview the maintainer as answers come up" | Scattered pings are the disease this skill treats. One agenda, at the barrier. |
| "They answered two batches then left — park the answers" | Answers given are contracts. The disengage round still completes stages 2–4 for every one of them. |
| "No ask tool, so post questions and keep looping" | Without answers a second round re-derives the first. Degrade to comments + report, end the run. |
