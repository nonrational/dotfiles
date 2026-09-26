---
id: trans-01
type: transformation
status: draft
---

## rule

Attach the reason you're asking or the answer that would resolve it. Never post a bare question.

## input

Why is the cache TTL 90 seconds here?

## task

Edit this draft comment according to code-review-register. Facts available to the reviewer: every other endpoint in the service uses a 300 second TTL, and the reviewer wants to know whether 90 is deliberate for this endpoint or a leftover from testing. Return only the revised comment.

## reference

Why is the cache TTL 90 seconds here? The rest of the service uses 300, so I want to know whether this endpoint needs the shorter window or it's a leftover from testing.

## rubric

```yaml
violation_fixed: Does the question now carry the reason it is asked, or the answer that would resolve it?
facts_kept: Does the reason use only the facts given (300 elsewhere; deliberate versus leftover) and invent nothing else?
no_new_violation: Is it still a question rather than a demand, with no unexplained shorthand and no bare why?
```

## note

Any wording that attaches the given reason passes. A rewrite that asserts the value is wrong, or supplies a reason the task did not give, fails.
