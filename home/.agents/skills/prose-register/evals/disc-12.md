---
id: disc-12
type: discrimination-structural
status: approved
source_commits:
  - ef020b0 (before)
  - working tree (after, hand-edited, uncommitted as of 2026-07-19)
source_repo: ~/src/alannorton.com
source_file: content/posts/things-ive-changed-my-mind-about.md
correct: after
expected_rule: Open with substance. Close without summary.
arguable: true
---

Which closing is on-register, and which SKILL.md rule decides it? This is a structural judgment, not a sentence-level one -- evaluate the whole closing move.

## rule

Open with substance. Close without summary.

## before

Changing your mind is the work. Read these back to back and they rhyme: I overvalued the artifact and undervalued the people in the room. Correctness over understanding, the code over the company, sounding smart over making anyone else smarter.

There will be more. The next version of me is already re-reading this, shaking his head, and adding entries to the README.

## after

Changing your mind is the work. There will be more. The next version of me is already re-reading this, shaking his head, and adding entries to the README.

## note

'before' spells out the essay's own throughline in plain restatement ('I overvalued the artifact and undervalued the people in the room... Correctness over understanding, the code over the company...') -- a textbook summary-close, the exact move the baseline rule bans. 'after' cuts that sentence entirely and lands on the same closing image (the next version of me shaking his head) without re-explaining what the reader just read. This is a cleaner, essay-sourced example of 'close without summary' than anything in the trust-essay mining, which only had an open-with-substance example (disc-08). Fixture edit (2026-09-20): the hand-edited source reads 'These are hard won lessons, and there will be more.' On all five CI runs to that date the subject chose 'before', reading 'These are hard won lessons' as a summarizing label of its own and 'before's recap triplet as a hard line with a breath; 'after' here drops that clause, and the closing sentence uses the shipped wording in both variants (ef020b0 read 'already reading this and shaking his head, adding entries'), so the pair differs only by the recap sentence the rule bans and the paragraph break that goes with it. Six local bare-$HOME suite runs on the unedited pair had all chosen 'after'; the cause of that CI-versus-local gap is open (see the eval spec), so the key stays arguable until CI runs on the edited pair show the choice holds.
