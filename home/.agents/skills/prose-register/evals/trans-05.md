---
id: trans-05
type: transformation
status: approved
source_commits:
  - e55f75c (before, unchanged since the first draft 5edc968)
  - "069e841 (first attempt: 'a human character was there to care')"
  - "c26cd1a (grammar fix: 'a human with character was there to care')"
---

## input

It means proving to your users that while the machine provided the Competence, a human being was there to provide the Character and the Caring.

## task

The back half nominalizes twice ('provide the Character', 'provide the Caring'). Collapse it into a verb, per 'concrete nouns over abstractions, strong verbs over adverbs.'

## reference

It means proving to your users that while the machine provided the competence, a human with character was there to care.

## rubric

```yaml
violation_fixed: Does 'provide the Character and the Caring' become a verb ('to care') instead of two more nominalizations?
no_new_violation: "Watch specifically for the bug the author's own first attempt introduced: 069e841 wrote 'a human character was there to care', which misreads as 'a human named Character' -- a real ambiguity, fixed one commit later in c26cd1a to 'a human with character'. A model that reproduces the ambiguous phrasing should not get full marks on voice_match even though it technically collapsed the nominalization."
voice_match: Subjective.
```

## note

This is a genuine two-step fix in the source history -- useful for testing whether a model's first-pass rewrite reproduces the same grammatical trap the author fell into, or avoids it in one pass.
