---
id: disc-02
type: discrimination
status: draft
correct: three_part
expected_rule: A nit needs its label, one clause of reasoning, and a blocking-or-not signal.
accepted_rules:
  - Never post a nit without a reason attached.
  - Never leave blocking-or-not ambiguous.
---

Which draft follows code-review-register, and which rule decides it?

## rule

Every nit has three parts, in order: the label ("nit:"), one clause of reasoning, a blocking/non-blocking signal. Never post a nit without a reason attached.

## label_only

nit: rename `tmp` to `pendingInvoices`.

## three_part

nit: `pendingInvoices` would say what `tmp` holds, since it survives past the loop. Not blocking.

## note

The label-only draft is missing both the reason and the signal, so either omission is a correct rule to name.
