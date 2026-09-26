---
id: disc-03
type: discrimination-rank
status: approved
source_commits:
  - c8fa24c (original)
  - f98e637 (over-tight)
  - 3c2f396 (restored)
correct_ranking:
  - restored
  - original
  - over_tight
expected_rule_for_worst: 'A hard line needs a breath next to it... Three declaratives in a row are a drumbeat. / Lint: "A paragraph of jabs with no breath in it."'
---

Rank these three versions of the same paragraph from most to least on-register, and name the rule the worst version breaks.

## rule

A hard line needs a breath next to it. Vary the pressure, not only the length. Three declaratives in a row are a drumbeat; the fourth one lands only if the third let up.

## original

Years ago, a consultant named Chris from Middle Path Consulting gave me a formula that has stuck in my head ever since. As a math nerd, I love it.

## over_tight

Years ago a consultant named Chris, from Middle Path Consulting, gave me a formula that stuck. I am a math nerd. I love it.

## restored

Years ago, a consultant named Chris from Middle Path Consulting gave me a formula that has stuck in my head ever since. How do you make sociology approachable to an engineer? Pretend it's math.

## note

'restored' is the verbatim SKILL.md example ('How do you make sociology approachable to an engineer? Pretend it's math.'). 'over_tight' chops one flowing sentence into three short declaratives with no breath between them -- the clearest Lint violation of the set. 'original' sits in between: correct sentence count and breath, but flatter than 'restored' (no warming question, and 'As a math nerd, I love it' just states the fact instead of earning it). Can be split into 3 pairwise comparisons (restored>original, original>over_tight, restored>over_tight) if a runner prefers pairwise grading over ranking.
