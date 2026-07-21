# Evals handoff: prose-register (second source)

Date: 2026-07-19
Source repo: /Users/norton/src/alannorton.com (branch `mind-edits`)
Source file: `content/posts/things-ive-changed-my-mind-about.md`
Skill under test: `home/.claude/skills/prose-register/SKILL.md`
Companion doc: `home/.claude/skills/prose-register/evals-handoff.md` (first source, `trust-in-the-age-of-ai.md`) -- read that one first for the case-type definitions (discrimination / transformation / detection) and grading conventions; this doc only covers what's specific to the second source.

This doc is read-only research output for the `disc-09..disc-12` / `trans-06..trans-07` cases in `evals.json`. Nothing in the source repo was changed to produce it.

## Why this essay, and why it's shaped differently

The trust essay's handoff doc mined a long single-file commit history (14 commits) with many small, independent register fixes. This essay instead offers one clean **three-stage arc** across a single working session:

| Stage | Ref | What it is |
|---|---|---|
| Original | `d847318` ("notes and edits") | A partially-polished draft: cleaned prose paragraphs interleaved with raw, unedited dictation-transcript blockquotes (voice-to-text output, never cleaned up) and placeholder headers. |
| Automated | `ef020b0` ("shorten everything") | An automated simplification pass. It correctly strips the leftover dictation-transcript scaffolding (legitimate cleanup, not register-relevant) but also flattens the already-polished prose paragraphs -- cutting concrete detail, connectives, and an entire self-effacing anecdote. |
| Hand-edited | working tree, uncommitted as of 2026-07-19 | The author's manual pass on top of `ef020b0`, restoring some (not all) of what the automated pass flattened, plus a few independent content edits unrelated to register. |

Because stage 2 is a single mechanical "shorten everything" pass rather than many discrete edits, most of its damage shows up as **whole-paragraph compression** rather than sentence-level word swaps -- the eval cases below reflect that (three of six lean on full-paragraph or 3-way-staged comparisons, not single-clause substitutions).

## Before/after/restored triples

Verbatim, re-pulled via `git show <sha>:content/posts/things-ive-changed-my-mind-about.md` and the working tree on 2026-07-19.

### 1. Concrete narrative collapsed to a generic claim (disc-09, trans-06)
- Original (`d847318`): `I doubted that in 2013, when Betterment hired a Ruby enthusiast, let him rewrite the core of the investor experience in Rails, and watched him become CTO a few years later. ... Custody and trading stayed in Java and Scala, and the Ruby services ran reliably for years anyway. Ifs are ifs, logic is logic, and correct is correct no matter what language spells it out.`
- Over-tight (`ef020b0`): `At Betterment, plenty of us were sure Ruby had no business near money, yet big pieces of the investor experience ran on Ruby for years without trouble.`
- Restored (working tree): `Betterment began as a Java shop. ... Yes, we decomposed our Java monolith, bit by bit, into distributed domain services on Rails. The biggest pieces of the investor experience have been running on Ruby for nearly a decade.`
- Note: "restored" is a genuine rewrite, not a reconstruction of "original" -- different concrete details, different rhythm. Both clearly outrank "over_tight." See disc-09's grading_note for why the original-vs-restored ranking is a closer call than it looks.

### 2. A real code example cut for a generic assertion, never restored (disc-10)
- Before (`d847318`): `` You can write `validate :reservation_must_be_for_today_if_city_is_mealpal_now_only` and the code narrates itself. ``
- After (`ef020b0`): `The code read like a sentence, so I decided comments were a failure.`
- This is the one clean case in the whole set (both sources) where the automated pass is simply worse, with no restoration later -- the hand-edit pass never brought this detail back. Good discrimination material precisely because it breaks the "later version is always better" heuristic a grader might otherwise learn.

### 3. Undefined jargon, caught only by the hand-edit (disc-11, trans-07)
- Before (`ef020b0`, unchanged from `d847318`): `Waiting to be noticed is a strategy for being underleveled with great reviews.`
- After (working tree): `Waiting to be noticed is a strategy for staying exactly where you are.`
- "Underleveled" survived the automated pass untouched -- only the manual hand-edit caught it. Fills a coverage gap the first source's history never exercised (see `evals.json`'s `coverage_gaps`).

