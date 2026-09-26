---
id: disc-09
type: discrimination
status: approved
correct: runtime_note
expected_rule: Keep a concise note about surprising platform behavior when it explains the memory consequence.
---

Which version follows code-comment-register, and which rule decides it?

## rule

Anything that would genuinely surprise a reader who knows the language and library.

## evidence

A runtime note survived because slicing returns a view rather than copying bytes.

## no_comment

{binary_part(contents, offset, length), offset + length}

## runtime_note

```
# `binary_part/3` returns a view, so this slice does not copy the source.
{binary_part(contents, offset, length), offset + length}
```

## note

This case prevents the evaluator from learning that deletion is always preferred.
