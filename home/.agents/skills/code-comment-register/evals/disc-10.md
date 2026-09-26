---
id: disc-10
type: discrimination
status: approved
correct: constraint
expected_rule: Keep a comment that names the sensitive-data containment requirement and the surprising source of the data.
---

Which version follows code-comment-register, and which rule decides it?

## rule

An external requirement.

## evidence

A sensitive-data comment survived because a parser error contained the submitted payload and could reach logs or durable metadata.

## mechanical

```
# Ignore the detailed message and return a generic reason.
{:error, {:malformed_input, _message}} -> cancel(job, "malformed input")
```

## constraint

```
# Parser errors include the submitted row. Customer data must not reach logs
# or durable job metadata.
{:error, {:malformed_input, _message}} -> cancel(job, "malformed input")
```

## note

The mechanical version says what the pattern does. The constraint version says why the detail must be discarded.
