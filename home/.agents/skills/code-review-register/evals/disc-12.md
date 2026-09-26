---
id: disc-12
type: discrimination
status: draft
correct: approved
expected_rule: A review with only non-blocking comments approves, and says so, rather than withholding approval.
---

Which review summary follows code-review-register, and which rule decides it?

## rule

Default to approving when nothing is blocking. A review with only non-blocking comments should approve, not sit un-actioned holding up a merge. Say so when it could read as ambiguous.

## withheld

Leaving this un-approved for now. Two nits below, both non-blocking: the `pageSize` default could live beside the other query defaults, and `rows` reads more clearly as `invoices`.

## approved

Approving; none of this is blocking, your call on all of it. Two nits below: the `pageSize` default could live beside the other query defaults, and `rows` reads more clearly as `invoices`.

## note

Both summaries carry the same two nits and label them non-blocking. Only the verdict differs.
