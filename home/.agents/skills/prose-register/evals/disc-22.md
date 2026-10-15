---
id: disc-22
type: discrimination
status: draft
source_commits:
  - 4978536 (before, hand-edited)
  - 159d68a (after)
source_repo: ~/src/alannorton.com
source_file: content/posts/pairs-programming.md
correct: after
expected_rule: '"Just" is banned when it stacks the deck.'
accepted_rules:
  - Concrete nouns over abstractions. Strong verbs over adverbs.
  - Short sentences as impact. They are punctuation, never the baseline.
  - Questions may warm, not only cut.
---

Which variant is on-register, and which SKILL.md rule decides it?

## rule

"Just" is banned when it stacks the deck. / Strong verbs over adverbs. / Short sentences as impact. / Questions may warm, not only cut.

## before

When a colleague leaves a review on my pull request, accepting their nits is often faster than debating them. How often are code review suggestions just plain wrong? It's awfully rare.

## after

When a colleague leaves a review on my pull request, accepting their nits is often faster than debating them. How often is a review suggestion flat wrong? Rarely.

## note

The author's hand edit (4978536) wrote the question and the 'just plain wrong' answer; the next pass (159d68a) cut the modifier and the adverb and landed the answer in one word. Fixture edit: 4978536 sets 'nits' in backticks; 'before' drops them so the pair differs only in the question and its answer. Four rules decide the same pair; any of them passes ('Questions may warm' added 2026-10-14 after a subject credited it first and the judge failed the rule line, though the one-word answer is this rule's own example). The one-word answer is the example added to 'Questions may warm' with this case.
