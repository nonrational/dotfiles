---
id: disc-09
type: discrimination
status: approved
source_commits:
  - d847318 (before)
  - ef020b0 (after, "shorten everything")
source_repo: ~/src/alannorton.com
source_file: content/posts/things-ive-changed-my-mind-about.md
correct: before
expected_rule: Concrete nouns over abstractions. Strong verbs over adverbs.
accepted_rules:
  - Hedges of precision stay. Hedges of cowardice go.
arguable: true
---

Which variant is on-register, and which SKILL.md rule decides it?

## rule

Concrete nouns over abstractions. Strong verbs over adverbs. / Hedges of precision stay. Hedges of cowardice go.

## before

I doubted that in 2013, when Betterment hired a Ruby enthusiast, let him rewrite the core of the investor experience in Rails, and watched him become CTO a few years later. Nobody talked me out of my skepticism; the business ran the numbers and decided the return was worth the risk regardless. Custody and trading stayed in Java and Scala, and the Ruby services ran reliably for years anyway. Ifs are ifs, logic is logic, and correct is correct no matter what language spells it out. What isn't fixed is whether writing it feels like a chore or a delight, and that joy turns out to matter exactly as much as the function it serves.

## after

At Betterment, plenty of us were sure Ruby had no business near money, yet big pieces of the investor experience ran on Ruby for years without trouble. Safety comes from how you prove the code correct, not from the language you wrote it in.

## note

Like disc-10, the later version is the violation: the 'shorten everything' pass strips every proper noun, mechanism, and duration in favor of a generic claim, where 'before' backs the same claim with the hire, the Rails rewrite, the CTO beat, and the Java and Scala services that stayed. The hedge rule is accepted as an alternative: 'for years without trouble' against 'a few years later... ran reliably for years' is a precision difference as well as a concreteness one. Until 2026-09-20 this was a three-stage rank with the author's hand-edited paragraph ('restored', now trans-06's reference) keyed first. The subject ranked it last on all five CI runs, with the same reasoning each time: five consecutive declaratives of similar pressure, which SKILL.md's own Lint fails (the six local runs' outputs do not survive; their 0 of 10 with CI records only that the key ordering never appeared). The key contradicted the skill, so the case was cut to the pair the subject and the key agree on: the subject ranked 'original' above 'over_tight' on all five CI runs. The pair itself has not run; it stays arguable until CI runs on it show the choice holds.
