# Evals handoff: prose-register

Date: 2026-07-17
Source repo: /Users/norton/src/alannorton.com (branch `social-link-previews` at mining time; file is fully merged into that branch)
Source file: `content/posts/trust-in-the-age-of-ai.md`
Skill under test: `home/.claude/skills/prose-register/SKILL.md`
Commits mined (oldest to newest):
`5edc968898c4a0b36bcabda8e906a85e98f41528` → `5b4cbdecffa9f94312ef6313ab9a2753d0b5f51a`

This doc is read-only research output. Nothing in the source repo or this repo was changed to produce it.

## Why this essay

The essay is the actual source of several SKILL.md examples. `SKILL.md` quotes these lines verbatim:

- `not unreviewed code, but un-authored knowledge, severed from any knower`
- `The unease was never that the work is bad. It is that the work no longer implies a worker.`
- `How do you make sociology approachable to an engineer? Pretend it's math.`
- `throwaway games, little toys, a script I will run once and never think about again`
- `nights and weekends and too much coffee`
- `mostly it looks like revision`
- `Slop, ironically, is sloppy.`

That means this history is not just "an essay that happens to fit the rules" — the rules were partly written by watching this essay get edited. Evals built from it should discriminate well.

## Revision map

| SHA | Subject | Editorial change |
|---|---|---|
| `5edc968` | add AI co-author colophon to co-authored posts | Initial draft. Op-ed register throughout: "uproar," "inherently unsettling," "here is the hard truth," "This begs a massive question." |
| `5aae06b` | correct Bun figures and add the unreviewed-slop section | Fixes invented figures ($200k→$165k, "weeks"→11 days, "99% of commits"→6,778 commits). Adds a section built around the critic's word "unreviewed slop." |
| `e1fc1c1` | reframe the Bun section around the missing worker instead of slop | Deletes the "slop" framing entirely; replaces it with the "hundred people" counterfactual and the un-authored-knowledge argument. Introduces em-dashes. |
| `5e09562` | use en-dashes instead of em-dashes per style rule | Pure mechanical pass: every em-dash (`—`) → spaced en-dash (` – `). No wording changes. |
| `951b0ac` | typeset the trust formula as 3C/R with build-time MathML | Formatting only (Hugo shortcode for math). Not prose-register material. |
| `c8fa24c` | flatten op-ed phrasing in the Trust opening | Removes "uproar," "inherently," "here is the hard truth," "forced to become." Converts "This begs a massive question" to "Which raises the question." |
| `f98e637` | editorial pass: tighter, plainer, Strunk and White register | Aggressive tightening across the whole piece. Cuts connectives, cuts questions, shortens lists. Goes further than the skill wants — the next commit walks parts of it back. |
| `24d944d` | warm the Trust essay: add breath and delight, weave in caring-as-revision | Adds back human detail and rueful specificity cut by the previous pass. Adds the whole "caring is revision" paragraph. This is the clearest single commit demonstrating "a hard line needs a breath." |
| `f08e2fe` | add lived-experience section: craft, low stakes, and slop as gatekeeping | Adds "The Workshop and the Job" section (woodworking analogy, "Slop, ironically, is sloppy"). **This section was cut in `069e841` and never shipped.** |
| `f5ffec0` | tighten the /ai page, credit it, drop the stale manifesto note | Mostly touches a different file; only removes the trailing "(I'm currently formalizing...)" aside from this essay. |
| `3c2f396` | revert to warm version | Reverts the opening paragraphs specifically back past the `f98e637`/`c8fa24c` tightening, restoring "Which raises the question" and the sociology question. Sets `draft: true`. |
| `e55f75c` | headline opening, publish drafts in preview env | Adds the "Consider two headlines" cold open (rhetorical restructure). Adds Claude as co-author credit, a footnote, and a link glossing "principals." |
| `069e841` | final draft | Cuts "The Workshop and the Job" section entirely. Sharpens a metaphor pair ("care that hurt to give" / "came off an invoice" → "care as a sacrifice" / "care as a line item"). Small wordplay fix (Competence/Character/Caring → competence/character/care). |
| `c26cd1a` | style footnotes, final pass | Cuts two instances of "just" as a modifier, one "really" hedge, a stray quote-mark placement. Pure lint-style cleanup. |
| `04e0799` | citation, un-draft | Removes `draft: true`, adds a citation link, adjusts co-author credit roles. |
| `5b4cbde` | add post and page descriptions | Adds a YAML `description` field. **This description contains an em-dash** (`same artifact — one rewrite`), added after the em-dash purge in `5e09562` and never caught. Currently live in the published file. |

