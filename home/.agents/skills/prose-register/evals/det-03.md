---
id: det-03
type: detection
status: approved
source_commit: 5b4cbde
source_label: YAML frontmatter of the essay, not the prose body -- tests whether a model checks metadata fields, not just paragraphs.
---

List every register violation in this document fragment, quoting the offending text and naming the specific SKILL.md rule it breaks.

## document

```
description: >-
  Same company, same invoice, same artifact — one rewrite by strangers, one
  by a machine. Why the two binaries don't feel the same, and what
  authorship trust is made of.
```

## violations

```yaml
- quote: same artifact — one rewrite by strangers
  anchor: artifact —
  rule: 'No em-dashes. Full stops, semicolons, parentheses, en-dashes. / Lint: "An em-dash."'
  fixed_in: bd0c864 ("en-dashes in descriptions") -- one day after this text shipped, and after the commit range this eval was mined from
```

## traps

```yaml
[]
```

## note

At the pinned commit (5b4cbde), this was a live, shipped miss: the em-dash purge (5e09562) predates this description field, which was added later and never caught at the time. It was subsequently fixed on the source repo's main branch in bd0c864, one day after the handoff doc was written -- do not present this case as 'the em-dash is currently live on alannorton.com', since it no longer is as of this file's writing (2026-07-18). Use it as a template for 'check frontmatter/metadata, not just prose,' not as a live bug report. If reusing this eval later, re-verify against the current HEAD of the source repo before citing it as an open issue. Anchor (2026-09-20): the violation is one character wide and the subject has quoted the text on either side of it (the left side on the second CI run of the fixture pass, which the overlap matcher alone called a miss), so any subject quote containing 'artifact —' counts.
