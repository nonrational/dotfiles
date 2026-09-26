---
id: disc-05
type: discrimination
status: draft
correct: plain
expected_rule: Data loss is a blocker and is marked blocking in plain words, never softened into a nit.
accepted_rules:
  - Make the difference between a bug and a style preference obvious in the wording.
---

Which draft follows code-review-register, and which rule decides it?

## rule

Correctness, security, data integrity, and broken contracts are blockers — if the code does the wrong thing, loses data, or breaks an interface, say so plainly and mark it blocking.

## plain

Blocking: `deleteBooking` runs before the audit row is written, so a crash between the two loses the record of who cancelled. Write the audit row first, or wrap both in the transaction.

## softened

nit: `deleteBooking` runs before the audit row is written, so a crash between the two loses the record of who cancelled. Might be worth writing the audit row first, or wrapping both in the transaction. Not blocking.

## note

The finding and the fix are identical; the softened draft misfiles them as a nit.
