---
id: det-02
type: detection
status: draft
---

Review this draft code review with code-review-register. List every comment that breaks the register and the rule it breaks. Do not flag comments that follow it.

## document

````
[export.ts:8] Should this read `settings.locale` instead of `user.locale`? The importer writes `settings.locale`, so I want to know which one the export is meant to reflect when the two differ.

[export.ts:19] Blocking: `buildRows` should be named `toCsvRows` to match the importer.

[export.ts:33] Ha, the date column has a mind of its own: it's ISO in the header row and locale-formatted below it. Worth picking one before the importer meets it.

[export.ts:47] Did you even test this? The byte-order mark is written after the header line instead of before it.

[export.ts:52] This will not scale past a few thousand rows.

[export.ts:60] The filename drops the extension when `name` contains a dot, so this one is blocking. One-line fix:
```suggestion
const filename = `${name}.csv`;
```
````

## violations

```yaml
- quote: "Blocking: `buildRows` should be named `toCsvRows` to match the importer."
  rule: A naming preference marked blocking; style defaults to non-blocking.
  reason: A rename does not change what the code does.
- quote: Did you even test this? The byte-order mark is written after the header line
  anchor: Did you even test this?
  rule: The joke targets the author's competence, not the code.
  reason: The finding is real; the opening line is aimed at the author.
- quote: This will not scale past a few thousand rows.
  rule: Pure critique with no reason and no path to resolution.
  reason: It names neither the cause nor a fix.
```

## traps

```yaml
- quote: Should this read `settings.locale` instead of `user.locale`? The importer writes `settings.locale`, so I want to know which one the export is meant to reflect
  why_valid: A question with its reason attached.
- quote: the date column has a mind of its own
  why_valid: A joke aimed at the code, followed by a path to resolution.
- quote: The filename drops the extension when `name` contains a dot, so this one is blocking.
  why_valid: A one-line fix offered as a suggestion block with one clause of why and an explicit blocking signal.
```
