---
id: disc-24
type: discrimination
status: draft
source_commits:
  - 33aff79 (published; 'before' is a fixture built on the hand edit)
  - working tree on 2026-10-14 (after; the author's post-merge hand edit, uncommitted when mined)
source_repo: ~/src/alannorton.com
source_file: content/posts/pairs-programming.md
correct: after
expected_rule: No announcements.
accepted_rules:
  - Connectives are joints, not filler.
---

Which variant is on-register, and which SKILL.md rule decides it? Both close the introduction and hand off to the first section; they differ in the second sentence.

## rule

No announcements. A sentence that promises the next point, grades it, or trails an anecdote is a teaser. A joint that only turns the corner stays.

## before

And so, I set out to make the machine sound more like me. The next part is the one that took the most work, and the one that matters.

## after

And so, I set out to make the machine sound more like me. Let's talk about code review!

## note

'after' is the author's own hand edit, made after the post merged and read as the voice the register describes. Under 'No announcements' as first written, a reviewer flagged the pivot as a teaser; the author's position is that the edit is the voice and the rule was too wide. The distinction the rule now draws: a joint turns the corner and promises nothing about what follows; a teaser grades the next point or trails a story. 'before' is a fixture: the same pivot rewritten as a graded teaser, so the pair differs in one sentence. 'Connectives are joints, not filler' is accepted because it names the same move from the keep side. The source commit for 'after' is the one that lands the hand edit; update it when that commit exists.
