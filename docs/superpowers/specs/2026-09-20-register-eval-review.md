# Register eval review: noise or bad evals?

**Date:** 2026-09-20\
**Scope:** `prose-register` eval suite at the tip of PR #68 (`73a9271`), five CI result sets (runs 35468566695, 35475298553, 35475698801, 35476167110, 35476580577), `code-comment-register` as a control.\
**Method:** recomputed every number below from the `latest.json` artifacts with a local script; read every failing subject output and judge reason; no model calls were made.

## Conclusion

Mostly bad evals, with a smaller layer of judge noise on top, and almost no evidence that the model under the skill is unpredictable on the cases that fail.

On the tip run (0577, 10 of 22), 11 of the 12 failures are eval-side: contested or wrong answer keys (4), non-minimal or context-stripped case construction (2), grader defects (3, including both detection cases that fail by design), and a rubric or grading note that the judge applies as a requirement (2). One failure (trans-05) is the subject producing a different rewrite that the judge fairly rejected. Seven cases fail in every run with the same reasoning each time; that is not sampling noise, that is a key the model disagrees with consistently.

The noise that does exist lives almost entirely in the LLM-judged components. Between the two pairs of runs with identical prompts and fixtures, 6 and then 2 rows flipped; of those 8 flips, 1 was a discrimination choice, 7 were judge or grader verdicts. The deterministic choice assert was stable within identical conditions (0 flips in the first pair, 1 in the second).

Rough proportions of the failure mass per run: about 60% deterministic eval defects (keys, construction, graders), about 15% by-design detection failures, about 15 to 20% judge inconsistency, about 5 to 10% subject variance. Confidence: high on the deterministic defects (five identical outcomes with identical reasoning; P(5 of 5 same by chance at p = 0.5) is 3%), medium on the judge share (each row has one judge sample), low on anything about the CI-versus-local gap (no local result files survive).

The suite also does not measure what the operator wants. Fifteen of 22 rows test the model as a critic of the author's edit history. Seven test generation on one-to-three-sentence snippets with the rule named in the task. Zero rows test unprompted drafting under the skill, and zero compare skill-on with skill-off. "Predictable generated prose" is unmeasured today, so fixing the suite's noise would not answer the operator's question either.

## Evidence

### Per-run totals (prose-register)

