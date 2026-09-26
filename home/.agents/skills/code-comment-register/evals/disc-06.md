---
id: disc-06
type: discrimination
status: approved
correct: semantic
expected_rule: An orienting what-sentence is allowed only when it names a hidden semantic role and immediately gives the reason.
---

Which version follows code-comment-register, and which rule decides it?

## rule

A short orienting sentence is allowed when it names a semantic role that the syntax cannot show.

## evidence

The final branch comment kept one orienting sentence because the extra row's sentinel role was otherwise hidden.

## mechanical

```
# If the index is greater than the limit, call add_limit_result.
{_row, index}, acc when index > @row_limit -> add_limit_result(acc, index)
```

## semantic

```
# The sentinel row is not written. Its synthetic result preserves the source
# row number so an operator can find the cutoff.
{_row, index}, acc when index > @row_limit -> add_limit_result(acc, index)
```

## note

The mechanical variant restates the guard and function call. The semantic variant explains why the branch exists.
