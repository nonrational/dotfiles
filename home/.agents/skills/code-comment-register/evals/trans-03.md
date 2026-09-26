---
id: trans-03
type: transformation
status: approved
---

## rule

Do not describe a bounded guarantee as a universal one.

## input

```
# Validates the full archive before restoring any entries.
entries |> Stream.take(@restore_limit) |> validate()
```

## task

Rewrite the comment so it states the strongest guarantee the code actually provides. Return only the revised code.

## reference

```
# Validates every entry the capped restore can consume before writing.
entries |> Stream.take(@restore_limit) |> validate()
```

## rubric

```yaml
violation_fixed: Does the comment stop claiming that entries beyond the cap are validated?
placement: The comment may remain above the expression because one invariant governs the whole expression.
no_new_violation: No new mechanics or unsupported behavior are added.
```

## note

Accept equivalent wording such as 'validates the capped prefix before restoring it'.
