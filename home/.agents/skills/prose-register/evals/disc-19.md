---
id: disc-19
type: discrimination
status: draft
source_commits:
  - 55bdc85 (before)
  - 6258fdf (after)
source_repo: ~/src/alannorton.com
source_file: content/posts/pairs-programming.md
correct: after
expected_rule: No jargon without definition. Define a term once, at first use, and only when it walls the reader out; a gloss on a term the audience already holds, or one the piece links to, is padding.
arguable: true
---

Which variant is on-register, and which SKILL.md rule decides it? In the essay, "skill" is a link to the file itself, and the blog's readers run coding agents.

## rule

No jargon without definition. Big words are fine when they're accessible; the ban is on words that wall a reader out, not on vocabulary. Define a term once, at first use, and only when it walls the reader out. A gloss on a term the audience already holds, or one the piece links to, is padding.

## before

So I banned it. The fix is a skill (a page of markdown an agent reads before it acts) that teaches the agent to handle review feedback on its own pull request. The rule is blunt:

## after

So I banned it. The fix is a skill that teaches the agent to handle review feedback on its own pull request. The rule is blunt:

## note

'after' is the author's suggestion ('We don't need to explain what a skill is at this point'). Both variants reduce two markdown links (the skill file and the commit) to their text and drop the trailing commit reference. Arguable because the call depends on who the reader is: 'skill' walls out a general reader, and a subject that picks 'before' on the define-your-jargon half of the rule is making a defensible case; the prompt states the audience so the subject can make the call the author made. Fills the gloss-once half of the jargon rule, which trans-07 only exercises by cutting the term.
