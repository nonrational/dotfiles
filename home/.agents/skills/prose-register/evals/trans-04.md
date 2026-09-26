---
id: trans-04
type: transformation
status: approved
source_commits:
  - e55f75c (before)
  - 069e841 (after)
---

## input

We know how to trust care that hurt to give. We do not yet know how to trust care that came off an invoice.

## task

Both clauses lean on an abstract framing ('care that hurt to give' / 'care that came off an invoice'). Tighten them into a cleaner parallel pair of concrete nouns, per 'concrete nouns over abstractions, strong verbs over adverbs.'

## reference

We know how to trust care as a sacrifice. We do not yet know how to trust care as a line item.

## rubric

```yaml
violation_fixed: Does the rewrite land on a genuinely parallel noun pair (like 'sacrifice' / 'line item') rather than just trimming words?
no_new_violation: No em-dash; the parallel structure shouldn't become a decorative triplet or add a third clause not present in the source.
voice_match: Subjective -- 'sacrifice' and 'line item' both read as workplace-adjacent nouns a reader immediately pictures; a rewrite that reaches for something more poetic ('a gift' / 'a transaction') is defensible and should be judged on whether it's equally concrete, not marked wrong for differing from the reference.
```
