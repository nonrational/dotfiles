---
id: det-01
type: detection
status: approved
min_recall: 0.5
---

Find every failing comment.

## document

````
[a.ts:1] Why is this 50?

[a.ts:9] The filename drops the extension.
```suggestion
const name = `${base}.csv`;
```
````

## violations

- quote: Why is this 50?
  rule: Bare question.
  reason: No reason attached.
  anchor: this 50

## traps

- quote: The filename drops the extension.
  why_valid: A fix offered as a suggestion block.
