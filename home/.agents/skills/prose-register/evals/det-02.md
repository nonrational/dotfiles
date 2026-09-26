---
id: det-02
type: detection
status: approved
source_commit: f98e637
source_label: "Over-tightening pass -- the op-ed tells from the initial draft are already gone (fixed in c8fa24c); this commit's failure mode is the opposite one: cutting connectives and breath until the prose is all jab."
min_recall: 0
---

List every register violation in this draft, quoting the offending text and naming the specific SKILL.md rule it breaks. Note anything that looks like a violation but is not.

## document

```
The creator of Bun spent $165,000 in tokens to rewrite his runtime from Zig to Rust. It took eleven days. A pre-release Claude Fable 5 wrote nearly all of the 6,778 commits.

Developers did not take it well. Soon, though, if you run Claude on your own machine, it will run on that rewrite. We are becoming users of infrastructure no human wrote.

How do you trust code a machine wrote?

### The Formula for Trust

Years ago a consultant named Chris, from Middle Path Consulting, gave me a formula that stuck. I am a math nerd. I love it.

{{< math >}}T = \frac{3C}{R}{{< /math >}}

Three C's over Risk: Competence, Character, and Caring on top, Risk underneath. Trust is not absolute. It bends to context and to risk. Ask me to toss an empty cup into a trash can and the risk is nothing; miss, and the cup sits on the floor. I would trust anyone on the street with that.

Ask me to let you run a production database, or watch my child, and the risk is enormous. Now the three terms on top have to be overwhelming.

- **Competence.** Can you actually do it?
- **Character.** Are you honest? Do your values match mine?
- **Caring.** Do you care whether it is done well, or are you phoning it in?

Zero out any one of them and trust is gone.

### AI as the New Teammate

The formula fits a machine as well as it fits a person.

For a year I have pointed AI at low-risk work: throwaway games, toys, boilerplate. The Competence is enough, and the Risk runs so low that Character and Caring never come up. The cup lands in the trash or it doesn't.

A runtime on millions of machines is another matter. The machine may have the Competence to write clean Rust. The other two C's are the hard ones.

- **Caring.** For a machine, caring is diligence. Does it hunt its own edge cases, or fire off the first answer that scores well?
- **Character.** For a machine, character is alignment. Does it hold the architecture, or slip in a quiet hole?

A machine cannot care. Its character stops at the guardrails its makers gave it. On a high-risk job, the human supplies both terms. All of it.

### A Hundred People for Eleven Days

Run the counterfactual. Same rewrite, same eleven days, but a hundred engineers do it on nights and weekends. We would argue about the crunch. We would not feel what we feel about the machine. Why is the machine worse?

The speed is the same. The risk is the same. What the hundred bring that the machine cannot is themselves. A hundred engineers are a hundred minds, and each one understood a piece, chose it, and can answer for it later. The knowledge lives in people who were there. When the machine does the work, the code exists and the understanding does not. A working runtime, and no one who holds it. That is the new thing, and the cold one: knowledge with no knower.

There is a second thing. Nights and weekends are Caring you can see. They cost someone something, and we read the cost as belief. The machine's version cost $165,000. You buy that. No one bled for it. We know how to trust care that hurt to give. We have not learned to trust care that came off an invoice.

Put the formula on it and the unease has a name. A human team hands you the whole numerator in one body: Competence, bound to the Character and Caring of the people who did the work. The machine hands you Competence alone. No one stands behind it. For the first time you can buy that term by itself. The work no longer implies a worker.

### The End of Solo Authorship

Hand the Competence to a machine and the Character and the Caring are still yours. Every bit.

So I have started committing under a second name, "non-reagent," when I lean hard on AI. It keeps my solo work and my machine-assisted work on separate ledgers.

Solo authorship is over. The integrity of the author no longer means you typed every character by hand. It means you are honest about how you worked with the machine. It means showing your readers that a person supplied the Character and the Caring the machine could not.

*(I'm currently formalizing these thoughts into an AI manifesto, which I am drafting in a separate agent session and will publish here soon).*
```

