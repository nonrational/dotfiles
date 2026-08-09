# Stage prompts, output schemas, and the interview

Recipes, not templates. Each stage's dispatch prompt contains the listed parts, in order.

Everything recon learned — repo path, stack, default branch, the **label mapping** (canonical role → actual label string, all five state strings), the tracker's provenance disclaimer text, the maintainer's handle and per-issue reporter handles, the verify commands and any shared-resource override with its literal create and drop commands, the read-only rule for the main checkout, the pre-read digest of conventions docs / domain glossary / ADR index / `.out-of-scope/` filenames — goes in a **shared context block** reused by every prompt.

Machine-wide conventions are restated in these prompts on purpose: a dispatched agent may run under a harness that never loaded this machine's rule set. That's not drift.

## Harness notes

- The schemas below are JSON Schema, passed as the harness's structured-output spec. **If the harness has no structured output**, append to each prompt: write this JSON as the last action to `<scratch>/<issue>/<stage>.json`, and have the orchestrator read the file.
- Harness arguments arrive either as an object or as a JSON string; parse defensively (`typeof args === 'string' ? JSON.parse(args) : args`).
- **Only the orchestrator can reach the human, and no dispatched agent notifies the maintainer by any channel** — no ask tools, no @-mentions in artifacts, no push notifications. Questions travel up through the schemas and wait for the interview barrier.
- Within a round, chain per item (a `pipeline()` per issue, a promise chain, a shell job — whatever the harness calls it). The one legitimate barrier is the interview, which genuinely needs every chain's output at once. Give the barrier a deadline (default 30 minutes per round): a chain that hasn't settled by then is recorded `failed` with the stage it died in and excluded from the agenda — a hung repro must not hold the run hostage.

## 1. Investigate

**Prompt parts, in order:**

