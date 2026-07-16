## Model and Effort Selection

Use this when picking a model and reasoning effort for a task — your own or a delegated subagent's. These are defaults, not laws: the human overrides, and evidence of struggle beats a guess.

### Match the model to the work

- **Brainstorming, ideation, divergent drafting** — Opus or Fable, medium. Breadth matters more than depth here; save the heavy tiers for when a decision is on the line.
- **Planning, triage, architecture, hard root-cause debugging** — Opus, xhigh (max for the gnarliest calls). Choices that are expensive to reverse — or that many later steps lean on — earn the deepest reasoning.
- **Implementation, refactors, delegated research, code review** — Sonnet. The workhorse. Scale effort to risk: mechanical edits run low, integration work runs high.
- **Commit messages, PR summaries, short prose, mechanical transcription** — Haiku, low. Fast and cheap for low-stakes text where the answer is already known.

### Principles

- **Least powerful model that can do the job.** Start low, escalate on evidence — a subagent that stalls, a review that keeps missing things — not on a hunch that a task "feels hard".
- **Turn count beats token price.** A cheap model that flails for ten turns costs more than a capable one that lands in three. When the plan already spells out the steps, the cheapest tier fits; when it doesn't, floor at Sonnet.
- **Effort tracks stakes, not size.** A one-line change to auth logic is high effort; a hundred-line mechanical rename is low. Ask what breaks if you're wrong.
- **Give the last word to Opus.** Whatever tier did the work, the final adversarial review — the one gating a merge — runs on Opus at high effort or above.
- **Name the model when you delegate.** An omitted model inherits the session's, often the most expensive — set it explicitly on every subagent.

### Before dispatching

1. What is this — generate, decide, build or transcribe?
2. Pick the model from the list above; set effort by stakes, not line count.
3. Delegating? State model and effort explicitly in the dispatch.
