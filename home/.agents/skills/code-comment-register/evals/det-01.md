---
id: det-01
type: detection
status: approved
---

Review these inline comments with code-comment-register. List every failing comment and the rule it breaks. Do not flag comments that earn their place.

## document

```
# Larger chunks use more memory. Smaller chunks use more CPU.
@chunk_size 192_000

# Parse all records and drop the header before writing.
defp restore(records) do
  records
  |> Stream.drop(1)
  |> Stream.take(@restore_limit)
  |> validate()
end

# Validates the full backup before restoring any records.
defp validate(records), do: Enum.each(records, &validate_record!/1)

defp slice(contents, offset, length) do
  # `binary_part/3` returns a view, so this slice does not copy the source.
  binary_part(contents, offset, length)
end

# Decoder errors include the submitted payload. Submitted data must not reach
# logs or durable task metadata.
defp public_reason({:decode_error, _details}), do: "invalid payload"
```

## violations

```yaml
- quote: Larger chunks use more memory. Smaller chunks use more CPU.
  rule: Generic performance tradeoff without a budget, machine spec, or observed failure.
  reason: It does not explain the chosen chunk size.
- quote: Parse all records and drop the header before writing.
  rule: Mechanical narration without a constraint.
  reason: The pipeline already shows these operations.
- quote: Validates the full backup before restoring any records.
  rule: Claims a broader guarantee than the capped caller enforces.
  reason: Only the prefix passed by restore/1 is validated.
```

## traps

```yaml
- quote: "`binary_part/3` returns a view"
  why_valid: Surprising runtime behavior with a concrete copy-avoidance consequence.
- quote: Decoder errors include the submitted payload
  why_valid: Names a sensitive-data containment requirement.
```
