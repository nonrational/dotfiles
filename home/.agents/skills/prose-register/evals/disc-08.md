---
id: disc-08
type: discrimination-structural
status: approved
source_commits:
  - 5edc968 through 3c2f396 (direct opening)
  - e55f75c (headline opening, shipped)
correct: headline_device
expected_rule: Open with substance. Close without summary.
accepted_rules:
  - A hard line needs a breath next to it. Vary the pressure, not only the length.
arguable: true
---

Which opening is on-register, and which SKILL.md rule decides it? This is a structural judgment, not a sentence-level one -- evaluate the whole opening move.

## rule

Open with substance. Close without summary.

## direct

Recently, the creator of Bun burned through roughly $165,000 in tokens to rewrite their core runtime from Zig into Rust. The migration was completed in just 11 days, with a pre-release version of Claude Fable 5 authoring nearly all of the 6,778 commits.

## headline_device

Consider two headlines:

> **Bun spends $165,000 on overtime as engineers work 80-hour weeks to rewrite its runtime in 11 days**

> **Bun spends $165,000 on AI tokens to rewrite its runtime in 11 days**

Same company, same invoice, same deadline. Either way the story ends in the same artifact: a runtime on a release page, waiting for you to install it. So the question is not which headline you prefer. It is which binary you run.

## note

Both openings arguably 'open with substance' -- neither throat-clears. This is the doc's flagged coarse-grained case: every commit before e55f75c used the direct opening; e55f75c replaced it with the headline device and it shipped that way. Treat 'correct' as the author's actual final call, not a strict rule violation in the 'direct' version -- a model arguing 'direct' is also acceptable on baseline grounds is making a defensible case. Grade on whether the answer identifies the real tradeoff (immediate fact vs. rhetorical framing that still front-loads substance) rather than marking 'direct' wrong outright. CI evidence (five runs to 2026-09-20): the subject chose 'headline_device' on every run and cited the breath rule on every run, reading the two block quotes and the run of argument after them as pressure varied on purpose; that rule is accepted, since the headline device is a breath move as much as an opening one.
