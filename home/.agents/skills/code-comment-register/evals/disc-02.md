---
id: disc-02
type: discrimination
status: approved
correct: constraint
expected_rule: Keep a comment that names a hidden second role and ties it to an observed failure without pretending the exact value is optimal.
---

Which version follows code-comment-register, and which rule decides it?

## rule

A comment may document a hidden second role without claiming the value is tuned.

## evidence

The final batch-size comment named both a memory-window role and an observed exhaustion failure.

## mechanical

```
# Insert 400 tickets at a time to reduce memory use.
@insert_batch_size 400
```

## constraint

```
# One batch of tickets and results is the most held in memory at once.
# Buffering the whole export exhausted the worker on large datasets.
@insert_batch_size 400
```

## note

The better comment explains why a bounded window exists and what else the constant governs. It does not claim that 400 is specially tuned.
