---
id: disc-07
type: discrimination
status: draft
correct: unpacked
expected_rule: Shorthand and metaphor are unpacked in the same sentence with a clause of plain-language context.
accepted_rules:
  - Don't assume shared vocabulary; optimize for fast reading.
---

Which draft follows code-review-register, and which rule decides it?

## rule

Don't use dense metaphor or shorthand ("load bearing", "footgun", "orthogonal") without unpacking it in the same sentence.

## unpacked

`retainDays=0` defaulting to forever is a footgun: someone will set 0 expecting "delete now". And every downstream read depends on the cache key, so I'd split the two changes to keep the key change revertible on its own.

## dense

`retainDays=0` defaulting to forever is a footgun, and the cache key is load bearing here, so I'd split the two changes.

## note

The dense draft leaves both terms unexplained. The unpacked draft keeps 'footgun' and explains it in the same sentence, and replaces 'load bearing' with the plain dependency it stood for.
