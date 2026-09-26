---
id: disc-10
type: discrimination
status: draft
correct: code_target
expected_rule: A joke targets the code or the situation, never the author's judgment or competence.
---

Which draft follows code-review-register, and which rule decides it?

## rule

Boundary, not the whole point: target the code, the tool, or the situation — never the author's judgment or competence.

## author_target

Ha, did you even run this? It fires every notification at midnight UTC regardless of the user's timezone. Worth converting with `user.tz` before enqueueing.

## code_target

Ha, the scheduler is a night owl: it fires every notification at midnight UTC regardless of the user's timezone. Worth converting with `user.tz` before enqueueing.

## note

Both drafts are playful and both carry the same fix. Only the target of the joke differs.
