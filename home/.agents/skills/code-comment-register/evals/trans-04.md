---
id: trans-04
type: transformation
status: approved
---

## rule

Split comments by the code they explain.

## input

```
# An 11x parser footprint exhausted the worker. The fixture is allocated before
# the baseline. Runtime-wide sampling may include unrelated allocations, and
# the threshold is three times the expected peak.
test "keeps parser overhead below the input-size budget" do
  payload = large_input()
  {result, peak} = measure_peak(fn -> parse(payload) end)
  assert result == :ok
  assert peak < byte_size(payload) / 3
end
```

## task

Edit comments only. Keep the known regression at test scope, but move assertion-specific accounting and measurement caveats beside the assertion. Return only the revised code.

## reference

```
# An 11x parser footprint exhausted the worker on large inputs.
test "keeps parser overhead below the input-size budget" do
  payload = large_input()
  {result, peak} = measure_peak(fn -> parse(payload) end)
  assert result == :ok

  # `payload` was allocated before the baseline, so `peak` is parser overhead only.
  # Runtime-wide sampling may include unrelated allocations.
  assert peak < byte_size(payload) / 3
end
```

## rubric

```yaml
violation_fixed: Is the known regression kept above the test while baseline and sampling caveats move beside the peak assertion?
placement: Do the comments now match test scope versus assertion scope?
no_new_violation: No test behavior changes and no useful caveat is lost.
```

## note

The exact margin sentence may be retained beside the assertion if it stays concise.
