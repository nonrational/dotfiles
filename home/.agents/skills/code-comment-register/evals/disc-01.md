---
id: disc-01
type: discrimination
status: approved
correct: no_comment
expected_rule: No comment is a valid result; delete generic tradeoffs that do not explain the chosen value.
---

Which version follows code-comment-register, and which rule decides it?

## rule

No comment is a valid result. Do not invent a rationale because a value or branch looks as though it ought to have one.

## evidence

The final edit removed an unsupported chunk-size explanation.

## generic_comment

```
# Larger chunks use more memory. Smaller chunks use more CPU.
@chunk_size 192_000
```

## no_comment

@chunk_size 192_000

## note

The generic statement is true of nearly every chunk size and supplies no budget, machine spec, or observed failure. Do not reward it merely for sounding technical.
