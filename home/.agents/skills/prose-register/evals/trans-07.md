---
id: trans-07
type: transformation
status: approved
source_commits:
  - ef020b0 (before)
  - working tree (after, hand-edited)
source_repo: ~/src/alannorton.com
source_file: content/posts/things-ive-changed-my-mind-about.md
---

## input

No one is watching your work as closely as you assume. Waiting to be noticed is a strategy for being underleveled with great reviews.

## task

'Underleveled' is performance-review jargon the essay never defines. Either cut it for plain language or define it in place, per 'No jargon without definition'.

## reference

No one is watching your work as closely as you. Waiting to be noticed is a strategy for staying exactly where you are.

## rubric

```yaml
violation_fixed: Is the undefined jargon term gone or explicitly glossed?
no_new_violation: Check the rewrite doesn't introduce a new abstraction in its place -- 'staying exactly where you are' is concrete/spatial, not a fresh euphemism.
voice_match: Subjective -- accept a rewrite that defines 'underleveled' inline instead of cutting it (e.g. 'paid and titled below what the work is worth'), since SKILL.md's rule allows either resolution; score it on whether the definition itself stays plain, not jargon-on-jargon.
```

## note

First transformation case in the set that exercises 'No jargon without definition' -- previously a documented coverage gap.
