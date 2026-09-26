---
id: disc-03
type: discrimination
status: approved
correct: local_comments
expected_rule: Put each reason beside the pipe stage it protects instead of stacking a mapping exercise above the function.
---

Which version follows code-comment-register, and which rule decides it?

## rule

Put the reason beside the decision.

## evidence

A dense function-top block was split across the parser stages it governed.

## function_block

```
# Parse failures must happen before writes. Validation and the write path must
# share line handling. The first row over the cap is needed to report truncation.
defp validate(rows) do
  rows
  |> line_stream()
  |> parse_rows()
  |> Stream.drop(1)
  |> Stream.take(@row_limit + 1)
  |> Stream.run()
end
```

## local_comments

```
defp validate(rows) do
  rows
  |> line_stream()
  # Validation and the write path must share line handling. Otherwise validation
  # can pass and writing can fail after inserts begin.
  |> parse_rows()
  |> Stream.drop(1)
  # The first row over the cap is required to report truncation, and it must
  # validate before any writes.
  |> Stream.take(@row_limit + 1)
  # Force the lazy parser before writes. A malformed row must not arrive after
  # the first batch commits.
  |> Stream.run()
end
```

## note

Both variants contain similar facts. Placement is the deciding distinction.