### 4. Summary-close cut (disc-12)
- Before (`ef020b0`): `Read these back to back and they rhyme: I overvalued the artifact and undervalued the people in the room. Correctness over understanding, the code over the company, sounding smart over making anyone else smarter.`
- After (working tree): that sentence is gone; the closing goes straight from "Changing your mind is the work" to the "next version of me" image.
- The clearest "close without summary" example either source has produced -- the trust essay only yielded an open-with-substance example (disc-08), never a close-without-summary one.

### 5. A clause initially flagged, then resolved on author review
- Before (`ef020b0`): `They used small words and showed up curious.`
- After (working tree): `They focused on expressing ideas accessibly.`
- Initially flagged as a likely regression (more abstract-sounding, dropping the "big words"/"small words" callback two sentences earlier). The author's correction: the register rule was never "no big words" -- it's "no jargon without definition," i.e. don't wall the reader out. Big words used accessibly are fine. "Focused on expressing ideas accessibly" names the actual mechanism (accessibility) rather than a proxy for it (word length), which is arguably more precise, not weaker. `SKILL.md`'s "No jargon without definition" prohibition now says this explicitly. Not promoted to a discrimination case regardless -- there's no clean single right answer to rank once "word-size is the metric" is off the table, so this doesn't produce a gradable pair the way the other cases do.
- The other half of that sentence -- `not like they built it with you` -> `without being committed co-owners in the solution` -- is a separate clause and wasn't part of the author's clarification. It reads as the weaker of the two changes (more corporate-abstract, less immediately concrete) but is left alone here; not confident enough to mine either direction.

## Coverage gaps this source fills or narrows

- **No jargon without definition**: filled by disc-11/trans-07 (see above). Still open: a from-scratch example of jargon *defined in place* rather than cut -- this source only shows the cut resolution.
- **Close without summary**: narrowed by disc-12 -- the trust essay only had the opening-move half of this rule (disc-08), never the closing half.
- **Concrete nouns over abstractions**: two more instances (disc-09, disc-10), one of which (disc-10) is a case where the "later" version is the violation, not the fix -- useful for a discrimination set that might otherwise skew toward "after is always right."

## Gaps this source does not fill

Everything else in the first handoff doc's coverage-gaps list is still open: **No flex**, **Never claim the reader's reaction**, **Nothing floral**, **Keep the "I"**, **Lint: five consecutive sentences of similar length/pressure**, **Lint: a decorative bad triplet**, **a hedge that protects the writer** / **a reversal used for cleverness**. This essay is first-person and undramatic throughout (like the trust essay), so none of these got exercised here either.

## Caveats

**Draft-only material used in SKILL.md.** The line added to SKILL.md's "Where the breath comes from" section (`I'm sure about this because I've been the villain of it.`) comes from a paragraph that existed in `d847318` and was cut entirely by the `ef020b0` automated pass -- it is not live on alannorton.com and was not restored by the hand-edit pass either. Same status as the trust essay's "Workshop and the Job" section per that doc's Caveats: real, author-approved draft prose, fine to quote in the author's own dotfiles, but not what a reader of the published site would currently see. Worth a note to the author that this paragraph (the whole MealPal/AngularJS anecdote in the "appearing smart" section) reads as a strong candidate for restoring to the actual essay, independent of its use here as a skill example.

**"Yes," as a connective.** Added to SKILL.md's connectives list from disc-09/trans-06's restored text (`Yes, we decomposed our Java monolith...`). It's a different flavor from the three connectives already listed there (all of which pivot into a question or a consequence) -- this one affirms/concedes a point before continuing. Worth watching in future mining passes to see if it holds up as a recurring move or was a one-off.

**Uncommitted source material.** The "hand-edited" stage is the working tree as of 2026-07-19, not a commit -- if the author commits, amends, or further edits this file, the exact SHA-addressable state used here will no longer be reachable by `git show`. The quoted text itself won't change, but anyone re-verifying this doc later should diff against the eventual commit rather than assuming the working tree is still in this state.
