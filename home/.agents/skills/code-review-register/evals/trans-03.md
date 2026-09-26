---
id: trans-03
type: transformation
status: draft
---

## rule

Approval plus a comment labeled "blocking" is a contradiction — never produce it. Corollary: don't approve if something genuinely must change first. Request changes (or leave it un-approved) and mark that comment blocking.

## input

Approving. Two notes:

1. Blocking: `applyCoupon` reads the discount before checking `expiresAt`, so an expired coupon still applies on the first request after expiry.

2. nit: `couponCode` could be `code` inside `applyCoupon`, since the receiver is already the coupon. Not blocking.

## task

Edit this draft review summary according to code-review-register. The expiry bug is real and must be fixed before merge. Keep both comments. Return only the revised summary.

## reference

Requesting changes for one thing; the nit is your call.

1. Blocking: `applyCoupon` reads the discount before checking `expiresAt`, so an expired coupon still applies on the first request after expiry. Check expiry first.

2. nit: `couponCode` could be `code` inside `applyCoupon`, since the receiver is already the coupon. Not blocking.

## rubric

```yaml
violation_fixed: "Does the summary no longer approve while carrying a blocking comment: it requests changes or withholds approval, and the expiry comment stays marked blocking?"
placement: Is the verdict stated in the first sentence, before the numbered comments?
no_new_violation: Are both comments kept, the nit still non-blocking with its reason, and no new facts invented?
```

## note

Downgrading the bug to non-blocking so the approval can stand also fails: the task says it must be fixed before merge.
