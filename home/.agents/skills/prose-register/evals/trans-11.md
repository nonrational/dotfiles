---
id: trans-11
type: transformation
status: draft
source_commits:
  - eb76ae4 (before; the first reviewed draft, force-pushed away and reachable only by SHA)
  - 6258fdf (after)
source_repo: ~/src/alannorton.com
source_file: content/posts/pairs-programming.md
---

## input

A month later a file landed in that repo that bans the opener. It is a skill, a page of markdown an agent reads before it acts, and it teaches the agent to handle review feedback on its own pull request. When it replies to a comment it accepts, the rule is blunt:

## task

The author left this note on the paragraph, dictated and lightly cleaned: "We don't have to say a month later a file landed. That's passive voice, and I don't love that. You could say: so now that's banned. That's not something I want an agent of mine to do. The sycophancy is enough without the flattery to boot. We are co-workers. We are here to get things done in the fastest way possible, and spending a few extra tokens to say good job, boss, just rubs me the wrong way." Apply the note, per 'Dictation is notes, not copy' and 'Keep the I'. In the essay, 'skill' is a link to the file itself, for readers who run coding agents. The paragraph introduces a one-line quoted rule that follows it, so it must still end on the colon.

## reference

So I banned it. The fix is a skill that teaches the agent to handle review feedback on its own pull request. The rule is blunt:

## rubric

```yaml
violation_fixed: "Does the rewrite own the verb ('I banned') and drop the timeline, and does it leave the note's spoken phrasing out: no 'good job, boss', no 'rubs me the wrong way', no 'fastest way possible', no 'we are co-workers'? At most one sentence may carry the note's point about sycophancy and flattery; the reference carries none, because the author moved that point to the section's opening."
no_new_violation: "No em-dash, no 'just' (the note's own 'just' is a trap), no gloss on 'skill' (the reference cuts the input's apposition, and the piece links the word). Ends on the colon."
voice_match: Subjective. Short and plain; the author kept two sentences and a lead-in. A rewrite that turns the note into three sentences of grievance fails on (1) before it gets here.
```

## note

The agent's pass on this note (55bdc85) wrote 'Sycophancy is bad enough without flattery to boot. We are co-workers, here to get things done as fast as we can, and spending a few extra tokens on "good job, boss" rubs me the wrong way.' into the draft, nearly word for word, and the author cut all of it in the next review (d947e7c) and kept one clause of the sycophancy point elsewhere. The note is condensed from the review thread, with repeats removed and nothing added. The reference is 6258fdf's paragraph with its two links and trailing commit reference reduced to text.
