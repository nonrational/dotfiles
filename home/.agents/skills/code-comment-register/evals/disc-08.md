---
id: disc-08
type: discrimination
status: approved
correct: split
expected_rule: Put the known regression above the test and the measurement caveat beside the assertion it qualifies.
---

Which version follows code-comment-register, and which rule decides it?

## rule

Split comments by the code they explain.

## evidence

The final test kept the known failure above the test and moved measurement caveats beside the assertion.

## single_block

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

## split

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

## note

The facts are not redundant: they govern different scopes and should be placed accordingly.
