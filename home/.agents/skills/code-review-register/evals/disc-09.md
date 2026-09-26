---
id: disc-09
type: discrimination
status: draft
correct: with_path
expected_rule: Critique comes with a path to resolution, never on its own.
accepted_rules:
  - Never bury the why; put it in the same comment.
---

Which draft follows code-review-register, and which rule decides it?

## rule

Never post pure critique with no path to resolution.

## with_path

This search query is going to fall over on large tenants: it has no limit and loads every ticket before filtering. Pushing the status filter into the query and paging at 200 would keep it bounded.

## no_path

This search query is going to fall over on large tenants.

## note

The no-path draft is a verdict with no reason and no fix. Naming either omission is correct.
