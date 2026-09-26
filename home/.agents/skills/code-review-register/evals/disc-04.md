---
id: disc-04
type: discrimination
status: draft
correct: style_non_blocking
expected_rule: Where a helper lives is a structure preference, and structure defaults to non-blocking.
accepted_rules:
  - Never let a style preference carry the same weight as a correctness bug.
---

Which draft follows code-review-register, and which rule decides it?

## rule

Style, naming, structure, and taste default to non-blocking. Flag them freely, but the author owns the file.

## style_as_blocker

Blocking: `formatTotal` should live in `lib/money.ts` with the other currency helpers, not inline in the component.

## style_non_blocking

nit: `formatTotal` would sit more naturally in `lib/money.ts` with the other currency helpers. Not blocking, your call.

## note

Same ask, same reasoning. Only the weight given to it differs.
