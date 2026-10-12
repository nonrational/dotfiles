---
id: trans-02
type: transformation
status: approved
---

## rule

No comment is a valid result.

## input

```
# Larger chunks use more memory. Smaller chunks use more CPU.
@chunk_size 192_000
```

## task

Edit the comment according to code-comment-register. There is no budget, machine spec, benchmark, or observed failure available. Return only the revised code.

## reference

@chunk_size 192_000

## rubric

```yaml
violation_fixed: Is the unsupported comment deleted rather than polished?
placement: Not applicable; the correct result has no comment.
no_new_violation: The value and code remain unchanged, and no invented evidence is introduced.
```

## note

A rewrite that supplies a plausible-sounding reason fails. The task explicitly says no evidence is available.