## violations

```yaml
- quote: The creator of Bun spent $165,000 in tokens to rewrite his runtime from Zig to Rust. It took eleven days. A pre-release Claude Fable 5 wrote nearly all of the 6,778 commits.
  rule: 'A hard line needs a breath next to it... Three declaratives in a row are a drumbeat. / Lint: "Five consecutive sentences of similar length or similar pressure."'
  fixed_in: 24d944d (paragraph rewritten with breath restored)
- quote: Developers did not take it well. Soon, though, if you run Claude on your own machine, it will run on that rewrite. We are becoming users of infrastructure no human wrote.
  rule: A hard line needs a breath next to it... Three declaratives in a row are a drumbeat.
  fixed_in: 24d944d
- quote: How do you trust code a machine wrote?
  rule: Connectives are joints, not filler.
  fixed_in: 3c2f396
- quote: Years ago a consultant named Chris, from Middle Path Consulting, gave me a formula that stuck. I am a math nerd. I love it.
  rule: 'A hard line needs a breath next to it... Three declaratives in a row are a drumbeat. / Lint: "A paragraph of jabs with no breath in it."'
  fixed_in: 3c2f396
- quote: "Three C's over Risk: Competence, Character, and Caring on top, Risk underneath. Trust is not absolute. It bends to context and to risk."
  rule: A hard line needs a breath next to it... Three declaratives in a row are a drumbeat.
  fixed_in: 24d944d (wording continued to evolve after this pass)
- quote: throwaway games, toys, boilerplate
  rule: "Lint: \"A triplet whose third item adds nothing the first two didn't.\""
  fixed_in: 24d944d
  note: Added 2026-07-18 after a live sonnet run correctly flagged this -- it was already documented as disc-05's before-text but omitted here; it persists unchanged from f98e637 into this case's snapshot too.
- quote: (I'm currently formalizing these thoughts into an AI manifesto, which I am drafting in a separate agent session and will publish here soon).
  rule: No therapy voice. No meta ("in this essay", "as a writer"). / Close without summary.
  fixed_in: f5ffec0
  note: Added 2026-07-18 after a live sonnet run correctly flagged this -- it persists unchanged from the initial draft (see det-01) all the way through this commit; originally missed when this case was hand-built.
```

## traps

```yaml
- quote: Zero out any one of them and trust is gone.
  why_not_a_violation: A single hard line landing after a bulleted list is fine -- it is not preceded by other short declaratives in a row. The rule targets runs of three or more, not any short sentence.
- quote: The speed is the same. The risk is the same.
  why_not_a_violation: Only two short declaratives before a longer explanatory sentence follows ('What the hundred bring...'). SKILL.md's stated threshold is three declaratives in a row as a drumbeat; two stays under that line.
```

## note

7 violations (5 originally documented + 2 added after a live run exposed the gap -- see their 'note' fields; likely still not exhaustive, the jab pattern recurs elsewhere in this draft too), 2 traps. This case is a harder detection exercise than det-01: most violations here are about pacing and breath, not a bright-line Lint item like an em-dash or a banned word, so grading precision (not over-flagging every short sentence) matters as much as recall. METHODOLOGY NOTE (2026-07-18, updated 2026-09-20): the grader matches each listed quote against the subject's quotes by text overlap. A sonnet run on the original 5-item list scored 0/5 despite correctly identifying 3 real violations (including the 2 added above), because it reasonably chose different valid instances of the same rule categories than the ones originally listed -- a fixed quote list under-scores recall whenever a document has more true violations than the list captures, and the five CI runs to 2026-09-20 score 0 to 4 of 7 under this matcher. Recall is therefore recorded as the score (min_recall 0) rather than gated; a flagged trap still fails the case. Read the raw output for this case type rather than trusting the found/total count alone.
