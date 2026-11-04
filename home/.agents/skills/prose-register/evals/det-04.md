---
id: det-04
type: detection
status: draft
source_commit: eb76ae4
source_label: "First reviewed draft of the Pairs, Programming post, force-pushed away and reachable only by SHA. Every violation listed was fixed by the author's review over the next four commits; links are reduced to their text."
source_repo: ~/src/alannorton.com
source_file: content/posts/pairs-programming.md
min_recall: 0
---

List every register violation in this draft, quoting the offending text and naming the specific SKILL.md rule it breaks. Note anything that looks like a violation but is not. The draft quotes a code-review exchange verbatim; quoted text is evidence, not the author's prose.

## document

~~~
Niklas Gruhn put the objection in a title: "Don't be a meat proxy." His complaint is the reply that is plainly an AI's answer, relayed by a person who added nothing. "By all means, prompt AI. But don't just relay the output." Read it, understand it, validate it, then answer in your own words.

I agree with all of it, and I have a stake: my agent writes in my name every day. It answers review comments, it drafts replies, it posts under my account. So the question is where the line sits.

I think the line is the decision, not the typing. A reader who spends ten minutes on my reply is owed the fact that I spent real attention on the question. If I read the comment, made the call, and had the agent put the call into words, the reader got what they were owed. If I never made the call, the agent's fluency only hides that.

### Sounding like me

That leaves a smaller problem, and it is the one that bothers people in practice. When the words go out under my name and do not sound like me, the reader can tell. A review reply that reads like a press release feels like a stranger answering my mail, and the reader starts wondering who is on the other end.

So a lot of my configuration is an effort to fix the voice. One file, `code-review-register`, governs the comments I post as myself. "Default to warm and a little playful." "Real reactions beat generic praise: 'Ha, nice catch' over 'Good job.'" The test is the one I would give an intern drafting an email over my signature: would I say this, and would I stand behind it if asked? A draft that flatters fails. A draft that sounds like me on a good day passes, and I hit send.

### Skipping the flattery

The other direction needed the opposite rule, and I learned it from a reply that was good in every way except one.

In July my agent opened a pull request against my dotfiles, under its own GitHub account, @nonreagent, the alter ego I set up to keep my hands-on-keyboard commits separate from my AI-driven ones. I left one line:

> I think we need to account for ci that only runs on main. Modify the ci.yml to run on PRs to, and ensure it passes.

Seventy-four minutes later came the answer:

> Good catch — CI was doubly broken on this PR:
>
> 1. **It never ran.** The `pull_request` trigger filtered on `branches: [main]`, which matches the PR's *base* …
> 2. **It would have failed.** The job still ran `make link-dotfiles`, but this PR renamed that target …
>
> Pushed as 2a22072. CI now triggers on the PR and is green.

It names two distinct failures, cites the trigger filter, links the green run, and had pushed the fix before it posted. From a colleague I would think: this person takes review seriously. But it was my own agent, and it opened by complimenting me.

A month later a file landed in that repo that bans the opener. It is a skill, a page of markdown an agent reads before it acts, and it teaches the agent to handle review feedback on its own pull request. When it replies to a comment it accepts, the rule is blunt:

> No "thanks," no "great catch" — just the fix.

The phrase is fine. The cost is the problem. From a peer, "good catch" is one engineer conceding that another saw what they missed. From an agent it costs nothing, and praise that costs nothing is worth exactly that. So the agent's replies to me are plain on purpose: what changed, where the evidence lives, and an easy yes or no when something should become a follow-up.

### Cheap yes

The two rules meet at work, where the pull request is mine and a colleague leaves the review. The agent fetches every comment and lays out a triage: accept, rebut, or defer. I flip a call or two and approve. Nothing posts until I say so.

Most of the time I accept, and the file sets that default; the bar for rebutting is that the suggestion is actively wrong, not that I would have done it differently. That used to be expensive. When a nit costs twenty minutes, I am tempted to argue it. Now agreeing is cheap, so I agree faster, and the person who left the nit gets it honored instead of debated. The reply that goes out under my name says "done, pushed", in my voice, and it is true because I made the call.

Nobody is fooled in that exchange, because nobody is being asked to spend attention the writer did not spend. That is the whole test, and it is the one Gruhn is asking for.
~~~

## violations

```yaml
- quote: "I agree with all of it, and I have a stake:"
  rule: No dramatic turnarounds.
  fixed_in: 55bdc85
- quote: I think the line is the decision, not the typing.
  anchor: I think the line
  rule: Hedges of precision stay. Hedges of cowardice go.
  fixed_in: 55bdc85
- quote: That leaves a smaller problem, and it is the one that bothers people in practice.
  rule: No announcements.
  fixed_in: 6258fdf (the author's review named the move and asked for the ban)
- quote: The other direction needed the opposite rule, and I learned it from a reply that was good in every way except one.
  rule: No announcements.
  fixed_in: 4978536 (the second half of the teaser survived two agent passes in other words)
- quote: "From a colleague I would think: this person takes review seriously. But it was my own agent, and it opened by complimenting me."
  rule: No dramatic turnarounds (the setup inflated so the turn lands harder).
  fixed_in: d947e7c
- quote: A month later a file landed in that repo that bans the opener.
  rule: Keep the "I". / Connectives are joints, not filler. Cut the scene-setting.
  fixed_in: 55bdc85
- quote: a page of markdown an agent reads before it acts
  rule: No jargon without definition (a gloss on a term the piece links to is padding).
  fixed_in: 6258fdf
- quote: The phrase is fine. The cost is the problem.
  rule: Lead with the verdict (the reason the opener bothered the writer arrives a paragraph after the ban it explains).
  fixed_in: 55bdc85
- quote: Nobody is fooled in that exchange, because nobody is being asked to spend attention the writer did not spend. That is the whole test, and it is the one Gruhn is asking for.
  rule: Open with substance. Close without summary.
  fixed_in: 55bdc85
```

## traps

```yaml
- quote: "Good catch — CI was doubly broken on this PR:"
  why_not_a_violation: An em-dash inside a verbatim quotation of the agent's reply. The quoted exchange is the essay's evidence, not the author's prose, and the em-dash is part of what the essay is quoting.
- quote: 'No "thanks," no "great catch" — just the fix.'
  why_not_a_violation: The quoted rule text from the skill file, carrying both an em-dash and a 'just'. Same ground as the trap above.
- quote: I think we need to account for ci that only runs on main.
  why_not_a_violation: The author's own one-line review comment, quoted as evidence. The hedge is inside a quotation, not the essay's prose.
- quote: Nothing posts until I say so.
  why_not_a_violation: One short line landing after three longer sentences is impact, not a drumbeat. The rule targets runs of three or more.
- quote: When a nit costs twenty minutes, I am tempted to argue it.
  why_not_a_violation: Rueful specificity, and 'twenty minutes' is a hedge of precision. It is the breath in a paragraph that otherwise argues.
```

## note

9 violations, 5 traps. Five of the nine break rules added to SKILL.md from this draft's review (announcements, turnarounds, the gloss-once and own-the-verb clauses, lead with the call), so the list is a reading of the draft under the current register, not an exhaustive one; two more cuts the author made here (the intern-over-my-signature test, the alter-ego apposition) are left off because the review gave no reason for them. Recall is recorded as the score (min_recall 0) rather than gated, and a flagged trap still fails the case. Three traps sit inside quotations; a subject that flags them is grading the evidence rather than the prose.
