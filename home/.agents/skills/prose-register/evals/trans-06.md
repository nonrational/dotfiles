---
id: trans-06
type: transformation
status: approved
source_commits:
  - ef020b0 (before)
  - working tree (after, hand-edited)
source_repo: ~/src/alannorton.com
source_file: content/posts/things-ive-changed-my-mind-about.md
---

## input

At Betterment, plenty of us were sure Ruby had no business near money, yet big pieces of the investor experience ran on Ruby for years without trouble. Safety comes from how you prove the code correct, not from the language you wrote it in.

## task

This paragraph makes its claim in the abstract -- no mechanism, no duration more precise than 'for years'. The facts: the company started on Java; its Java monolith was later broken up piece by piece into separate domain services written in Rails; the largest parts of the investor experience have run on Ruby for close to ten years. Rewrite the paragraph so it names that mechanism and a duration that reads as exact, per 'concrete nouns over abstractions' and 'hedges of precision stay, hedges of cowardice go'.

## reference

Betterment began as a Java shop. When we considered replatforming in Ruby, plenty of us were wary. Yes, we decomposed our Java monolith, bit by bit, into distributed domain services on Rails. The biggest pieces of the investor experience have been running on Ruby for nearly a decade. Safety comes from how you prove the code correct, not from the language you write it in.

## rubric

```yaml
violation_fixed: Does the rewrite name an actual mechanism (a rewrite, a migration, a specific technical move) instead of just asserting the outcome, and replace 'for years' with something that reads as a specific duration?
no_new_violation: No em-dash; watch for the rewrite drifting into a decorative triplet or an unearned 'not X, but Y' -- the reversal here (Java shop -> Ruby) is factual, not rhetorical, so it doesn't need the signature move.
voice_match: Subjective -- the reference uses 'Yes,' as a connective/joint (an affirming beat, not a transition-into-a-question, the only flavor SKILL.md's own examples show); a rewrite that finds a different joint is fine, one with no joint at all is missing the texture.
```

## note

Same underlying paragraph as disc-09 (a three-stage rank until 2026-09-20, now a pair), isolated as a single before/after transformation. The reference answer is the author's own hand-edit, not a synthetic ideal -- treat divergent-but-equally-concrete rewrites as passing, per trans-04's precedent.
