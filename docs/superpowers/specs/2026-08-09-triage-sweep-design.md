# Triage Sweep — Design

**Prepared for:** @nonrational \
**Author:** Agent Norton (@nonreagent) \
**Date:** 2026-08-09 \
**Status:** Implemented — `home/.agents/skills/triage-sweep/`

## Problem

`issue-sweep` consumes a triaged queue, but producing one still costs the maintainer an attended `triage` session per issue. An untriaged backlog therefore bottlenecks on maintainer attention — and the expensive part isn't the judgment, it's the interruptions: each issue's open questions arrive as a separate ping.

## Design

Sweep the unlabeled / `needs-triage` backlog through the `triage` state machine in bulk, flipping as much as possible to `ready-for-agent` and compressing everything that genuinely needs the maintainer into **one batched interview**. The natural chain is `triage-sweep` → `issue-sweep`.

Per issue, chained without stage barriers: **investigate** (evidence dossier with an empirical reproduction attempt, never a paraphrase of the thread) → **adjudicate** (category + state + draft artifact: agent brief, needs-info questions, or a close recommendation) → **gate** (adversarial re-derivation against the code; strikes any question the codebase could have answered) → **apply** (labels as a *replacement* — exactly one category role and one state role, read back and asserted — plus one disclaimed comment). Then the one deliberate barrier in the pattern: the orchestrator interviews the maintainer with the batched agenda, writes answers back to the issues as the durable record, and re-dispatches answered issues. Bounded: one re-dispatch per issue, 3 rounds per run, 30-minute settle deadline per round.

### Decisions fixed by the operator up front

1. **Autonomy boundary — everything except close.** Unattended, the sweep applies labels and posts comments but never closes an issue and never writes `.out-of-scope/`. A close explicitly confirmed during the interview is human-authorized and executes (with the `wontfix` label swap); rejected-enhancement KB entries are drafted into the report as maintainer action items rather than committed by the sweep.
2. **Questions land twice** — a durable `needs-info` comment on each issue, plus the live batched interview whose answers are posted back to the threads.
3. **In-session rounds** — one invocation loops sweep → interview → apply → re-sweep until nothing new flips; re-invoking later starts a fresh sweep that picks up thread replies. No self-scheduling machinery.

## Adversarial review record

Same two-lens judge pass as `issue-sweep` (operational executability; conventions/integration): 15 merged must-fixes, all addressed.

| Flagged | Change |
|---|---|
| Apply only *added* labels — every issue would end with two state roles, tripping `triage`'s own halt condition | Labels are a replacement with read-back assertion; two-state-labels named a red flag |
| A confirmed close never flipped the state to `wontfix`, and closed issues re-entered the next sweep's queue | Confirmed-close sequence spelled out (label swap → disclaimed comment → close); queue restricted to open issues |
| `disputed` was a dead end — collected for the interview with nowhere to route the answer, and invisible to the next sweep | Dispute question form with three routings (post the draft / side with the gate / `ready-for-human`); unresolved disputes leave a posted record recon detects |
| "The gate strikes questions" was unimplementable — no schema field carried the strikes | Gate may return `approved` with `editedArtifact` + `approvedQuestions`/`struckQuestions`; forced-revise-per-strike gone |
| The `.out-of-scope/` write at the interview was unexecutable (read-only checkout, no commit/push/link mechanics) | Cut from the unattended run — the drafted entry travels in the schema to the report as an action item |
| The round loop had no bound ("flips nothing new" undefined; follow-up questions could loop forever) | One re-dispatch per issue, 3-round default cap, termination defined as no-new-terminal-state |
| The interview barrier had no settle timeout — one hung repro blocked the entire run | 30-minute round deadline; unsettled chains recorded `failed` and excluded from the agenda |
| Maintainer and reporter questions were conflated, burning the interview budget on questions only the reporter can answer | `audience` field on every question; reporter questions post to the thread and wait; wrong-audience is a gate strike |
| A maintainer who answered two batches then left had their answers written back but never acted on | The disengage round still completes stages 2–4 for every answer given |
| The gate never saw interview answers on re-dispatch — predictable spurious `revise` burning the round's budget | Gate briefed on answers, instructed to treat them as authoritative; fresh revision budget per round |
| External PRs were admitted to the queue but no stage could process one | PRs declared out of scope — `triage` handles them interactively |
| Terminal-state vocabulary desynced across the two files (`skipped` never produced; `awaiting-human` colliding with `ready-for-human`; two spellings of `close-recommend`) | One canonical list; recon exclusions get their own reported reason rows |
| Repro worktrees had no path, no base branch, no push ban, no teardown commands | Literal commands: detached worktree under `.worktrees/repro-<issue>`, commit/push banned, `git worktree remove --force` + prune on both paths |
| Loophole: an artifact could @-mention the maintainer — a per-issue ping wearing a comment's clothes | No-notify-by-any-channel constraint; maintainer @-mention is an automatic gate `revise` |
| Stage prompts cited `triage`'s reference docs without a load instruction or fallback | Load-plus-fallback form, with the brief and needs-info shapes enumerated inline |

Smaller ones taken: partial tracker-write failures name exactly which writes landed so the next sweep repairs instead of re-deriving; recon routes label-drift repairs straight to Apply; unlabeled issues the sweep touched always end with at least `needs-triage`; interview overflow carries to the next round's agenda head; freed concurrency slots backfill from the `not-attempted` queue; the vacuous gate label-string check dropped; the agenda cap counts entries of all three kinds (question, close confirmation, dispute).

## Verification

Same gate as [issue-sweep](2026-08-06-issue-sweep-design.md): `make check-skill-frontmatter`, `make check-skills`, `make check-copilot-instructions`, `make test`, and `./deploy.sh apply && ./deploy.sh audit` against a throwaway `$HOME`. Real-world validation is the first unattended run against a live backlog.
