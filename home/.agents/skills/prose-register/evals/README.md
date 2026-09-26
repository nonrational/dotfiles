---
skill: prose-register
min_pass_rate: 0.4
---

# prose-register evals

## Description

Discrimination, transformation, and detection eval cases for the prose-register skill, mined from the real revision history of the essay that produced several of SKILL.md's own verbatim examples.

## Provenance

- **sources:**
  - **handoff_doc:** home/.claude/skills/prose-register/evals-handoff.md
    - **source_repo:** ~/src/alannorton.com
    - **source_file:** content/posts/trust-in-the-age-of-ai.md
    - **commit_range_mined:** 5edc968..5b4cbde
    - **cases:** disc-01..disc-08, trans-01..trans-05, det-01..det-03
    - **verification:** All quoted text was re-pulled directly from `git show <sha>:content/posts/trust-in-the-age-of-ai.md` in the source repo on 2026-07-18, not copied from the handoff doc's paraphrases alone. Two exceptions, both hand edits (see each case's grading_note): disc-01's 'after' variant had the modifier 'just' removed on 2026-09-19, and disc-04's two variants were each prefixed on 2026-09-20 with the paragraph that precedes the sentence in c8fa24c, so the connective has something to join. Detection-case violation lists (det-01, det-02) were hand-built against SKILL.md by reading the full draft text end to end, per the handoff doc's own caution not to infer them only from the diff.
    - **excluded_material:** None of the text comes from the 'Workshop and the Job' section (added in f08e2fe, cut in 069e841) -- that section was drafted but never shipped, so it is excluded from these fixtures. See the handoff doc's Caveats section if you want to add it back deliberately.
  - **handoff_doc:** home/.claude/skills/prose-register/evals-handoff-changed-my-mind.md
    - **source_repo:** ~/src/alannorton.com
    - **source_file:** content/posts/things-ive-changed-my-mind-about.md
    - **commit_range_mined:** d847318 (polished draft, still carrying raw dictation-transcript blockquotes) -> ef020b0 ("shorten everything", automated simplification) -> working tree (author's manual hand-edit on top of ef020b0, uncommitted as of 2026-07-19)
    - **cases:** disc-09..disc-12, trans-06..trans-07
    - **verification:** All quoted text was re-pulled directly from `git show <sha>:content/posts/things-ive-changed-my-mind-about.md` (or the working tree, for the uncommitted hand-edit stage) in the source repo on 2026-07-19. Three departures since, all on 2026-09-20 and each recorded in its case's grading_note: disc-11's 'after' keeps 'as you assume' from 'before' and disc-12's 'after' drops 'These are hard won lessons, and', so each pair differs in one place; disc-09 was cut from a three-stage rank to the original-versus-over_tight pair, and its 'restored' stage survives as trans-06's reference. trans-06's task now states the facts the reference uses, in other words than the reference's, because the subject cannot know them: on the five CI runs to 2026-09-20 the judge rejected two rewrites for naming no mechanism and one for inventing one. Transformation notes reach the judge, so this history lives here rather than in the case.
    - **note:** Three stages, not two. ef020b0's automated pass conflates legitimate cleanup (stripping leftover dictation-transcript scaffolding) with genuine over-tightening of the already-polished paragraphs -- only the latter is register-relevant and mined here. The working-tree hand-edit restores some, not all, of what the automated pass flattened; disc-10 documents a concrete detail neither pass restored. One hand-edit was deliberately excluded from these fixtures rather than mined as a positive example -- see the top-level `notes` field below.
  - **source_repo:** ~/src/alannorton.com
    - **source_file:** content/posts/mature-poets-steal.md
    - **commit_range_mined:** f3ca29e (author's first edit pass on a drafted essay) -> cf18538 (the revision the author kept)
    - **cases:** disc-13..disc-14
    - **verification:** Quoted text was re-pulled with `git show <sha>:content/posts/mature-poets-steal.md` on 2026-09-25. Both pairs are hand edits built to differ in one place, each recorded in its case's grading_note: disc-13's 'before' sets f3ca29e's floral clause into cf18538's sentence, and disc-14's 'before' drops a repeated 'immediately' from f3ca29e's sentence and both of its variants reduce a markdown link to its text and redact a first name as [name].
    - **note:** No handoff doc: mined in the editing session that produced the edits, to fill two coverage gaps. The essay was unpublished when mined.

## Case types

- **discrimination:** Given 2+ register variants of the same passage, pick the on-register one (or rank them) and name the SKILL.md rule that decides it. Grade: exact-match on the chosen/ranked variant, plus a check that the cited rule text actually appears in SKILL.md and is the correct one for the distinction being drawn -- not just any rule that happens to be true of the passage.
- **discrimination-rank:** Same as discrimination, but 3 variants ranked instead of a 2-way pick. Can be decomposed into 3 pairwise comparisons if a runner prefers binary grading.
- **discrimination-structural:** Same as discrimination, but the distinction is structural (an opening or closing move) rather than sentence-level. Grade more loosely -- see each case's grading_note.
- **transformation:** Given a before-passage, produce an on-register rewrite. Grade with a 3-item rubric against the reference after-text: (1) is the specific violation fixed, (2) does the rewrite avoid introducing a new Lint violation, (3) does it read like the author's voice (subjective -- human or LLM-judge spot check, not exact-match).
- **detection:** Given a full passage or document, list register violations with the specific SKILL.md rule each breaks. Grade on recall/precision against the case's hand-built violation list; a case whose list is not exhaustive sets min_recall below 1 and records recall as its score instead of failing on it. Each detection case also lists deliberate 'traps' -- lines that look like violations but are explicitly sanctioned by SKILL.md -- to catch over-flagging, not just under-flagging.

## Coverage gaps

- **No flex ("Never a sentence that flatters the writer")** No example in this essay's history of a flex line being cut. Filled 2026-09-25 by disc-14, mined from mature-poets-steal.md: thanks reported rather than given.
- **Never claim the reader's reaction ("this is why you can trust me")** The essay is consistently careful never to do this from the first draft on -- no edit-pair shows a violation getting caught and fixed.
- **Nothing floral ("The people who lit my path" is a costume)** No floral-language example anywhere in this history. Filled 2026-09-25 by disc-13, mined from mature-poets-steal.md's 'lantern blueprint' cut.
- **Keep the "I" (agentless prose fixed to first person)** The essay is first-person throughout from the first draft, so there is no agentless-prose-fixed-to-"I" pair here. The SKILL.md example for this rule may come from a different Alan Norton essay (the /ai page or manifesto referenced in the commit log) -- check there for a real pair before building this case.
- **No jargon without definition** Weak in the trust essay -- only the 'principals' hyperlink gloss (e55f75c), which defines via link rather than in-text. Filled 2026-07-19 by disc-11/trans-07, mined from things-ive-changed-my-mind-about.md's 'underleveled' cut. That case resolves by cutting the term rather than defining it in place, so a from-scratch 'define the jargon inline' example is still open.
- **Lint: "Five consecutive sentences of similar length or similar pressure"** The essay's paragraphs are short enough that the exact 5-sentence threshold is never hit; det-02's 3-sentence runs are the closest analog, at smaller scale.
- **Lint: "A triplet whose third item adds nothing the first two didn't"** The essay only shows the good triplet (disc-05); no essay-sourced bad triplet exists (SKILL.md's own contrast example, 'remix, retool, reimagine', is not drawn from this essay -- it would need to be authored synthetically for a negative example).
- **"A hedge that protects the writer rather than the fact" / "A reversal used for cleverness rather than argument"** No bad examples survive in this history -- only good ones (hedges of precision, argument-driven reversals) made it to the shipped text, which makes sense for a piece mined after it shipped. Negative examples for these two would need to be authored synthetically or mined from a rougher draft of a different essay.
- **Don't shrink the work** Added to SKILL.md 2026-09-25 with no case. 'Have your own by lunch' was dropped from mature-poets-steal.md rather than rewritten, so it has no after-text. The closest real pair is that essay's 0a4fcb6 -> cf18538 sentence after 'Nothing in it is wrong.' ('on the morning it breaks you are reading a stranger's shell script by flashlight' -> 'It's someone else's philosophy: having learned it, you must obey it or fight it.'), a taste call that should start arguable if built.
- **Where the breath comes from: a verb borrowed from the section's governing image** Added to SKILL.md 2026-09-25 with no case. One real pair exists (mature-poets-steal.md 0a4fcb6 'took the shape, and wrote my own' -> f3ca29e 'conjured my own'), but both lines are on-register, the kind of taste split disc-04 and disc-11 show the subject does not settle; not built.

## Notes

No eval convention existed in this repo before this file. Format choice (structured JSON over a narrative markdown rubric) was made 2026-07-18 so cases are machine-gradable by a future runner script or fed directly into an LLM-judge prompt; grading logic itself is not implemented here, only the cases and rubrics. A second source was mined 2026-07-19 from content/posts/things-ive-changed-my-mind-about.md (see provenance.sources) -- a genuine three-stage revision arc (polished draft -> automated 'shorten everything' pass -> manual hand-edit) rather than the trust essay's long single-commit history. One hand-edit from that pass was initially flagged rather than mined: the 'appearing smart' section's closing paragraph replaces 'They used small words and showed up curious' with 'They focused on expressing ideas accessibly.' On review with the author (2026-07-19) this was a misapplication of the register, not a real violation -- the rule was never 'no big words', it's 'no jargon without definition' / don't wall the reader out; SKILL.md's Prohibitions section now says so explicitly ('Big words are fine when they're accessible'). 'Focused on expressing ideas accessibly' names the actual mechanism (accessibility) rather than a proxy for it (word length), which is arguably the more precise choice, not a regression. Not mined as a discrimination case even so -- there's no clean single right answer to rank, since both phrasings are defensible once the 'word-size is the metric' framing is dropped. 'without being committed co-owners in the solution' (replacing 'not like they built it with you') is a separate, weaker clause in the same sentence and wasn't part of the author's clarification -- still worth a second look, just not for the jargon reason. A third source was mined 2026-09-25 from content/posts/mature-poets-steal.md (see provenance.sources) to fill the 'No flex' and 'Nothing floral' gaps. Case count: 14 discrimination (15 gradable comparisons, since disc-03 is a 3-way rank), 7 transformation, 3 detection (20 hand-built violations + 5 traps total across the three documents).
