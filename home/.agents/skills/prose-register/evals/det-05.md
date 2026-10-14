---
id: det-05
type: detection
status: draft
source_commit: working tree on 2026-10-14 (the author's post-merge hand edit, uncommitted when mined; update when it lands)
source_label: "The author's post-merge hand edit of the Pairs, Programming post: the introduction and the two register sections, read as the voice the register describes. Links are reduced to their text."
source_repo: ~/src/alannorton.com
source_file: content/posts/pairs-programming.md
min_recall: 0
---

List every register violation in this passage, quoting the offending text and naming the specific SKILL.md rule it breaks. Note anything that looks like a violation but is not. The passage quotes an agent's reply and a rule from a skill file; quoted text is evidence, not the author's prose.

## document

~~~
Everyone has an agent in their pocket now, which makes it trivial to conjure words from nothing. Niklas Gruhn named the failure in a title: "Don't be a meat proxy." He's right: we all despise it, but we've all done it.

Because it is so nice to have a ghostwriter! Such convenience! My agent answers review comments, drafts replies, and posts under my account every day. And I do more, faster. But if an agent is going to publish under my name, it needs to be sufficiently good. I like writing well. So the question becomes, how do I retain the convenience and speed without my readers feeling like I've handed them something cheap?

And so, I set out to make the machine sound more like me. Let's talk about code review!

## Me and myself, as reviewer

For now at least, code review is composed of prose. I want an agent to be able to review code someone else authored, so I can interrogate it, learn it, and determine whether I support shipping it. The decision is mine. But that decision and its additive, component parts need to be encoded in prose.

Agents don't read the room or know their audience. They have tics and tells and bad habits. Even if the core intent of a message is valid, it's hard to engage with over-dramatic constructions like "You're right, and it's worse than I thought..." in a PR that drops a column prematurely.

So I've worked hard to coax agents into sounding more like me out of the gate, and revise from there. /code-review-register governs the comments I ask an agent to draft. "Default to warm and a little playful." "Real reactions beat generic praise: 'Ha, nice catch' over 'Good job.'" I want to be able to stand behind a first or second draft. When my hands are on the keyboard and I am the one waving the baton, a little playfulness in the agent's prose is welcome. I'm critiquing someone else's work, often starting new threads. Brightness, recognition of good work, and humor help build capital to be spent on critique.

## Me and myself, as author

Conversely, when an agent is _responding_ to suggestions or critique, often autonomously, I want the playfulness gone. No flattery, no pleasantries. I don't like being talked to by an agent that pretends to care. Sycophancy is bad enough without empty, quasi-emotional words.

In July, my agentic alter ego @nonreagent opened a pull request against my dotfiles. I left a one-line comment, and it replied "Good catch — CI was doubly broken on this PR" and followed up with the helpful details of its analysis.

It named the failures and had pushed the fix before it posted. But, all I could think about was how silly the opening line felt. I mean, nothing is wrong with the phrase. From a peer, "good catch" is a concession. But from an agent, it costs nothing, and praise that costs nothing is worth exactly that.

So I banned it. /address-pr-feedback teaches the agent to bluntly handle review feedback: no "thanks," no "great catch," just the fix.
~~~

## violations

```yaml
- quote: teaches the agent to bluntly handle review feedback
  anchor: bluntly handle
  rule: Strong verbs over adverbs (the earlier draft had 'The rule is blunt:' and let the rule speak).
  fixed_in: open; the author has not ruled on it
```

## traps

```yaml
- quote: Let's talk about code review!
  why_not_a_violation: A joint that turns the corner into the first section and promises nothing about what follows. 'No announcements' names the teaser that grades the next point or trails a story; a four-word pivot with a wink is a breath, not a teaser.
- quote: So the question becomes, how do I retain the convenience and speed without my readers feeling like I've handed them something cheap?
  why_not_a_violation: A worry the writer owns, framed as a question that hands off to the argument. 'Never claim the reader's reaction' bans telling the reader what they will feel or conclude; naming what the writer is trying not to do to them is the writer's stake.
- quote: it needs to be sufficiently good
  why_not_a_violation: A hedge of precision. 'Sufficiently good' means good enough to publish, not excellent, and the next sentence ('I like writing well.') is the contrast it sets up.
- quote: So I've worked hard to coax agents into sounding more like me out of the gate, and revise from there.
  why_not_a_violation: A plain report of effort that sets up the skill named in the next sentence. 'No flex' targets a line whose real work is showing how generous or sharp the writer is; this one's work is the setup.
- quote: Brightness, recognition of good work, and humor help build capital to be spent on critique.
  why_not_a_violation: The closing line of a paragraph that builds to it. 'Lead with the verdict' governs a verdict paragraph, where the judgment opens and the reasons follow; a paragraph that assembles a case and lands on its point is a different shape and is the writer's own.
- quote: I mean, nothing is wrong with the phrase.
  why_not_a_violation: A spoken joint the writer chose on the page, listed under 'Connectives are joints, not filler'. 'Dictation is notes, not copy' is about review-note phrasing pasted into a draft, not about a conversational connective in the writer's own hand.
- quote: So I banned it.
  anchor: So I banned it
  why_not_a_violation: The third paragraph in the passage to open on 'So'. The repeated joint is the writer's cadence; the lint on consecutive sentences of similar pressure targets a run of declaratives, not a connective reused across paragraphs.
- quote: 'no "thanks," no "great catch," just the fix'
  why_not_a_violation: The terse form of an order to a machine. The 'just' ban targets a 'just' that shrinks a cost or loads a question ('why not just let them'); this one has no cost to shrink and no reader to lean on.
- quote: "Good catch — CI was doubly broken on this PR"
  why_not_a_violation: An em-dash inside a verbatim quotation of the agent's reply.
```

## note

1 violation, 9 traps. The 'just the fix' trap first rested on quotation (the rule's text from the skill file); the author's answer was that the rule needs no quoting and the 'just' is an order's terseness, so the trap now rests on the narrowed rule. The passage is the author's hand edit of the published post, taken as ground truth for the voice: every trap is a line a reviewer flagged under the register as it stood after the first mining pass, and the author's answer was that the prose is right and the rule was too wide. The case exists to catch over-flagging (min_recall 0, so a flagged trap is the only way to fail it). The one violation is the adverb the author has not ruled on; if the author keeps it, move it to the traps as a second hedge of precision and the case has no violations left to find, which the harness cannot score, so pair it with another or retire it.