## Before/after pairs

Each pair is verbatim from the diff. Rule text is quoted from SKILL.md.

### 1. Factual precision (hedges of precision)
**Commit:** `5aae06b`
**Rule:** "Hedges of precision stay... Keep: 'roughly $165,000'"
- Before: `roughly $200,000 worth of tokens ... in mere weeks, with 99% of the commits authored by a pre-release AI model`
- After: `roughly $165,000 in tokens ... in just 11 days, with a pre-release version of Claude Fable 5 authoring nearly all of the 6,778 commits`

### 2. Op-ed tells flattened
**Commit:** `c8fa24c`
**Rule:** Baseline — "No throat-clearing" / Prohibitions — "No grandiosity. Don't grant a machine a stake it cannot have."
- Before: `It caused an immediate uproar in developer communities. The idea of an AI unilaterally rewriting a low-level systems programming language runtime feels inherently unsettling. But here is the hard truth: ... we are being forced to become users of AI-authored infrastructure.`
- After: `Developer communities did not take it well, and an AI rewriting a low-level runtime out from under everyone is an unsettling thing to sit with. But very soon, ... we are becoming users of AI-authored infrastructure.`
- Note: this is the best-available match, not a perfect one — SKILL.md doesn't name "op-ed tells" as a rule verbatim. See Caveats.

### 3. Connective restored as a joint
**Commit:** `c8fa24c`
**Rule:** "Connectives are joints, not filler. 'Which raises the question:'... give the reader somewhere to breathe."
- Before: `This begs a massive question: How do we establish *trust* with code written by a machine?`
- After: `Which raises the question: how do you establish *trust* in code written by a machine?`

### 4. Over-tightening, then restoring breath (three-stage — good discrimination material)
**Commits:** `f98e637` (over-tight) → `3c2f396` (restored)
**Rule:** "A hard line needs a breath next to it... Three declaratives in a row are a drumbeat" / Moves — "Questions may warm, not only cut."
- Over-tight (`f98e637`): `Years ago a consultant named Chris, from Middle Path Consulting, gave me a formula that stuck. I am a math nerd. I love it.` — three short declaratives, no breath, fails the Lint condition "A paragraph of jabs with no breath in it."
- Restored (`3c2f396`): `Years ago, a consultant named Chris from Middle Path Consulting gave me a formula that has stuck in my head ever since. How do you make sociology approachable to an engineer? Pretend it's math.` — one longer sentence, then a warming question (this exact question is quoted in SKILL.md).

### 5. Connective cut, then restored
**Commits:** `f98e637` (cut) → `3c2f396` (restored)
**Rule:** "Connectives are joints, not filler."
- Cut: `How do you trust code a machine wrote?`
- Restored: `Which raises the question: how do you establish *trust* in code written by a machine?`

### 6. Three-part list, decorative → doing work
**Commits:** `f98e637` (flat) → `24d944d` (final)
**Rule:** "Three-part lists are fine when the last item does work the first two don't." Verbatim SKILL.md example is the "after" text.
- Flat: `throwaway games, toys, boilerplate`
- Final: `throwaway games, little toys, a script I will run once and never think about again`

### 7. Human detail added for breath
**Commit:** `24d944d`
**Rule:** "Where the breath comes from... A human detail: *nights and weekends and too much coffee*" (verbatim SKILL.md example)
- Before: `a hundred engineers do it on nights and weekends`
- After: `a hundred engineers do it, on nights and weekends and too much coffee`

### 8. "Not X, but Y" reframing (whole-section replacement)
**Commits:** `5aae06b` (before) → `e1fc1c1` (after)
**Rule:** "'Not X, but Y' is allowed. It is the signature move. It earns its place when the reversal *is* the argument."
- Before (the "slop" framing): `That phrase contradicts itself, and the contradiction is the point. Slop is a verdict on Competence—sloppy, low-quality work. But unreviewed means he never inspected the Competence.`
- After (the "not X but Y" framing, verbatim SKILL.md example): `not unreviewed code, but un-authored knowledge, severed from any knower` — closing with `The unease was never that the work is bad. It is that the work no longer implies a worker.`

