---
id: disc-06
type: discrimination
status: approved
source_commit: "5e09562"
correct: after
expected_rule: No em-dashes. Full stops, semicolons, parentheses, en-dashes.
---

Which variant is on-register, and which SKILL.md rule decides it?

## rule

No em-dashes. Full stops, semicolons, parentheses, en-dashes. / Lint: "An em-dash."

## before

same eleven days — but by a hundred engineers ... The system is comprehended — the knowledge lives ... cost $165,000 — a purchase, not a sacrifice

## after

same eleven days – but by a hundred engineers ... The system is comprehended – the knowledge lives ... cost $165,000 – a purchase, not a sacrifice

## note

Purely mechanical: three em-dashes (—) become spaced en-dashes (–). No wording changed. This is the easiest discrimination case in the set -- useful as a sanity check that the grader itself can tell an em-dash from an en-dash, which some renderers and terminal fonts collapse visually.
