---
id: disc-06
type: discrimination
status: draft
correct: suggestion_block
expected_rule: A one-line fix is offered as a suggestion block, not as prose asking for the change.
---

Which draft follows code-review-register, and which rule decides it?

## rule

````
When the fix is a small, concrete code change (roughly one to a few lines), propose it as a GitHub ```suggestion``` block, not prose describing the change.
````

## prose_fix

The timeout here is in seconds but `setTimeout` takes milliseconds, so this fires after 30 ms instead of 30 s. Could you multiply by 1000 when passing it in?

## suggestion_block

````
This fires after 30 ms: `setTimeout` takes milliseconds and `timeout` is in seconds.
```suggestion
  setTimeout(abort, timeout * 1000);
```
````

## note

Both drafts find the same bug. Only the form of the proposed fix differs.