### 9. Em-dash → en-dash mechanical pass
**Commit:** `5e09562`
**Rule:** Baseline — "No em-dashes. Full stops, semicolons, parentheses, en-dashes." / Lint — "An em-dash" fails the draft.
- Before: `same eleven days — but by a hundred engineers`, `The system is comprehended — the knowledge lives`, `cost $165,000 — a purchase, not a sacrifice`
- After: `same eleven days – but by a hundred engineers`, `The system is comprehended – the knowledge lives`, `cost $165,000 – a purchase, not a sacrifice`

### 10. "Just" purged as a modifier
**Commit:** `c26cd1a`
**Rule:** "'Just' is banned as a modifier. It stacks the deck." (verbatim rule)
- Before: `are you just phoning it in?` / `does it just confidently blast out the first statistically probable solution?` / `I don't really need to worry about Character or Caring`
- After: `are you phoning it in?` / `does it confidently blast out the first statistically probable solution?` / `I don't need to worry about Character or Caring`

### 11. Hedge of precision, verbatim SKILL.md example
**Commit:** `24d944d`
**Rule:** "Hedges of precision stay... Keep: ... 'mostly it looks like revision'"
- Added: `So what does keeping them look like? Mostly it looks like revision. A machine will give you a competent first draft in a single pass, and it will be good, and that is the trap. Caring is what happens after. You roll the idea over. You try the sentence four ways. You cut the line you were proudest of because it was showing off and not saying anything.`
- There is no "before" — this is new material. Use it as a positive-only example (recognize/preserve, not transform).

### 12. Concrete nouns over abstraction (parallel metaphor tightened)
**Commit:** between `e55f75c` and `069e841`
**Rule:** "Concrete nouns over abstractions. Strong verbs over adverbs."
- Before: `We know how to trust care that hurt to give. We do not yet know how to trust care that came off an invoice.`
- After: `We know how to trust care as a sacrifice. We do not yet know how to trust care as a line item.`

### 13. Nominalization collapsed into a verb
**Commit:** between `e55f75c` and `069e841`
**Rule:** "Concrete nouns over abstractions. Strong verbs over adverbs."
- Before: `a human being was there to provide the Character and the Caring`
- After: `a human character was there to care` (then `c26cd1a` fixes grammar to `a human with character was there to care`)

### 14. Open with substance (structural, not sentence-level)
**Commit:** `e55f75c`
**Rule:** Baseline — "Open with substance. Close without summary."
- Before (all prior commits): essay opens directly on the fact — `Recently, the creator of Bun burned through roughly $165,000 in tokens...`
- After: essay opens on the two-headlines device — `Consider two headlines:` followed by the two block quotes, then five sentences of argument before the fact is confirmed as real. This is a structural, not sentence-level, before/after — useful for a coarser-grained eval.

## Proposed eval designs

