---
id: disc-11
type: discrimination
status: approved
source_commits:
  - ef020b0 (before)
  - working tree (after, hand-edited, uncommitted as of 2026-07-19)
source_repo: ~/src/alannorton.com
source_file: content/posts/things-ive-changed-my-mind-about.md
correct: after
expected_rule: No jargon without definition.
accepted_rules:
  - Concrete nouns over abstractions. Strong verbs over adverbs.
arguable: true
---

Which variant is on-register, and which SKILL.md rule decides it?

## rule

No jargon without definition.

## before

No one is watching your work as closely as you assume. Waiting to be noticed is a strategy for being underleveled with great reviews.

## after

No one is watching your work as closely as you assume. Waiting to be noticed is a strategy for staying exactly where you are.

## note

Fixture edit (2026-09-20): the hand-edited source also changed 'as closely as you assume' to 'as closely as you'; 'after' here keeps 'as you assume' so the pair differs only in the jargon clause. Shown with both differences, the subject decided the case on the first one on 2 of 5 CI runs (both chose 'after'). The two wrong choices came from runs that engaged the jargon clause and read 'underleveled with great reviews' as the concrete detail; the one-difference pair does not change that reading, which is why the key stays arguable. 'Underleveled' is HR/performance-review jargon the essay never defines anywhere, for a general readership that shouldn't need to already know it. Fills a documented coverage gap: the trust essay's mined history never caught a live jargon violation being fixed (see the coverage_gaps entry this closes). Note the fix here is CUT, not DEFINE -- 'underleveled' disappears rather than getting a gloss. Accept an answer that names 'No jargon without definition' even though the resolution technique differs from an in-text definition; also accept 'Concrete nouns over abstractions' for 'staying exactly where you are' being more vivid than the jargon term, since both readings are defensible. This term survived unchanged through the automated 'shorten everything' pass (ef020b0) -- only the hand-edit caught it, worth noting if this case is used to argue automated tightening alone isn't sufficient register QA.
