---
id: disc-05
type: discrimination
status: approved
correct: bounded
expected_rule: Match the scope of the claim to the bounded behavior the code actually enforces.
---

Which version follows code-comment-register, and which rule decides it?

## rule

Do not describe a bounded guarantee as a universal one.

## evidence

A full-validation claim was narrowed to the rows the capped operation could read.

## overclaim

```
# Validates the full archive before restoring any entries.
entries |> Stream.take(@restore_limit) |> validate()
```

## bounded

```
# Validates every entry the capped restore can consume before writing.
entries |> Stream.take(@restore_limit) |> validate()
```

## note

The code cannot validate entries after the cap. Calling this a full-archive guarantee is false.
