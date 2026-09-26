---
id: disc-10
type: discrimination
status: approved
source_commits:
  - d847318 (before)
  - ef020b0 (after, "shorten everything")
source_repo: ~/src/alannorton.com
source_file: content/posts/things-ive-changed-my-mind-about.md
correct: before
expected_rule: Concrete nouns over abstractions. Strong verbs over adverbs.
accepted_rules:
  - A hard line needs a breath next to it. Vary the pressure, not only the length.
---

Which variant is on-register, and which SKILL.md rule decides it?

## rule

Concrete nouns over abstractions. Strong verbs over adverbs.

## before

When I fell in love with Ruby, I fell in love with how much you could say with a name. You can write `validate :reservation_must_be_for_today_if_city_is_mealpal_now_only` and the code narrates itself. A class is a pipeline of whole business rules you can read out loud, no comment required.

## after

Ruby taught me how much you can say with a name. The code read like a sentence, so I decided comments were a failure: if your code needs one, your code isn't good enough.

## note

One of two cases in this set (with disc-09) where the automated pass makes things worse, not better -- worth keeping precisely because a model shouldn't assume 'after' is always the answer. 'before' backs its claim with an actual, slightly funny, real method name; 'after' asserts the identical claim ('the code read like a sentence') with no evidence at all. This cut was never restored in the later hand-edit pass either (checked against the source repo's working tree as of 2026-07-19) -- flag that to a human if this case is used to test whether a model notices an opportunity to restore, not just judges two fixed variants. CI evidence (five runs to 2026-09-20): the choice was right on every run, and the RULE line cited the breath rule on four runs (the method name being the breath in a paragraph of claims) and 'No flex' on one; the breath rule is accepted.