### (a) Discrimination
Show the model two variants of a passage — one from an earlier commit, one from a later one — and ask it to pick the on-register variant and name the rule it violates/satisfies. Best pairs for this: 4, 5, 6, 9, 10 (clean before/after with a single identifiable rule). Pair 4 is the strongest: it's a three-way chain (original → over-tight → restored), so you can ask the model to rank all three, not just pick a winner.
- Grading: exact match on which variant is on-register, plus a rule-name check (does the cited rule appear in SKILL.md, and is it the *correct* one — e.g. don't accept "no em-dashes" as the reason for picking the connective-restored variant).
- Case count: ~7 clean pairs (1, 3, 4, 5, 6, 9, 10), each usable as one discrimination item; pair 4 can generate 3 items (rank-3, or three pairwise comparisons).

### (b) Transformation
Give the model the "before" text and ask it to produce an on-register edit. Grade against the actual "after" — not for exact match (that's brittle and wrong for a prose task) but for: did it fix the specific violation, did it avoid introducing a new one (check the Lint list), and is it recognizably closer to the "after" in register (a second LLM-judge pass, or a human skim).
- Best source pairs: 1 (factual + concrete), 2 (op-ed flattening), 8 (whole-section reframe — the hardest, most generative case), 12, 13.
- Grading: rubric-based — (1) violation fixed y/n, (2) no new Lint violation introduced, (3) reads like the author's voice (subjective, flag for human spot-check).
- Case count: 5 pairs, expandable if you also feed in the full essay as context (real transformation work rarely happens sentence-isolated).

### (c) Detection
Give the model a paragraph (or the full essay at a specific commit) and ask it to list register violations with the specific rule each one breaks.
- Use `5edc968` (initial draft) or `f98e637` (over-tight pass) as the "before" input — both are dense with violations (uproar/inherently/hard truth in the first; jab-paragraph and cut connectives in the second).
- A sharper, real-world case: the **current published file** (`content/posts/trust-in-the-age-of-ai.md` as of `5b4cbde`) still contains one live em-dash in the YAML `description` field (`same artifact — one rewrite`), introduced after the em-dash purge and never caught. This is a genuine, currently-shipped miss — good for testing whether the model catches violations outside the main prose body (frontmatter, not just paragraphs).
- Grading: recall/precision against a hand-built violation list per input (build this list when constructing the eval — don't infer it only from the diff, since some violations in the initial draft were never explicitly "fixed" for register reasons, e.g. some were fixed as part of the fact-correction pass, not the register pass).
- Case count: 2-3 full-paragraph or full-document detection cases from the initial draft and the over-tight pass, plus the 1 frontmatter case.

## Caveats

**Publication status of quoted text.** Sections f08e2fe added ("The Workshop and the Job," including the "Slop, ironically, is sloppy" joke) were cut in `069e841` and never shipped on the live site. That text is real, author-approved draft prose — fine to quote in the author's own dotfiles — but it is not what a reader of alannorton.com would see if they went looking for the source. If any eval surfaces this text, note it as "drafted, not published" rather than implying it's live. The dotfiles repo is public; this doc itself quotes that text, which is the author's call to keep or redact.

**Rules in SKILL.md the mined history does not exercise** (name them so eval coverage gaps are explicit):
- **No flex** ("Never a sentence that flatters the writer") — no example in this essay's history of a flex line being cut.
- **Never claim the reader's reaction** ("this is why you can trust me") — no example found; the essay is consistently careful never to claim this, but there's no edit-pair showing a violation getting caught and fixed.
- **Nothing floral** ("The people who lit my path" is a costume) — no floral-language example in this history.
- **Keep the "I"** (the SKILL.md example "The rule applies equally" → "I don't run a quieter rule for probabilistic character generators") — that example is not from this essay; the essay is first-person throughout from the first draft, so there's no agentless-prose-fixed-to-"I" pair to mine here. If that example came from a different Alan Norton essay (the /ai page or manifesto mentioned in the commit log), check there for a real pair.
- **No jargon without definition** — only a weak partial match (the "principals" link to the Anthropic constitution, added `e55f75c`, glosses jargon via hyperlink rather than in-text definition).
- **Lint: "Five consecutive sentences of similar length or similar pressure"** — the essay's paragraphs are short enough that this exact 5-sentence threshold is never triggered; pair 4's 3-sentence version is the closest analog, at a smaller scale.
- **Lint: "A triplet whose third item adds nothing the first two didn't"** — the essay only shows the *good* triplet (pair 6); no essay-sourced example of a bad, decorative triplet (SKILL.md's own contrast example, "remix, retool, reimagine," is not drawn from this essay).
- **"A hedge that protects the writer rather than the fact" / "A reversal used for cleverness rather than argument"** — no bad examples in this history; only good ones (hedges of precision, argument-driven reversals) survive to the final text, which makes sense since we're mining a piece that ended up shipped. If you need negative examples for these two, you'll have to author them synthetically or mine a rougher/earlier draft of a different essay.

**Eval infrastructure.** No eval convention exists yet in the dotfiles repo for skills. Searched for `evals/` directories, test harnesses, and justfile targets; found none belonging to the user's own skills (only third-party plugin eval scaffolding under `.claude/plugins/marketplaces/...` and `.claude/plugins/cache/...`, which is vendored and not a pattern to extend). Building evals for `prose-register` means establishing the convention, not slotting into an existing one — worth deciding format (JSON cases + a runner script? a markdown rubric a human/LLM-judge walks?) before writing the eval file itself.
