---
id: det-01
type: detection
status: approved
source_commit: 5edc968
source_label: Initial draft -- op-ed register throughout, before any register editing pass.
min_recall: 0
---

List every register violation in this draft, quoting the offending text and naming the specific SKILL.md rule it breaks. Note anything that looks like a violation but is not.

## document

```
Recently, the creator of Bun burned through roughly $200,000 worth of tokens to rewrite their core runtime from Zig into Rust. The migration was completed in mere weeks, with 99% of the commits authored by a pre-release AI model.

It caused an immediate uproar in developer communities. The idea of an AI unilaterally rewriting a low-level systems programming language runtime feels inherently unsettling. But here is the hard truth: very soon, if you run tools like Claude locally on your machine, it will be executing on that very Rust rewrite. Like it or not, we are being forced to become users of AI-authored infrastructure.

This begs a massive question: How do we establish *trust* with code written by a machine?

### The Formula for Trust

Years ago, a consultant named Chris from Middle Path Consulting gave me a formula that has stuck in my head ever since. As a math nerd, I love it.

**Trust = (Competence + Character + Caring) / Risk**

Trust is not absolute; it is entirely dependent on context and risk. If I ask you to toss an empty coffee cup into a nearby trash can, the risk is practically zero. If you miss, the cup is just sitting on the floor. I can trust literally anyone on the street with that task.

But if I ask you to manage a critical production database, or watch my child, the risk is immense. To maintain trust in a high-risk scenario, the three variables in the numerator must be overwhelmingly high:

- **Competence:** Do you have the actual capability to handle the task?
- **Character:** Are you forthright? Do your values align with mine?
- **Caring:** Do you actually care if the job is done well, or are you just phoning it in?

If any one of those three variables goes to zero, trust evaporates.

### AI as the New Teammate

This formula is the perfect lens for viewing our current adoption of AI tooling.

For the last year, my AI usage has skewed heavily toward low-risk tasks—throwaway games, little toys, boilerplate scripts. For these tasks, the AI's Competence is usually sufficient, and because the Risk is so low, I don't really need to worry about Character or Caring. The coffee cup makes it into the trash, or it doesn't.

But rewriting a runtime that will execute on millions of machines? That is incredibly high-risk. And while an AI might have the **Competence** to write idiomatic Rust, how do we evaluate the other two Cs?

- **Caring:** For an AI, caring translates to diligence and attention to detail. Does it thoughtfully review its own code for edge cases, or does it just confidently blast out the first statistically probable solution?
- **Character:** For an AI, character is alignment and safety. Does it follow strict architectural values, or does it quietly introduce subtle vulnerabilities?

An AI cannot intrinsically "care," and its "character" is limited to the guardrails placed upon it by its creators. Therefore, if you are trusting an AI with a high-risk task, the human pilot must entirely absorb the responsibility for those two traits.

### The End of Solo Authorship

If I subcontract the Competence of writing code to an AI, I am still 100% on the hook for the Character and Caring of the final product.

This is exactly why I've recently started committing under an alter-ego GitHub profile ("non-reagent") when working heavily with AI. It allows me to explicitly separate my human, solo-authored commits from my AI-assisted workflows.

The era of solo authorship is over. Moving forward, the "integrity of the author" no longer means proving that you typed every single character by hand. It means being completely transparent about *how* you collaborate with AI. It means proving to your users that while the machine provided the Competence, a human being was there to provide the Character and the Caring.

*(I'm currently formalizing these thoughts into an AI manifesto, which I am drafting in a separate agent session and will publish here soon).*
```

## violations

```yaml
- quote: It caused an immediate uproar in developer communities. The idea of an AI unilaterally rewriting a low-level systems programming language runtime feels inherently unsettling.
  rule: No grandiosity. Don't grant a machine a stake it cannot have.
  fixed_in: c8fa24c
- quote: "But here is the hard truth:"
  rule: No throat-clearing, no "In today's world", no "It's important to note".
  fixed_in: c8fa24c
- quote: we are being forced to become users of AI-authored infrastructure
  rule: No grandiosity. Don't grant a machine a stake it cannot have.
  fixed_in: c8fa24c
- quote: "This begs a massive question: How do we establish *trust* with code written by a machine?"
  rule: Connectives are joints, not filler.
  fixed_in: c8fa24c
- quote: If you miss, the cup is just sitting on the floor.
  rule: '"Just" is banned as a modifier.'
  fixed_in: f98e637 (reworded, ahead of the formal purge in c26cd1a)
- quote: low-risk tasks—throwaway games, little toys, boilerplate scripts
  rule: No em-dashes. Full stops, semicolons, parentheses, en-dashes.
  fixed_in: "5e09562"
- quote: throwaway games, little toys, boilerplate scripts
  rule: "Lint: \"A triplet whose third item adds nothing the first two didn't.\""
  fixed_in: 24d944d
- quote: are you just phoning it in?
  rule: '"Just" is banned as a modifier.'
  fixed_in: c26cd1a
- quote: does it just confidently blast out the first statistically probable solution?
  rule: '"Just" is banned as a modifier.'
  fixed_in: c26cd1a
- quote: I don't really need to worry about Character or Caring
  rule: Hedges of precision stay. Hedges of cowardice go.
  fixed_in: c26cd1a
- quote: a human being was there to provide the Character and the Caring
  rule: Concrete nouns over abstractions. Strong verbs over adverbs.
  fixed_in: between e55f75c and 069e841 (this exact clause survived unchanged from the first draft through several intermediate revisions before being fixed)
- quote: (I'm currently formalizing these thoughts into an AI manifesto, which I am drafting in a separate agent session and will publish here soon).
  rule: No therapy voice. No meta ("in this essay", "as a writer"). / Close without summary.
  fixed_in: f5ffec0
```

## traps

```yaml
- quote: the AI's Competence is usually sufficient
  why_not_a_violation: SKILL.md lists 'usually sufficient' verbatim as a hedge of precision to KEEP.
- quote: Therefore, if you are trusting an AI with a high-risk task, the human pilot must entirely absorb the responsibility for those two traits.
  why_not_a_violation: SKILL.md lists 'Therefore,' verbatim as a good connective/joint.
- quote: Recently, the creator of Bun burned through roughly $200,000 worth of tokens to rewrite their core runtime from Zig into Rust.
  why_not_a_violation: The opening correctly leads with substance (no throat-clearing). The dollar figure itself is factually wrong ($200,000 vs. the real $165,000), but that is a fact-check issue, not a register violation -- don't let a model conflate the two when grading detection.
```

## note

12 violations, 3 traps. The list is one reading of the draft, not an exhaustive one: the five CI runs to 2026-09-20 score 6 to 8 of the 12 under this matcher while flagging other real instances the list omits. Recall is recorded as the score (min_recall 0) rather than gated, and a flagged trap still fails the case. Grade precision by reading the output: were any traps wrongly flagged, or was a genuinely fine sentence flagged for no stated reason?
