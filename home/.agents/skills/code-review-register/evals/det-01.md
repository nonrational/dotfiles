---
id: det-01
type: detection
status: draft
---

Review this draft code review with code-review-register. List every comment that breaks the register and the rule it breaks. Do not flag comments that follow it.

## document

[limiter.ts:12] Why is the bucket size 50?

[limiter.ts:27] nit: `refill` would read better as `refillTokens`, since it also updates `lastRefillAt`. Not blocking.

[limiter.ts:41] Blocking: the refill math uses `Date.now()` in seconds here but `lastRefillAt` is stored in milliseconds, so every bucket refills to full on the second request. Divide both by 1000 or store seconds.

[limiter.ts:58] This retry path is orthogonal to the limiter and a bit of a footgun.

[limiter.test.ts:9] nit: move the fixture to `beforeEach`.

[limiter.ts:63] Requesting changes for the refill math only; the nits are your call. Ha, the token-bucket rewrite is tidy.

## violations

```yaml
- quote: Why is the bucket size 50?
  rule: Bare question with no reason attached.
  reason: It gives the author nothing to answer beyond the number.
- quote: This retry path is orthogonal to the limiter and a bit of a footgun.
  rule: Unexplained shorthand, and critique with no path to resolution.
  reason: Neither term is unpacked and no fix is offered.
- quote: "nit: move the fixture to `beforeEach`."
  rule: Nit without a reason or a blocking signal.
  reason: Only the label is present.
```

## traps

```yaml
- quote: "`refill` would read better as `refillTokens`, since it also updates `lastRefillAt`. Not blocking."
  why_valid: "Three-part nit: label, one clause of reasoning, non-blocking signal."
- quote: the refill math uses `Date.now()` in seconds here but `lastRefillAt` is stored in milliseconds
  why_valid: A correctness bug stated plainly, marked blocking, with a fix.
- quote: Requesting changes for the refill math only; the nits are your call.
  why_valid: Verdict first, matching the one blocking comment; the nits are left to the author and the praise follows the ask.
```
