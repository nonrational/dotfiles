---
id: disc-01
type: discrimination
status: approved
correct: with_reason
expected_rule: Explain why, not what.
accepted_rules:
  - Put the reason beside the decision.
arguable: false
source_commit: abc1234
---

Which version follows the register?

## rule

Explain why, not what.

## evidence

The author deleted the generic comment.

## with_reason

```
# Retry once: the upstream drops the first connection after idle.
retry(1)
```

## bare

Fix the flaky call.

```suggestion
retry(1)
```

## note

Only the reason differs.
