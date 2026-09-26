---
id: det-02
type: detection
status: approved
---

Review these test comments with code-comment-register. List every failing comment and the rule it breaks. Do not flag comments that explain a fixture, known failure, or measurement caveat.

## document

```
# The streaming parser must match the string parser.
test "streaming parser matches string parser" do
  assert via_stream(input()) == via_string(input())
end

# This creates a long padding row and then parses it.
test "a quoted field crossing the boundary remains one row" do
  boundary = 64_000
  # Put the opening quote 7 bytes before the boundary so the record crosses it.
  padded = fixture_with_quote_at(boundary - 7)
  assert parse(padded) == expected_rows()
end

# A 9x parser footprint exhausted the worker on large inputs.
test "keeps parser overhead below the input-size budget" do
  payload = large_input()
  {result, peak} = measure_peak(fn -> parse(payload) end)
  assert result == :ok

  # `payload` was allocated before the baseline, so `peak` is parser overhead only.
  # Runtime-wide sampling may include unrelated allocations.
  assert peak < byte_size(payload) / 3
end
```

## violations

```yaml
- quote: The streaming parser must match the string parser.
  rule: Repeats the test name.
  reason: It does not explain why this case exists.
- quote: This creates a long padding row and then parses it.
  rule: Narrates obvious test setup.
  reason: The fixture call and assertion already show that.
```

## traps

```yaml
- quote: Put the opening quote 7 bytes before the boundary
  why_valid: Explains why this fixture, rather than a nearby one, exercises the boundary.
- quote: A 9x parser footprint exhausted the worker
  why_valid: Names the known failure the test guards against.
- quote: "`payload` was allocated before the baseline"
  why_valid: Explains measurement accounting beside the assertion.
```
