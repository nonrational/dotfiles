# chat-register Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `chat-register` skill that makes drafts of chat and short email replies read like my hand edits, backed by a keyed eval suite.

**Architecture:** Cases first, rule second. A suite of synthetic cases (status `draft`) in a neutral invented domain is written and run without the skill for a baseline; then `SKILL.md` is written to carry the nine rules in the spec, and the suite is rerun. `language.md` gains one entry in its scoped-registers sentence. The author flips cases to `approved`; the agent never does.

**Tech Stack:** Markdown skill and eval cases, the existing `evals/` promptfoo harness (`make eval-validate`, `make eval SKILL=<name>`, `make preflight`).

**Spec:** `docs/superpowers/specs/2026-10-26-chat-register-design.md` (read it first; it holds the nine rules, the open decisions and the coverage gaps).

## Global Constraints

- Skill lives at `home/.agents/skills/chat-register/SKILL.md`; `home/.claude/skills` is a symlink to `../.agents/skills`, so no second copy.
- Frontmatter: `name: chat-register`, plus a `description` that says when to use it (drafting or editing a chat message or short email reply to a colleague) and what it is not (PR comments: `code-review-register`; essays: `prose-register`).
- No project-specific identifiers anywhere in the artifact, per `home/.agents/rules/skill-authoring.md`. Scenarios are invented (log rotation, uploads, deploys, exports). The private source scenario is never named, not even as an example.
- Banned in every file written: em-dashes, "just"/"simply" as modifiers, every word `language.md` bans under "Diction to Avoid", honesty qualifiers, emojis.
- Case files follow the format of `home/.agents/skills/code-review-register/evals/` (`disc-01.md`, `trans-01.md`, `det-01.md`, `README.md`). Read one of each before writing.
- New cases are `status: draft`. Only the author sets `approved`.
- `evals/README.md`-style suite README: frontmatter `skill: chat-register`, `min_pass_rate: 0.75`; sections Description, Provenance, Case types, Coverage gaps, Notes.
- Commits: plain descriptive subjects, no Conventional Commit prefixes, ending with the `Co-Authored-By` line from the session's attribution reminder. Never push or open a PR unless asked.
- Credit: the mining approach (cases before rules, author's edit outranks the reviewer's comment) comes from `mining-review-into-register`, which lives on the unmerged branch `origin/mining-review-into-register`. Mention it in the suite README Provenance as process, not as a fork; no `forked-from` because no text is copied.

## Review Focus

- A draft that opens with thanks and a method summary before the finding (Task 1 `disc-01`, Task 2 lint line).
- A message set whose "N things" count disagrees with the list (`disc-08`).
- A result phrased with "pass"/"verify"/"trust" and no expected outcome (`disc-05`, `trans-02`).
- A reply that answers the asked question and then enumerates every other finding (`disc-09`, `trans-01`).
- A hedge applied to the writer's own measurement, or none applied to a claim about the recipient's intent (`det-01` traps and violations).

## Tasks

### Task 1: Draft eval suite and baseline

**Files:**
- Create: `home/.agents/skills/chat-register/evals/README.md`
- Create: `home/.agents/skills/chat-register/evals/disc-01.md` … `disc-09.md`, `trans-01.md` … `trans-03.md`, `det-01.md`

**Interfaces:**
- Consumes: the case format shown by `code-review-register/evals/*.md`.
- Produces: 13 cases with `status: draft`; Task 2 writes `SKILL.md` to make them pass.

- [ ] **Step 1: Read the format and the harness.** Read `disc-01.md`, `trans-01.md`, `det-01.md`, `README.md` in `home/.agents/skills/code-review-register/evals/`, and `evals/promptfooconfig.yaml` plus `evals/providers/` to learn how the subject loads a skill by `EVAL_SKILL`. Note whether a missing `SKILL.md` errors.
- [ ] **Step 2: Write the nine discrimination cases.** Each is a minimal pair differing in the one rule named; `correct:` is the key. Use this table; invent the draft text.

| id | rule (spec) | scenario | wrong draft | right draft |
|---|---|---|---|---|
| disc-01 | 1 opener | colleague shared a log-rotation script; reviewer found `/var/log/app/archive` skipped | thanks, "I ran it on a test box", then the finding | finding as a one-line observation plus "Is that intentional?" |
| disc-02 | 3 ask vs assert | same script; retention check ignores files older than 30 days | "The retention check is wrong." | asks whether skipping them is deliberate; keeps the observation flat |
| disc-03 | 4 plan not task | same script; no lock file, nightly runs can overlap | "Can you add a lock file?" | "Do you plan to add a lock file ...?" |
| disc-04 | 4 offer | reviewer keeps a cron wrapper of their own | "Is there a standard way to handle this?" | "I can handle that in my own wrapper." |
| disc-05 | 5 expected outcome | upload filter; 7 of 14 sample files get through | "7 of 14 still pass the filter" | "7 of 14 still get through the filter; I expected 0" |
| disc-06 | 6 jargon | importer reachable by web form and SFTP drop | "The second path isn't covered." | names both paths, then says the SFTP drop isn't covered |
| disc-07 | 2 one topic | two unrelated findings | one message, both findings | "Two things:" then one message per finding |
| disc-08 | 2 count | three findings | "Two things:" over three messages | "Three things:" over three messages |
| disc-09 | 8 scope | colleague asked only "can you check this won't break anything?" | answers it plus six unrelated findings | answers the question with the one relevant finding, holds the rest |