| run | fixtures / prompt | success | choice | rule (judged) | rubric (judged) | detection | wrong choices |
|---|---|---|---|---|---|---|---|
| 6695 (#67) | disc-01 has "just"; no flags; two-line prompt | 12/22 | 8/12 | 7/12 | 5/7 | 1/3 | disc-01, 09, 11, 12 |
| 8553 | disc-01 fixed; 4 flags; two-line prompt | 10/22 | 9/12 | 7/12 | 5/7 | 0/3 | disc-06, 09, 12 |
| 8801 | same as 8553 | 12/22 | 9/12 | 8/12 | 5/7 | 1/3 | disc-06, 09, 12 |
| 7110 | compare-first prompt | 10/22 | 9/12 | 6/12 | 5/7 | 0/3 | disc-04, 09, 12 |
| 0577 (tip) | same as 7110 plus disc-12 flag | 10/22 | 8/12 | 9/12 | 4/7 | 1/3 | disc-04, 09, 11, 12 |

Discrimination output length tripled after the compare-first change (median 218 to 258 visible characters before, 737 to 762 after). Model was `claude-sonnet-5` on every row that recorded it. Every run shows the skill loaded: 7 of 12 discrimination outputs per run quote SKILL.md wording the prompt never contains ("hedges of cowardice", "joints, not filler", "drumbeat"), and the subject refers to SKILL.md's section heading "The baseline" by name.

### Per-case outcomes across the five runs

| case | pass | choice | rule | rubric/det | what is happening |
|---|---|---|---|---|---|
| disc-01 | 4/5 | 4/5 | 4/5 | | The one miss is the pre-fix fixture (the "just" in `after`). Fixed. |
| disc-02 | 5/5 | 5/5 | 5/5 | | Stable pass. |
| disc-03 | 5/5 | 5/5 | 5/5 | | Stable pass. |
| disc-04 | 3/5 | 3/5 | 5/5 | | Wrong on both compare-first runs, for the reason the case's own note predicts: the connective has nothing to connect to. Construction defect. |
| disc-05 | 5/5 | 5/5 | 5/5 | | Stable pass. |
| disc-06 | 3/5 | 3/5 | 5/5 | | Both misses are self-contradictions under the two-line prompt: `ANSWER: A` with a RULE line saying "B (en-dashes) is on-register". 2 of 2 correct after compare-first. Harness defect, likely fixed. |
| disc-07 | 2/5 | 5/5 | 2/5 | | Judge passed RULE lines that cite only "just" (6695, 8801) and failed ones that cite both "just" and hedges (8553, 7110), the reverse of what the grading note asks. Judge inconsistency, fed by a human-facing note passed to the judge as a rubric. |
| disc-08 | 0/5 | 5/5 | 0/5 | | Choice right every time. RULE fails every time: subject cites the breath rule; key says "Open with substance", which the note itself says both variants satisfy. Key defect. |
| disc-09 | 0/5 | 0/5 | 1/5 | | Ranks `restored` last every run (reported 0 of 10 with local), same reasoning each time: `restored` is five consecutive same-pressure declaratives, which SKILL.md's Lint fails. The key conflicts with the skill. Key defect, deterministic. |
| disc-10 | 0/5 | 5/5 | 0/5 | | Choice right every time. RULE fails every time (breath cited, key says concrete nouns). The master rule absorbs the case. Key or skill-text defect. |
| disc-11 | 0/5 | 3/5 | 1/5 | | The pair differs in two places ("as you assume" and "underleveled"); the subject decides on the first in 3 of 5 runs and the RULE judge fails it. When it picks `before` it argues "underleveled with great reviews" is the concrete detail, which is a defensible reading. Non-minimal pair plus contested key. |
| disc-12 | 0/5 | 0/5 | 4/5 | | Picks `before` every CI run with a coherent argument ("These are hard won lessons" is a summarizing label). Reported 6 of 6 the other way locally. Contested key plus an unexplained environment effect. |
| trans-01 | 5/5 | | | 5/5 | Stable pass. |
| trans-02 | 1/5 | | | 1/5 | Three of four failures are `voice_match` demanding the reference's specific color word ("unsettling"); one is a fair "throat-clearing swapped, not removed". Over-specified rubric. |
| trans-03 | 4/5 | | | 4/5 | The most generative case; one judge rejection on a partial reframe. Judge on a subjective rubric. |
| trans-04 | 5/5 | | | 5/5 | Stable pass. |
| trans-05 | 3/5 | | | 3/5 | Failures cite real differences in the rewrite (drops "character"; reintroduces "caring" as a noun). Subject variance, fairly judged. |
| trans-06 | 1/5 | | | 1/5 | Task asks for "an actual mechanism" only the author knows; the subject invents a Java billing service with a rounding bug and the judge rejects the invention. Case demands facts the subject cannot have. |
| trans-07 | 5/5 | | | 5/5 | Stable pass. |
| det-01 | 0/5 | | | 0/5 | Subject finds 5 to 6 of 12 listed violations each run; pass requires all 12 by substring. By design. |
| det-02 | 0/5 | | | 0/5 | Subject finds 0 to 3 of 7 by substring; the note itself says the list is not exhaustive and the matcher under-scores. By design. |
| det-03 | 3/5 | | | 3/5 | Subject flagged the em-dash for the em-dash rule in all 5 runs. The two "misses" are the substring matcher: the key quote begins "same artifact — one rewrite" and the subject quoted from "artifact — one rewrite". Grader defect. |

### Identical-condition pairs (pure sampling noise)

Runs 8553 and 8801 share prompt and fixtures; so do 7110 and 0577.

- 8553 vs 8801: 6 row flips. Choice 0, rule 1 (disc-07), rubric 4 (trans-02, 03, 05, 06), detection 1 (det-03, grader).
- 7110 vs 0577: 2 row flips. Choice 1 (disc-11), rule 3 (disc-09, 11, 12), rubric 1 (trans-05), detection 1 (det-03, grader). The disc-09 rule flip is the judge passing (0.85) essentially the same breath-rule sentence it failed four times.

Observed SD of run totals: 1.1 rows. Predicted from the per-case rates under independence: 1.36 rows. The runs behave like a fixed set of per-case probabilities, not like a suite whose cases drift.

### Control: code-comment-register

Same five runs: 15, 15, 13, 13, 16 of 16. Choice 10 of 10 on every run; every row flip came from the rule judge (7 to 10 of 10 across runs), one rubric verdict, and one detection trap hit. That is the judge-noise floor on well-constructed, single-rule, anonymized cases: about plus or minus 2 rows in 16. The same judge that is stable enough there is noisy on prose-register because the prose keys give it contestable references and human-facing notes.

## Question 1: noise or bad evals, by source

- **Sampling noise (same case, same conditions, different outcome).** Small on the deterministic assert (1 choice flip in 44 identical-condition comparisons). Present on judged rows: 4 of 7 rubric rows flipped in one identical pair, 1 of 7 in the other. Estimated share of a run's failures: 15 to 25%, all in judged components. Confidence: medium.
- **Key defects.** disc-08 (rule), disc-09 (ranking contradicts the skill's own Lint), disc-10 (rule), disc-11 (contested and non-minimal), disc-12 (contested), disc-04 (context stripped). Six cases, four of them 0 of 5 with identical reasoning each time. Share: about half of each run's failures. Confidence: high.
- **Grader defects.** det-01 and det-02 fail by construction; det-03 fails on quote-boundary substring matching while the subject finds the violation every time. Share: 2 to 3 rows per run. Confidence: high.
- **Judge strictness and inconsistency.** disc-07 (passes the weaker answer, fails the stronger), trans-02 (voice_match reads the reference's color word as required), disc-09's one rule pass. The RULE rubric says "grade only the RULE line" and the judge reads the body anyway (7110 disc-07 reason quotes it). Share: 2 to 3 rows per run. Confidence: medium.
- **Harness and environment.** The two-line prompt produced self-contradictory answers (disc-06, 2 of 3 runs under it); compare-first removed that on 2 of 2 runs. The CI-versus-local gap is real for disc-12 (0 of 5 CI, reported 6 of 6 local; not a coincidence under any single rate) but no local result files survive, so its aggregate size cannot be decomposed here. Share: one row per run today, more before the prompt change. Confidence: low.
- **Inherent unpredictability of the model under the skill.** Visible in trans-05 (different rewrites, fairly judged), disc-11's choice (3 of 5, but on a two-difference pair), and trans-03 (one rejection in five on the most open task). One to two rows per run. Confidence: medium. There is no data at all on generation-side predictability, which is the operator's actual question.

## Question 2: what the suite measures versus what the operator wants

The suite answers "does Sonnet, told to use the skill, agree with the author's revision history when shown the before and after?" It answers that well on sentence-level mechanical cases (disc-02, 03, 05, 06 after the prompt fix, disc-07 choice) and badly on taste cases (disc-08, 09, 11, 12), where the author's final call is one defensible reading among two.

The operator wants "when I draft under this skill, does the prose come out on-register, and does it come out the same way each time?" Nothing in the 22 rows samples a draft. The seven transformation rows name the rule and the fix in the task, so they measure instruction-following on a snippet, not the register's effect on writing. `promptfooconfig.compare.yaml` (skill on versus off) exists and has never run in CI.

A generation-side measurement that answers the operator's question:

- **Inputs:** 6 to 8 drafting prompts of the kind the operator actually issues (a 300 to 500 word post from a bullet outline; an edit pass over a clipped draft; a rewrite of an op-ed paragraph). det-01's and det-02's documents are ready-made edit-pass inputs.
- **Conditions:** skill on and skill off, the existing two providers.
- **Samples:** k = 5 per prompt per condition.
- **Tier 1 scoring, deterministic, zero judge sessions:** em-dash count; "just" as a modifier; the banned-phrase list from SKILL.md; five consecutive sentences within a length band; first-person pronoun present; adverb density; sentence-length distribution (median, share under six words).
- **Tier 2 scoring, judged, four binary items:** flatters the writer; claims the reader's reaction; summary close; floral. One judge call per sample as an informational score, or majority of three if it ever gates.
- **Metrics:** effect = tier-1 violation rate on versus off; predictability = share of prompts where all k samples pass tier 1, plus per-prompt variance of the tier-1 count and tier-2 agreement across the k samples.
- **Cost:** 8 prompts × 5 samples × 2 conditions = 80 subject sessions, plus 80 judge sessions at one call each. About 3.4 full prose runs.

## Question 3: power

With per-case rates taken from the five runs, a run's total has expected value 10.8 and SD 1.36 rows (about 6 points). The 0.4 floor (9 of 22) trips on unchanged code about 4% of the time from the floor alone. The hard choice gate trips far more often: under the two-line prompt, disc-06 alone failed 2 of 3 runs; at the tip flags, the unflagged wrong-choice rate is near zero only because every contested case is now flagged.

Regression detection at one sample per case: if 1 of the 6 reliably-passing cases becomes an always-fail, the floor trips 17% of the time; 2 cases, 41%; 3 cases, 70%; 4 cases, 90%. If 4 reliable cases degrade to coin flips, 43%. The floor detects a collapse of half the reliable cases and nothing smaller.

Per case, 5 samples cannot separate a 90% case from a 60% case (one-sided power 0.32 at alpha 0.05); 10 samples gives 0.62; 20 gives 0.95. Every per-case rate in this memo carries a 95% interval about 0.5 wide (0 of 5 is [0, 0.52]; 3 of 5 is [0.15, 0.95]).

## Question 4: which SKILL.md rules are checkable

Objectively checkable by regex or structure, on generated text:

- No em-dashes (U+2014).
- "Just" as a modifier (with a short adjective exclusion list).
- The named phrases: "In today's world", "It's important to note", "in this essay", "as a writer".
- Five consecutive sentences of similar length (the "or similar pressure" half is judgment).
- Keep the "I" (first-person pronoun count over a text of N words).
- Short sentences never the baseline (median length and share of very short sentences as a proxy).
- Adverb density as a proxy for "strong verbs over adverbs".
- Partial: opening and closing (first sentence contains no listed throat-clearing phrase; last paragraph contains no "In sum", "So,", "In short"). Whether a close "summarizes" is judgment.
- Partial: a hedge phrase list ("I think maybe", "because I believe that", "a decent amount", "really", "sort of"); precision versus cowardice on unlisted hedges is judgment.

Judgment only: the master rule (a hard line needs a breath; a paragraph of jabs), connectives as joints versus filler, the triplet's third item doing work, hedges of cowardice beyond the list, reversal for argument versus cleverness, no flex, never claim the reader's reaction, no grandiosity, nothing floral, no jargon without definition, therapy voice, concrete nouns over abstractions, questions that warm.

The master rule is the problem for the eval. It is broad enough that the subject cites it as the deciding rule on disc-08, 09, 10, 11 and 12, five cases whose keys name five other rules. A judge cannot apply "the same principle" consistently when one principle subsumes the rest. Two fixes, either or both: the eval stops asking for a free-text rule and asks for a pick from SKILL.md's numbered rule list against an `accepted_rules` set (deterministic, removes the judge from 12 rows); and SKILL.md's Lint section splits into "checkable" and "judged" items so a linter enforces the first half. The skill text otherwise reads as a voice guide and should stay one; the eval should stop pretending its judgment rules have single right answers.

## Question 5: the menu

- **Tiering (deterministic hard, judged advisory).** Keep; cheap. Insufficient alone, because the current deterministic tier asks the model to detect em-dashes and the model self-contradicted on that 2 of 3 times under the old prompt. The deterministic tier should be lint over generated prose, not model detection.
- **Variance study first (5 repeats × on/off on the existing suite).** Drop in that form. It costs about 470 sessions to learn what five CI runs already show: seven cases fail identically every time and the flips sit in judged rows. Replace with the generation pilot above, which is the variance study that matters.
- **Minimal synthetic pairs.** Keep for the coverage gaps and to replace disc-04 and disc-11. Zero sessions to author. They pin critic behaviour, not generation, so they belong in the advisory tier.
- **Structured `accepted_rules`.** Keep, and go further to numbered-rule selection so the check is deterministic. Also stop passing `grading_note` to the judge; disc-07 shows the judge treating a human-facing note as a requirement.
- **Judge calibration (20 rows against a human).** Defer. After the changes above the judged surface is the four tier-2 items and trans rubrics; majority-of-three on those costs about 22 extra judge sessions per run and acts on every run, which a one-off calibration does not. A cheaper diagnostic exists first: re-judge the stored transformation outputs from the artifacts three times each (21 judge sessions, zero subject sessions) to split judge noise from subject noise on the 7 trans rows.

### Recommended sequence

1. **Fixture pass, zero model sessions.** Re-key or drop disc-09 (key contradicts the Lint); accept the breath rule or drop the rule check on disc-08 and disc-10; restore a one-difference pair for disc-11; prepend the prior paragraph to disc-04 as its note suggests; put the facts into trans-06's task; rewrite trans-02's `voice_match` to not name the reference's word; state in disc-07's note that either rule passes; fix the detection matcher to search for a shorter core of each quote, and score det-01 and det-02 as recall percentages that never pass or fail. Verify with one CI run (47 sessions). Expected: 16 to 19 of 22 with no model change. If it stays at 10 to 12, the noise is inherent and this memo's conclusion is wrong.
2. **Numbered-rule deterministic RULE check with `accepted_rules`.** Zero sessions to build; verify in the same CI run as step 1 or the next. Removes about 12 judge sessions per run.
3. **Generation pilot** (about 160 sessions, or 80 for tier 1 only). Decides whether the skill changes output and how stable the output is. This is the first measurement of what the operator asked for.
4. **Gate redesign.** Tier-1 lint on generated prose gates hard; the critic suite and tier-2 judgments report a trend and never gate. Keep the `evals` job advisory until five CI runs of the new shape exist.
5. **CI-versus-local gap.** Either the operator runs one local suite with a `claude setup-token` token exported as `CLAUDE_CODE_OAUTH_TOKEN` (47 sessions), or local runs stop being a reference at all. The second is cheaper and the spec already calibrates on CI.

## Ranked recommendations

1. Do the zero-session fixture pass and one CI run before anything else. It settles noise-versus-evals for 47 sessions.
2. Build the generation-side set with skill on and off, k = 5, deterministic lint first. Nothing in the current suite measures predictability.
3. Replace free-text RULE judging with numbered-rule selection and `accepted_rules`; stop feeding `grading_note` to the judge.
4. Move the author's-taste cases (disc-08, disc-09, disc-11, disc-12) out of any gate for good. A key that encodes one defensible reading cannot gate a model that finds the other one.
5. Split SKILL.md's Lint into checkable and judged items, and let a linter own the first half.
6. Drop the 5×2 repeat study of the existing suite and the judge calibration study; spend those sessions on the pilot.

## Decisions for the operator

- Whether the purpose of `evals/` is a regression pin for the critic (keep, tiered, advisory) or a measurement of generated prose (build the pilot). Both can coexist; only the second answers the question in the handoff.
- Re-key or drop disc-09, disc-11 and disc-12; accept the breath rule on disc-08 and disc-10 or drop their rule checks. These are the author's own editorial calls.
- Which model is the subject. The suite runs Sonnet; if the operator drafts with a different model, the generation pilot should run on that one.
- Whether to spend a token on the CI-versus-local test, or drop local as a reference.
- Whether SKILL.md's Lint section may be restructured (checkable versus judged), since it is the author's voice document.

## What I could not determine

- The size and cause of the CI-versus-local gap beyond disc-12. No local result files survive and I ran nothing. The five CI runs are internally consistent, so calibration on CI is sound; the open question is only whether disc-12's local record means anything.
- The split between judge noise and subject noise on the transformation rows. One subject sample and one judge sample per row cannot separate them; re-judging stored outputs would.
- Any number about generation-side predictability. No row measures it.
- Whether the compare-first prompt fixed disc-06 for good: 2 of 2 is all the evidence there is.

## What would change my mind

If, after the fixture pass alone (no prompt or model change), five CI runs still land at 10 to 12 of 22, with the re-keyed cases flipping between runs rather than passing together, the variance is in the model and not in the keys. Equally, if a five-repeat of the tip suite showed disc-08's rule, disc-09, disc-10's rule or disc-12 passing in 2 or more of 5 runs, those are noisy rather than mis-keyed and the "deterministic defect" share above is overstated. On the operator's real question, the pilot could show skill-on and skill-off tier-1 rates indistinguishable at k = 5; then the skill has no measurable effect on drafting and the eval question is secondary to the skill itself.

## Where the handoff's sketch was wrong

- disc-08 is not environment-sensitive; its choice is 5 of 5 in CI and the 0 of 5 is the RULE key.
- disc-06 is not environment-sensitive; the misses are self-contradictions under the two-line prompt, corrected 2 of 2 after compare-first.
- trans-04 is a stable pass (5 of 5), not a coin flip; trans-02 and trans-06 (1 of 5 each) are near-stable fails; trans-05 (3 of 5) is the only transformation row behaving like a coin flip.
- det-03's flips are a grader substring defect; the subject found the em-dash all five times.
- disc-11 is not a "coin-flip judge" case; its choice is 3 of 5 because the pair has two differences.
- The stable-pass class also holds trans-01, trans-04 and trans-07, not only disc-02, 03 and 05.
- disc-07 (rule 2 of 5, judge-inconsistent) was missing from the sketch entirely.

## Errata (2026-09-20, found while acting on this memo)

Rechecked against the same five artifacts during review of the fixture pass. The sections above stand as written; these are the corrections.

- disc-10: the RULE line cited the breath rule on four of five runs, not every run. Run 8553 cited "No flex".
- disc-11: the subject decided on the first difference ("as you assume") in 2 of 5 runs, not 3, and both of those chose correctly. The two wrong choices (6695, 0577) engaged the jargon clause and read "underleveled with great reviews" as the concrete detail, so a one-difference pair leaves that failure mode in place. The same correction applies to the line above about disc-11.
- trans-02: two of four failures are voice_match on the missing color word (6695, 7110), not three. 8553 failed criterion 1 for dropping the developer-backlash claim; 0577 failed it for swapping the throat-clearing rather than removing it.
- trans-06: one run was rejected for an invented mechanism (0577). Two were rejected for naming no mechanism (8801, 7110), one failed voice_match with criteria 1 and 2 passing (6695), and one passed (8553, with an invented ledger service the judge accepted). The task still asked for facts the subject cannot have; "invents a mechanism" describes one run, not the pattern.
- The eight row flips across the two identical-condition pairs are all rule, rubric or detection verdicts. The one choice flip (disc-11, second pair) did not flip its row, because that row failed on the rule in the other run.
