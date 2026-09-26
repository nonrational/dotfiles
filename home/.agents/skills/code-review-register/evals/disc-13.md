---
id: disc-13
type: discrimination
status: draft
correct: warm_no_joke
expected_rule: "On a blocking security issue the humor is dialed down: stay warm but drop the jokes."
accepted_rules:
  - Dial down for blocking bugs and security issues.
---

Which draft follows code-review-register, and which rule decides it?

## rule

Dial down, but don't go cold, for blocking bugs, security issues, or a contributor's first PR. Stay warm; just drop the jokes.

## warm_no_joke

Blocking: `resetToken` is compared with `==`, so a request that sends `true` matches any stored token and resets any account. Worth a constant-time string compare, and thanks for wiring the reset flow end to end; the rest of it reads well.

## joking

Blocking, and ha, this one's a doozy: `resetToken` is compared with `==`, so a request that sends `true` matches any stored token and resets any account. The token check is doing its best impression of a welcome mat. Worth a constant-time string compare.

## note

Both drafts mark the bug blocking and offer the same fix. The joking draft keeps the humor on a security hole; the warm draft keeps the warmth and drops the joke.