- [ ] **Step 3: Write three transformation cases** (`## input`, `## task` stating every usable fact, `## reference`, `## rubric` with `violation_fixed`, `facts_kept`, `no_new_violation`, `## note`).
  - `trans-01`: input is a four-paragraph reply ("Thanks for sharing! I reviewed ... Here are all seven things ..."); facts: the deploy tool skips region `eu-2`, one question was asked, six other findings exist. Output: the next message only, observation plus question.
  - `trans-02`: input "The export check passes for 7 of 14 files." Facts: the check should reject all 14; the author expects 0 accepted. Output states expected versus observed.
  - `trans-03`: input "Please add retries and fix the timeout." Facts: the reviewer can add retries in their own wrapper; the timeout is the author's call. Output: plan question plus offer, side note marked "FWIW".
- [ ] **Step 4: Write `det-01`**: a 6-message chat thread, three violations (a method-summary opener; an assertion about the recipient's intent; a "pass" with no expected outcome) and three traps (a flat first-person measurement; "As I understand it" before a claim about their setup; a backticked identifier with a fenced snippet). Quote fields must match the document verbatim.
- [ ] **Step 5: Write `README.md`** with the section list from Global Constraints. Coverage gaps copied from the spec's last section.
- [ ] **Step 6: Validate.** Run `make eval-validate`. Expected: `chat-register: 13 cases ok (13 draft)` and exit 0.
- [ ] **Step 7: Baseline (RED).** Run `make eval SKILL=chat-register` with no `SKILL.md` (add a frontmatter-only stub if Step 1 showed a missing file errors, and do not commit the stub). Record the draft pass count in the README Notes. A case the bare model already passes is not discriminating; rewrite its wrong draft to be a more tempting default.
- [ ] **Step 8: Commit.** `git add home/.agents/skills/chat-register/evals && git commit -m "Add draft eval cases for chat-register"` (plus the attribution line).

### Task 2: The skill and the language.md entry

**Files:**
- Create: `home/.agents/skills/chat-register/SKILL.md`
- Modify: `home/.agents/rules/language.md` (the sentence beginning `Scoped registers extend this guide`)

**Interfaces:**
- Consumes: the nine rules and open-decision defaults from the spec; the Task 1 cases.
- Produces: a skill the eval harness loads by `EVAL_SKILL=chat-register`.

- [ ] **Step 1: Write `SKILL.md`.** Open with scope (who it is for, what defers to it, what it defers to: `language.md` as base, `code-review-register` for PR comments, `prose-register` for essays). Then the nine rules, each with one invented Bad/Good pair that is not reused from any eval case (the subject loads this text; a reused pair tests recall). End with a short lint list in the style of `prose-register`. Reference `code-review-register` for question-with-a-reason and jargon rather than copying them. Keep the body shorter than the spec plus its examples.
- [ ] **Step 2: Edit `language.md`.** Add `` `chat-register` for chat and short email replies to colleagues`` to the scoped-registers sentence, matching its existing punctuation.
- [ ] **Step 3: GREEN.** Run `make eval SKILL=chat-register`. Expected: the pass rate on the draft rows beats the Task 1 baseline and reaches 0.75. For each failing case, decide whether the rule or the case is wrong; fix the one that is, and never fit the rule to a single case's wording.
- [ ] **Step 4: Regression.** Run `make eval SKILL=code-review-register` and `make eval SKILL=prose-register`. Expected: unchanged from `origin/main` (the `language.md` edit must not move them).
- [ ] **Step 5: Scrub.** Build a pattern from the private terms of the source scenario (the vendor, product, company, and people it names, plus its jargon: the security and network vocabulary of the sender's script). Keep that list out of every committed file, including this plan. Run `grep -rniE '<terms>' home/.agents/skills/chat-register docs/superpowers/specs/2026-10-26-chat-register-design.md docs/superpowers/plans/2026-10-26-chat-register.md`. Expected: no output.
- [ ] **Step 6: Commit.** `git add home/.agents/skills/chat-register/SKILL.md home/.agents/rules/language.md && git commit -m "Add chat-register skill and list it in language.md"`.

### Task 3: Preflight and handoff to the author

**Files:**
- Modify: `home/.agents/skills/chat-register/evals/*.md` (status flips, author only)

- [ ] **Step 1: Preflight.** Run `make preflight`. Expected: exit 0. A prettier or editorconfig diff is committed into the owning commit with `git commit --fixup` and autosquash (see the `atomic-commits` skill).
- [ ] **Step 2: Top-tier review.** Dispatch one Opus reviewer at high effort on the whole branch diff against `origin/main`. Give it the diff and the spec, not this plan's conclusions. Apply accepted findings into the owning commit.
- [ ] **Step 3: Ask the author to resolve the spec's open decisions and flip cases.** Report the pass counts. The author reads each case and sets `status: approved` or edits it; an author edit outranks any rule in `SKILL.md`, so rerun `make eval SKILL=chat-register` after the flips and fix the rule, not the case. Fold the flips into the Task 1 commit via fixup.
- [ ] **Step 4: Prune the worktree** (`git worktree remove .worktrees/chat-register && git worktree prune`) once the author has the branch they want, then stop. Push and PR only on request.

## Self-review notes

- Spec coverage: rules 1 to 9 map to `disc-01`, `disc-07`/`disc-08`, `disc-02`, `disc-03`/`disc-04`, `disc-05`, `disc-06`, backticks (`det-01` trap only), `disc-09`, "FWIW" (`trans-03`). Rule 7 has no discrimination case on purpose (one screenshot of evidence; recorded as a coverage gap).
- Open decisions in the spec are resolved by the author in Task 3 Step 3; Task 2 writes the defaults.
- Recommended execution: subagent-driven, per `prudence.md`. Sonnet implements Tasks 1 and 2 (case and rule prose need judgment, so effort high), Sonnet at high reviews each task, and the Task 3 whole-branch review runs on Opus.
