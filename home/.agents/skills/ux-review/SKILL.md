---
name: ux-review
description: Review a single UI screen against nine parsing-cost lenses and produce a findings doc ranked by how hard the user works to read the answer, an explicit "don't touch" list, and a risk-phased fix plan. Use when critiquing or auditing an existing or proposed screen, when a UI feels cluttered or buried, before/after a UI build, or when the user says "ux review", "review this screen/page/card", "make this parseable", or invokes /ux-review.
---

# UX Review

A discipline for reviewing one screen: render it against real data, name the central failure in one sentence, rank findings by how hard the user works to extract the answer, name what already works, and phase the fixes by risk. Produces a findings doc — not a pile of nitpicks.

## When to use

Any time you're critiquing or auditing an existing or proposed screen — "review this page", "why does this feel cluttered", right before or after a UI build. One screen (or one card/component) per pass; a whole app is several passes.

## The loop

Work these six steps in order. Create a todo per step.

1. **Scope & render.** Name the screen *and the user's job on it* ("triage a support ticket", not "the tickets page"). Then look at the real thing: drive it against realistic data — the full seed, not a 2-row mock — via `/run` or the browser, and capture what you see. Realistic also means *varied*: a seed where every row looks alike can show you that the screen is uniform, but never what its differences mean. **Then** trace the component path in code. No live env? Fall back to a code-read and say so in the writeup — a code-only pass is structurally blind to visual-weight and color findings.
2. **State the core diagnosis.** One sentence naming the central failure, framed by the user's job: "the card buries its own answer." Can't write that sentence? You haven't found the problem yet — keep looking.
3. **Find & rank.** Sweep the nine lenses in `references/lenses.md`. Each finding = named defect · why it costs the user · concrete evidence (the string, the element, the screenshot). Rank by **parsing cost** — how much work the user does to extract the answer — not by how easy the fix is. The cheapest fix is rarely the highest-leverage one. Any finding asserting what a color or weight *means* is a hypothesis — run it through **Verifying a visual claim** below before it reaches the doc.
4. **Name what's fine.** Write an explicit "don't touch" list of the mechanics that already work. This scopes the change and protects working behavior from churn — it's the step most reviews skip, and skipping it is how a review turns into a rewrite.
5. **Phase by risk.** Group fixes: **Phase 1** copy / hierarchy / CSS (no data changes) · **Phase 2** structural (layout, component shape) · **Phase 3** new data or navigation. Map every item back to its finding(s) and an effort estimate. Order highest-leverage-first. Flag any test that pins a copy string you're changing.
6. **Hand off.** Emit the doc in the template below. Offer to file it via whatever tracker the project has (GitHub issue, PROJECT.md, a plan) — don't assume one exists.

## Verifying a visual claim

"This green means X" is a hypothesis, and a screen almost always admits more than one explanation. Two checks, in order — the second is the one that bites.

1. **Read the computed style, not the screenshot.** Image compression, contrast against neighbouring colors, and theme rendering all shift what a color looks like. Query the element — computed styles, the class list, devtools — before you write the claim down.
2. **Then test it where your explanations disagree.** List the candidate readings and ask what data would make them differ. If two readings predict the *same* rendering for the item in front of you, that item is worth nothing as evidence no matter how carefully you measured it.

*e.g.* Line numbers in a diff viewer render green. Two readings: "this line is part of the changeset" and "this line is covered by tests". On a fully-changed, fully-covered file both predict every line green — so any amount of careful inspection there confirms nothing. Open a file with a changed-but-uncovered line and the readings come apart at a glance.

**Finding the discriminating case.** Ask for the item that splits the readings: selected but unhealthy, included but empty, partial rather than complete, sitting on a boundary. Then go get that item on screen — staging state, expanding a row, or picking a different record usually gets you there. If your data has no such case, say so in the writeup and describe the encoding as unconfirmed rather than asserting it.

This applies to any encoding, not just color — weight, size, position and iconography all invite the same mistake.

## Optional: adversarial pass

For a high-stakes review, dispatch a cheap subagent per finding (or one skeptic for the whole set) prompted to *refute* it — "argue this isn't real; default to refuted if unsure." Drop findings that don't survive. Catches plausible-but-wrong claims before they reach the plan.

## Output template

See the shape and quality bar in `references/worked-example.md`. Sections, in order:

- **Context** — one line: screen · data reviewed against · component path (or "code-read only").
- **Core diagnosis** — the one sentence.
- **Findings, ranked by parsing cost** — F1…Fn, each: defect name, why it costs, evidence.
- **Fine as-is (don't touch)** — the list.
- **Phased plan** — Phase 1/2/3, each item mapped to finding(s) + effort; ordering note; test notes.

## References

- `references/lenses.md` — the nine lenses, each as Smell · Ask · Fix · e.g.
- `references/worked-example.md` — a full review of a generic triage card, start to finish.
