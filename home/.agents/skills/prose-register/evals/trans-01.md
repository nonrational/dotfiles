---
id: trans-01
type: transformation
status: approved
source_commit: 5aae06b
---

## input

Recently, the creator of Bun burned through roughly $200,000 worth of tokens to rewrite their core runtime from Zig into Rust. The migration was completed in mere weeks, with 99% of the commits authored by a pre-release AI model.

## task

The real figures are: $165,000 in tokens, 11 days, and a pre-release version of Claude Fable 5 authoring nearly all of 6,778 commits. Rewrite the passage to use exact, sourced figures instead of vague ones, per the 'hedges of precision stay, hedges of cowardice go' rule.

## reference

Recently, the creator of Bun burned through roughly $165,000 in tokens to rewrite their core runtime from Zig into Rust. The migration was completed in just 11 days, with a pre-release version of Claude Fable 5 authoring nearly all of the 6,778 commits.

## rubric

```yaml
violation_fixed: Does the rewrite replace 'roughly $200,000' / 'mere weeks' / '99% of the commits' with the exact figures given?
no_new_violation: "Check against Lint: no em-dash introduced, no flattery/grandiosity added. See grading_note on 'just'."
voice_match: Subjective -- does the rewrite keep the plain, direct register of the passage, or does it get clinical/listy trying to cram in three numbers?
```

## note

The reference answer itself contains a residual 'just' ('in just 11 days') that SKILL.md's own prohibition bans -- it isn't purged until a much later commit (c26cd1a). Don't penalize a model's rewrite for matching that flaw; give it extra credit if it lands exact figures without introducing 'just' at all, since that's a strictly better answer than the reference.