1. Role: build the evidence dossier for issue #N, for an adjudicator that will not re-read the thread. You decide nothing, write nothing to the tracker, and never notify anyone.
2. Shared context block, plus the orchestrator's prior-work hint for this issue.
3. How to read: fetch the issue with all comments; later comments re-scope earlier ones; parse prior triage notes so resolved questions stay resolved. Then **trust the code over the thread** — check every claim against `git log` and the actual source.
4. **Redundancy check, by domain concept:** search the codebase for an existing implementation of the requested behavior using the domain glossary's terms, not the request's wording. Report where you looked either way.
5. **Prior-rejection check:** compare against the `.out-of-scope/` filenames in the context block; read any candidate file fully before claiming a match.
6. **Claim verification, empirical:** for a bug, attempt the reproduction from the reporter's steps. If it needs a live run: `git worktree add <repo>/.worktrees/repro-<issue> --detach origin/<default-branch>` (see `superpowers:using-git-worktrees`; never a sibling directory), resource override's create command, then the repro. **In the worktree you may build and run, never commit, push, or create branches.** Tear down on both paths: `git worktree remove --force <repo>/.worktrees/repro-<issue> && git worktree prune`, then the resource drop command. For an enhancement, verify the status-quo description is accurate. Outcomes: `confirmed` (with the code path), `failed` (what happened instead), `insufficient` (what's missing — a strong needs-info signal), `not-verifiable-locally` (recon said so; never silently downgrade to this).
7. **Open unknowns:** list what the thread leaves genuinely unanswered, each tagged with where you looked for the answer first and with who can answer it — the maintainer (a judgment call) or the reporter (a fact about their environment or intent).

```json
{
  "type": "object",
  "required": ["claimStatus", "summary", "redundancy"],
  "properties": {
    "claimStatus":   { "enum": ["confirmed", "failed", "insufficient", "not-verifiable-locally"] },
    "summary":       { "type": "string", "description": "the claim as verified, not as reported" },
    "codePath":      { "type": "string", "description": "for confirmed bugs: where the defect lives" },
    "redundancy":    { "type": "string", "description": "existing-implementation findings + where you looked" },
    "priorRejection":{ "type": "string", "description": "matching .out-of-scope/ entry, if any" },
    "unknowns":      { "type": "array", "items": { "type": "string" }, "description": "each tagged with what was checked first and who can answer" },
    "codeMap":       { "type": "string", "description": "types, interfaces, and modules the adjudicator will need" }
  }
}
```

## 2. Adjudicate

**Prompt parts, in order:**

1. Role: decide category and target state for issue #N and draft the artifact. You write nothing to the tracker and never notify anyone; a separate gate reviews you.
2. Shared context block; the dossier, serialized whole. On a re-dispatch after the interview: the maintainer's answers, verbatim, and an instruction to fold them in rather than re-ask. On a `revise` loop: the gate's instructions.
3. The state machine is `triage`'s: one category role (`bug` / `enhancement`), one state role. Decide from the dossier — do not re-investigate. **Load the `triage` skill and read its `AGENT-BRIEF.md` before drafting**; if it isn't installed, the required shapes are enumerated inline below — follow those.
4. **The artifact, by target state.** Never @-mention the maintainer; the reporter's handle is the only mention allowed, and only in needs-info notes.
   - `ready-for-agent` — an agent brief: category, one-line summary, current behavior, desired behavior, key interfaces from the dossier's code map, independently testable acceptance criteria, explicit out-of-scope. Behavioral contract, never file paths or line numbers.
   - `needs-info` — triage notes in `triage`'s two-section template: what's established so far (from the dossier), then the questions, addressed to whoever can answer. Each question must survive the test *"could an agent answer this from the code, the docs, or the thread?"* — cite the dossier's checked-first tag — and carries an `audience`: `maintainer` questions go to the interview, `reporter` questions live only in the posted note and wait for a thread reply. Where a maintainer question's answer space is enumerable, supply 2–4 concrete options plus your recommendation.
   - `ready-for-human` — brief-shaped, plus one line naming why it can't be delegated (judgment call, external access, design decision, manual testing).
   - `close-recommend` — a `wontfix` close, whether rejection or already-implemented: a draft closing comment citing the evidence (where the implementation lives, or the `.out-of-scope/` match / reasoning). For a rejected enhancement, also draft the `.out-of-scope/` entry body (per `triage`'s `OUT-OF-SCOPE.md`; append to the file `priorRejection` names if one exists) — it travels in the schema for the report, the sweep never commits it. You are recommending, not closing.
5. An `insufficient` or `failed` claim status biases toward `needs-info`. A confirmed dossier with no unknowns biases toward `ready-for-agent`. A `not-verifiable-locally` claim may still reach `ready-for-agent` only if the brief names the limitation and its first acceptance criterion is reproducing the claim. Say which signal decided it.

```json
{
  "type": "object",
  "required": ["category", "targetState", "artifact", "reasoning"],
  "properties": {
    "category":    { "enum": ["bug", "enhancement"] },
    "targetState": { "enum": ["ready-for-agent", "needs-info", "ready-for-human", "close-recommend"] },
    "artifact":    { "type": "string", "description": "the full comment body, ready to post (disclaimer excluded; the poster adds it)" },
    "reasoning":   { "type": "string", "description": "which dossier signal decided the state" },
    "outOfScopeDraft": { "type": "string", "description": "close-recommend of a rejected enhancement only: the drafted KB entry" },
    "questions":   { "type": "array", "description": "needs-info only: structured form of each question", "items": {
      "type": "object",
      "required": ["question", "audience"],
      "properties": {
        "question":       { "type": "string" },
        "audience":       { "enum": ["maintainer", "reporter"] },
        "options":        { "type": "array", "items": { "type": "string" }, "description": "2–4 if enumerable" },
        "recommendation": { "type": "string" },
        "checkedFirst":   { "type": "string", "description": "what was searched before asking" }
      }
    } }
  }
}
```

## 3. Gate

**Prompt parts, in order:**

1. Role: adversarial review of the adjudicator's draft for issue #N before anything touches the tracker. Distrust it; re-derive against the code.
2. Shared context block; the dossier and the adjudicator's full output. On a re-dispatch after the interview: the maintainer's answers, verbatim — **a maintainer answer is authoritative; check the draft honors it, don't re-derive it.**
3. **By target state:**
   - a brief — could an agent weeks from now execute this without the thread? Are the acceptance criteria independently testable? Do the named interfaces exist (read the code)? Any file path or line number is an automatic `revise`.
   - questions — strike any answerable from code, docs, or thread (spot-check the `checkedFirst` claims yourself), any duplicate of prior triage notes, and any with the wrong audience; return the surviving and struck sets explicitly, with the artifact edited to match. A question without a `checkedFirst` tag is an automatic `revise`.
   - a close recommendation — does the cited evidence hold? Read the implementation or the `.out-of-scope/` file it cites. An already-implemented claim you cannot reproduce from the code is a `revise`.
4. Also check: category defensible, tone matches the tracker's conventions, and **no @-mention of the maintainer's handle anywhere in the artifact** — that's an automatic `revise` (the reporter's handle in needs-info notes is fine).
5. Verdicts: `approved` — as-is, or with your strikes applied via `editedArtifact` (small, surgical edits only; substantive rewrites go back as `revise`). `revise` — numbered instructions; the adjudicator gets exactly one more attempt this round. `disputed` — you and the adjudicator still disagree on substance after its revision, or (first pass only) the dossier itself is too broken to adjudicate; nothing posts from the chain — the interview and the report carry the disagreement.

```json
{
  "type": "object",
  "required": ["verdict"],
  "properties": {
    "verdict":         { "enum": ["approved", "revise", "disputed"] },
    "editedArtifact":  { "type": "string", "description": "approved-with-strikes: the artifact as it should post; omit if unchanged" },
    "approvedQuestions": { "type": "array", "items": {}, "description": "needs-info: surviving questions, same shape as stage 2's" },
    "struckQuestions": { "type": "array", "items": { "type": "string" }, "description": "each with the one-line reason it fell" },
    "instructions":    { "type": "array", "items": { "type": "string" } },
    "dispute":         { "type": "string", "description": "for the interview and report: both positions, one line each" }
  }
}
```

## 4. Apply

**Prompt parts, in order:**

1. Role: execute the gated outcome for issue #N — labels and one comment, nothing else. You never close an issue.
2. Shared context block; the approved artifact (the gate's `editedArtifact` when present) and target state.
3. Post **one comment**: the tracker's provenance disclaimer, then the artifact verbatim. No edits, no additions.
4. **Labels are a replacement, not an addition.** One edit: add the category label and the new state label, remove every *other* state-role string from recon's mapping (`close-recommend` keeps `needs-triage` as its state — the close hasn't been authorized). Read the labels back and assert exactly one category role and one state role survived; anything else is a `failed` item, not a shrug. An issue that arrived unlabeled ends with at least `needs-triage`.
5. If a tracker write is rejected (permissions, deprecated API silently no-oping — read back, never assume), undo nothing; report `failed` naming exactly which writes landed (comment, labels, neither) so the next sweep repairs instead of re-deriving.

```json
{
  "type": "object",
  "required": ["status"],
  "properties": {
    "status":     { "enum": ["applied", "failed"] },
    "commentUrl": { "type": "string" },
    "labels":     { "type": "array", "items": { "type": "string" }, "description": "read back after writing, not assumed" },
    "failReason": { "type": "string", "description": "failed: which writes landed and which didn't" }
  }
}
```

## 5. The interview (orchestrator, not a dispatch)

Runs at the round barrier, in the orchestrator's own context — it is the only participant that can reach the human. Every comment the orchestrator posts here carries the same provenance disclaimer stage 4 uses.

1. **Agenda:** every `needs-info` item's surviving **maintainer-audience** questions (the gate's `approvedQuestions`), every `close-recommend`, every `disputed` item. Order by unblock value: answers that flip an issue to `ready-for-agent` first, then close confirmations, then disputes. Cap the round at 12 agenda entries — a question, a close confirmation, and a dispute each count as one; the overflow goes to the head of the next round's agenda, and to the report if the run ends first.
2. **Ask in batches** using the harness's interactive tool (on Claude Code, `AskUserQuestion`: up to 4 questions per call, options plus a free-text escape hatch). Use the adjudicator's options and recommendation where supplied. A close recommendation asks explicitly: *"Close #N as \<reason\>? (evidence: …)"* — anything but a clear yes leaves it a recommendation. A dispute asks: *"On #N the adjudicator wants \<X\>, the gate objects \<Y\> — post the adjudicator's artifact, side with the gate, or take it yourself?"* — routing to stage 4 with the chosen artifact, back through stage 2 with the ruling attached, or to `ready-for-human`.
3. **The maintainer going quiet is an answer.** A declined or abandoned interview means no further rounds — but the current round completes: every answer already given is written back and carried through stages 2–4 before the run ends. Never re-ask an *answered* question within a run; unasked overflow may carry forward.
4. **Write answers back** before re-dispatching: on each answered issue, post a disclaimed comment — *"The maintainer answered during a triage interview:"* — quoting them verbatim, so the thread, not this session, is the durable record. A confirmed close executes now, in order: apply the `wontfix` label (removing the old state label, same replacement discipline as stage 4), post the disclaimed closing comment, close the issue. The sweep still writes no `.out-of-scope/` entry — the adjudicator's `outOfScopeDraft` goes in the report as a maintainer action item.
5. **Re-dispatch** answered `needs-info` issues into the next round at stage 2, answers attached, fresh revision budget, the gate briefed on the answers too. Re-run stage 1 first only if an answer introduced a new verifiable claim (a repro recipe, a version, a counterexample). One re-dispatch per issue, ever.

## 6. Close of run (orchestrator)

1. Post the record for anything that ended without one, disclaimer included: an unresolved `disputed` item gets one comment stating both positions (the gate's `dispute` line), and any still-unlabeled issue the sweep touched gets `needs-triage` applied.
2. Verify cleanup with the literal commands: `git worktree list` shows only the main checkout; every resource drop command has run.
3. Assemble the report: the outcome table first (issue, before → after, category, artifact link, what unblocks the non-terminal rows), then recon's exclusions with reasons, then the action items — drafted `.out-of-scope/` entries, unconfirmed close recommendations, disputes.
