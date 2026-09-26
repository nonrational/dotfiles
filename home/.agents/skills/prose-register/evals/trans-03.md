---
id: trans-03
type: transformation
status: approved
source_commits:
  - 5aae06b (before)
  - e1fc1c1 (after)
---

## input

```
### The Slop That Passed Its Tests

Not everyone was thrilled. The creator of Zig, the language Bun walked away from, called the rewrite "unreviewed slop."

That phrase contradicts itself, and the contradiction is the point. _Slop_ is a verdict on **Competence**—sloppy, low-quality work. But _unreviewed_ means he never inspected the Competence. He didn't read it. So the word isn't reporting what he found in the code; it's reporting his prior about who wrote it. He grabbed a quality-insult to voice something that was never about quality.

Because the code works. The test suite passes on every platform; the new version fixes 128 bugs and runs a few percent faster. On **Competence**, the machine delivered, measurably. What a green test suite cannot measure is **Character** and **Caring**—whether the code honors the architecture or hides a subtle vulnerability, whether it sweated the edge cases or confidently blasted out the first plausible thing six thousand times over. "It passes every test" and "I don't trust it" are not in conflict. They are claims about different terms of the equation. The critic isn't wrong to distrust a core runtime that one engineer and sixty-four agents produced in eleven days. He is just wrong about which term he is objecting to.
```

## task

This section builds its whole argument around the critic's word 'slop' and a self-contradiction reading of it. Reframe it around a 'not X, but Y' move instead -- the reversal should BE the argument, not decorate it -- using a hundred-human-engineers counterfactual to locate what's actually missing when a machine does the work alone.

## reference

```
### A Hundred People for Eleven Days

Run the counterfactual. Suppose the same rewrite had shipped on the same schedule – same runtime, same eleven days – but by a hundred engineers pulling nights and weekends. We'd have opinions about the crunch, but we would not feel what we feel about the machine version. So what makes the AI one worse?

Not the speed, and not the risk; those are identical in the counterfactual. What the hundred people bring that the machine doesn't is themselves. A hundred engineers is a hundred minds that each understood a piece of the thing, chose it, and can answer for it later. The system is comprehended – the knowledge lives in people who were there. When the machine does it, the code exists and the understanding lives nowhere. You are handed a working runtime that no mind holds. That is the genuinely new part, and the unsettling one: not unreviewed code, but un-authored knowledge, severed from any knower.

There is a second thing. Nights and weekends are Caring you can see, because it cost someone something, and we read the cost as belief. The machine's version cost $165,000 – a purchase, not a sacrifice. We know how to trust care that hurt to give. We do not yet know how to trust care that came off an invoice.

Put the formula on it and the discomfort has a name. A human team hands you the whole numerator in one body: Competence, bundled with the Character and Caring of the people who did the work. The machine hands you Competence alone, unbundled, with no one standing behind it. For the first time you can buy that one term by itself. The unease was never that the work is bad. It is that the work no longer implies a worker.
```

## rubric

```yaml
violation_fixed: Does the rewrite drop the 'slop is a self-contradicting verdict' framing entirely (not just soften it) and replace it with a reversal that carries the argument, e.g. 'not unreviewed code, but un-authored knowledge'?
no_new_violation: No em-dash (the reference uses en-dashes throughout, which is correct post-5e09562, not a violation); no flattery; the reversal must argue something, not just decorate a sentence -- 'a reversal used for cleverness rather than argument' is a named Lint failure.
voice_match: Subjective, and the hardest of the five transformation cases -- this is closer to real editorial work than a sentence fix. A partial match (keeps the 'unreviewed slop' quote as a launching point but resolves it with a different reversal) should still score well on (1) if the new reversal does real work.
```

## note

This is the doc's 'most generative' case -- there is no single correct rewrite, only a family of reversals that would satisfy the rule. Grade the shape of the move, not textual proximity to this exact reference. This section was itself revised again before publication (069e841 sharpens 'care that hurt to give' / 'came off an invoice' to 'care as a sacrifice' / 'care as a line item' -- see trans-04); e1fc1c1 is used here as the reference because it's the commit where the reframe itself happens, which is what this case tests.
