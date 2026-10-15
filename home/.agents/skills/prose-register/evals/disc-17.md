---
id: disc-17
type: discrimination
status: draft
source_commits:
  - 55bdc85 (before, hand-edited)
  - d947e7c (after)
source_repo: ~/src/alannorton.com
source_file: content/posts/pairs-programming.md
correct: after
expected_rule: Say the feeling once.
---

Which variant is on-register, and which SKILL.md rule decides it? The paragraph follows a quoted code-review reply from the writer's own agent that opened with "Good catch".

## rule

Say the feeling once. A sentence that names a feeling the previous sentence already showed spends it twice.

## before

It names two distinct failures, cites the trigger filter, links the green run, and had pushed the fix before it posted. But, all I could think about was how silly the opening felt. I found that frustrating.

## after

It names two distinct failures, cites the trigger filter, links the green run, and had pushed the fix before it posted. But, all I could think about was how silly the opening felt.

## note

'after' is the author's suggestion, verbatim from d947e7c. Fixture edit: 55bdc85's paragraph also staged the turn ('From a colleague I would think: this person takes review seriously. Then I reached the first two words.') and ran the reaction longer; trans-10 tests that whole paragraph. 'before' here keeps only the sentence that names the feeling again ('I found that frustrating.', verbatim from 55bdc85) so the pair differs in one place.
