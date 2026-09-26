---
skill: code-review-register
min_pass_rate: 0.75
---

# code-review-register evals

## Description

Discrimination, transformation, and detection cases for the reviewer's voice: what blocks, how a nit or question is shaped, when a fix is a suggestion block, and where humor may point. Every case is a synthetic minimal pair on a neutral scenario.

## Provenance

- **date_authored:** 2026-09-25
- **source:** Synthetic. Each case was written from one rule in SKILL.md with a fresh scenario; no Bad/Good pair from the skill text is reused, because the subject loads that text and a verbatim pair would test recall rather than judgment.
- **anonymization:** Scenarios are invented (a CSV importer, a booking service, a rate limiter, a settings export). No real repository, vendor, or person appears.
- **construction:** A discrimination pair differs in the one rule it tests and nothing else. Transformation tasks state every fact the rewrite needs so the subject never has to invent one. Detection documents plant well-formed comments as traps beside the violations.

## Case types

- **discrimination:** Pick the draft that follows the register. Grade on the chosen draft; the rule named is recorded but never counts.
- **transformation:** Rewrite one draft comment or review summary. Grade against the rubric, not the reference wording.
- **detection:** Find every failing comment in a full review while leaving the well-formed ones alone. Grade recall against violations and precision against traps.

## Coverage gaps

- **Own mistakes immediately and warmly.** A reviewer-side apology needs the thread that preceded it; a minimal pair without that context tests tone in a vacuum.
- **Name-check another opinion when the call affects people beyond the author.** Whether a call reaches beyond the author is a fact about the team, not the diff, so a synthetic case cannot make the key unambiguous.
- **Multi-paragraph take: hedge before, out after.** Not yet paired. A long take with and without its framing lines is a natural discrimination-structural case.
- **Real review comments.** Every case here is synthetic. A labeling pass over real review threads from public repositories, triaging each comment as good or bad, would supply mined pairs: a triaged bad comment beside its rewritten good form is a ready-made discrimination case.
- **Keep the diction concrete in suggestion-block prose: name the token, quote the on-screen text, say guard rather than gate.** Not yet paired; a minimal pair would differ only in 'it' versus the named token.
- **Frame a recommendation as personal experience where true.** Whether the experience is true is a fact about the reviewer, so a synthetic key cannot make it unambiguous.
- **Never let a dismissive line stand without a counterbalancing signal of respect.** Not yet paired; distinct from the joke-target rule in disc-10.

## Notes

Both detection documents plant a correct blocking comment, a three-part nit, a reasoned question, a code-targeted joke, or a suggestion block as traps. A subject that reads the register as 'soften everything' or 'strip all personality' should trip them. disc-11 is the one taste key and is flagged arguable. Case count: 13 discrimination, 3 transformation, 2 detection.
