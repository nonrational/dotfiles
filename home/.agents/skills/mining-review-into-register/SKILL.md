---
name: mining-review-into-register
description: "Use when a pull request's review threads on a draft (a newsletter, a changelog post, an essay) name moves the author dislikes, carry suggestion blocks, or hold dictated notes, and the author wants those turned into rules for a register skill and keyed eval cases in its evals/ suite. Also use when a register skill gained a rule from one review and the suite has no case for it."
---

# Mining review into a register

The review threads hold the author's own before and after text. Each rule you add gets that text as its example, and each case gets the author's call as its key. Cases come first; the rule is written to make them pass. The author's hand edit outranks the review comment it answers: a rule distilled from a comment that the author's own later edit breaks is too wide, and the edit is the key.

## Procedure

1. **Collect the threads with their snapshots.** `gh api repos/<o>/<r>/pulls/<n>/comments --paginate` gives every inline thread with its `original_commit_id`. A force-pushed draft points at a commit no branch reaches; `git cat-file -e <sha>` usually finds the object, and `gh api .../contents/<path>?ref=<sha>` does otherwise. Read every snapshot, the commit that applied the suggestions, and the author's hand edits after it, including edits made after the merge.
2. **Sort each thread by what it gives you** (table below). A dictated note the agent pasted into the draft nearly verbatim, which the author then cut, is a transformation and a rule of its own.
3. **Write the cases before the rule.** One Markdown file per case under the skill's `evals/` (the format is in `docs/superpowers/specs/2026-09-25-eval-cases-markdown-design.md`). Make each pair differ in one place; when the real text differs in several, set the one sentence onto the later paragraph and record the fixture edit in the note. Reduce links to text. Every case is `status: draft` until the author reads the key; taste calls are `arguable`.
4. **RED.** `make eval SKILL=<name>` with `EVAL_ONLY=<new ids>` against the unedited skill. Read the outputs. A pass on a kin rule is fine (list it under `accepted_rules`); a pass for no stated reason tests nothing.
5. **Write the rule** in the skill's own voice, with the draft's before and after as its example. Extend an existing rule when one is a near match. Add the Lint line.
6. **GREEN, then wording passes.** Re-run the new ids. For what stays red, run `--repeat 3` and read every sample before touching anything: a subject that keeps the move in new words needs a rule change; a judge whose reason does not match the text needs the rubric to name the passing shape; a task missing context the reference relied on needs the task fixed.
7. **Full suite** for regressions, then the pinned case count in `evals/test`, the README's provenance (source, commit range, fixture edits, gaps closed, case count), and `make preflight`.
8. **Publish.** Before pushing, grep the diff and PR body for the source repo's name, the PR number, the draft's title and any names in it. The PR comment carries the per-case RED and GREEN numbers; the README says only that they exist.

## What each kind of comment becomes

| Review comment | Case | Key |
|---|---|---|
| Names a move and asks for a ban | discrimination pair | the author's rewrite |
| Suggestion block | single-difference pair, fixture edit noted | the block, verbatim |
| Dictated note the agent pasted, then the author cut | transformation; the task carries the note | what the author kept |
| "Lead with X" on a paragraph | structural pair (same text, reordered) or transformation | the author's final order |
| A whole reviewed snapshot | detection, `min_recall: 0`, traps inside quoted text | every fix the next commits made |
| The author's later hand edit keeps a line a rule flags | detection built from the edit, the flagged lines as traps | the edit, as is; the rule narrows |

## Common mistakes

- **Keeping a rule the author's own edit breaks.** "Lead with the call", distilled from a "burying the lede" comment on one paragraph, flagged a paragraph the author later wrote by hand to build to its closing line. The comment was about verdict paragraphs; the rule said all paragraphs. Narrow the rule to the distinction the edit draws, re-quote its exemplar from the edit, and keep the kept lines as traps.
- **A new ban catches a sanctioned example.** An "announce nothing" rule read the skill's own approved connective as an announcement. After GREEN, re-run the old cases nearest the new rule and carve the exception into the rule.
- **Rewording a prohibition that does not bind.** Three wordings of "don't stage the turn" changed nothing; quoting the on-register pair beside the staged one did. A shaping failure wants the passing shape shown.
- **Blaming the subject for a judge miss.** A rubric that names only the violation fails a correct rewrite longer than the reference. Name the passing shape in the rubric.
- **Marking new keys `approved`.** `draft` runs and reports without gating; the author flips it.
- **Trusting a fresh worktree's preflight.** `git submodule update --init` first, or the vendored-skill symlinks dangle; `git worktree remove --force` after, or the submodule blocks removal.
