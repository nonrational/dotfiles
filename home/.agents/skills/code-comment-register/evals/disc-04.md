---
id: disc-04
type: discrimination
status: approved
correct: beside_branch
expected_rule: A branch-specific reason belongs beside that branch, not above the whole function.
---

Which version follows code-comment-register, and which rule decides it?

## rule

Sits above a whole function when it explains one pipe stage or branch.

## evidence

A truncation explanation moved from a caller's header to the guarded clause that creates the result.

## distant

```
# The extra record is not written. Its synthetic result preserves the source
# row number so an operator can find the cutoff.
defp import(records) do
  Enum.reduce(records, new_summary(), fn
    {_record, index}, acc when index > @row_limit -> add_limit_result(acc, index)
    {record, _index}, acc -> write_record(acc, record)
  end)
end
```

## beside_branch

```
defp import(records) do
  Enum.reduce(records, new_summary(), fn
    # The sentinel record is not written. Its synthetic result preserves the
    # source row number so an operator can find the cutoff.
    {_record, index}, acc when index > @row_limit -> add_limit_result(acc, index)
    {record, _index}, acc -> write_record(acc, record)
  end)
end
```

## note

The short orienting sentence is allowed because 'sentinel record' names a semantic role that the guard syntax cannot show.
