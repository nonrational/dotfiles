---
id: disc-04
type: discrimination
status: approved
source_commits:
  - f98e637 (over-cut)
  - 3c2f396 (restored)
correct: after
expected_rule: Connectives are joints, not filler.
arguable: true
---

Which variant is on-register, and which SKILL.md rule decides it? The opening paragraph is the same in both; the difference is the sentence that follows it.

## rule

Connectives are joints, not filler.

## before

Developer communities did not take it well, and an AI rewriting a low-level runtime out from under everyone is an unsettling thing to sit with. But very soon, if you run tools like Claude locally, you will be executing on that very Rust rewrite. Like it or not, we are becoming users of AI-authored infrastructure.

How do you trust code a machine wrote?

## after

Developer communities did not take it well, and an AI rewriting a low-level runtime out from under everyone is an unsettling thing to sit with. But very soon, if you run tools like Claude locally, you will be executing on that very Rust rewrite. Like it or not, we are becoming users of AI-authored infrastructure.

Which raises the question: how do you establish *trust* in code written by a machine?

## note

Same underlying sentence as disc-02, one revision cycle later: c8fa24c had already fixed the melodrama, then f98e637's over-tightening pass cut the connective back down to a bare question, then 3c2f396 restored it. Good for showing the rule isn't 'shorter is always better' -- the cut version isn't wrong on any other axis, it's wrong specifically for dropping the joint. Fixture edit (2026-09-20): both variants now open with the paragraph that precedes this sentence in c8fa24c (the same text as trans-02's reference), so 'Which raises the question:' has something to join. Shown alone, the pair lost the subject on 3 of 12 keyed runs (the 2026-07-18 local probe and 2 of the 5 CI runs, both on the compare-first prompt; the six local suite runs all picked the key), each time by reading the connective as decorative preamble with nothing to connect to. In f98e637 the preceding paragraph was itself tighter (see det-02); the c8fa24c text is used for both variants so the pair differs in one place. Kept arguable until CI runs with the context show the choice holds.
