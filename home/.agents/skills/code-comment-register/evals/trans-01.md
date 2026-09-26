---
id: trans-01
type: transformation
status: approved
---

## rule

Put the reason beside the decision.

## input

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

## task

Edit comments only. Preserve behavior, but move each reason beside the exact operation it protects. Return only the revised code.

## reference

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

## rubric

```yaml
violation_fixed: Is the function-top block gone, with each surviving reason placed beside parse_rows, Stream.take, or Stream.run?
placement: Does every comment clearly govern the next operation rather than the whole function?
no_new_violation: No behavior changes, no speculative rationale, and no mechanical narration added.
```

## note

Exact wording may vary. The three reasons and their local placement are the point.
