# Eval Cases as Markdown: One File per Case, Approved by Hand

**Date:** 2026-09-25\
**Status:** Approved design; supersedes decision 2 ("`evals.json` stays canonical") in `2026-08-29-skill-eval-suite-design.md`

## TL;DR

Each skill's eval suite moves from one `evals.json` to a directory of Markdown files: `home/.agents/skills/<skill>/evals/README.md` for the suite and one `<id>.md` per case. Structured fields live in YAML frontmatter; every piece of prose (prompt, variants, documents, rewrites, notes) lives in a headed section. A case carries a `status` of `draft` or `approved`, and only approved cases can fail a run. A loader turns the directory into the same case objects the harness already consumes, so the generator, graders and gate keep their shape. All three suites migrate in one PR.

## Problem

The whole value of a suite is that the author has read every case and agrees with every key. JSON works against that in three ways. Multi-line prose collapses into escaped strings, so a variant cannot be read as the comment or passage it is. A pull-request diff shows escaped blobs, so reviewing a case change means decoding it. And nothing in the format records whether a human has signed off on a key, so a drafted case and an approved one look the same to the gate. The September review memo traced most eval failures to case defects; a format that makes each case legible is the cheapest defense.

## Decisions

1. **One file per case, Markdown with YAML frontmatter.** GitHub renders the frontmatter as a table and the sections as prose, so a case reads as a short review exercise and a diff on a case is a diff of sentences.
2. **Prose in sections, keys in frontmatter.** Anything a human reads as text (prompt, variants, stages, input, task, reference, document, rule quote, note, evidence) is a section. Anything the graders compare (`correct`, `correct_ranking`, `expected_rule`, `accepted_rules`, `arguable`, `min_recall`) is frontmatter. Section order is significant for variants and stages: it is the order the subject sees them lettered.
3. **`status` is required and gates.** `approved` means the author has read the case and stands behind its key. `draft` means it runs and is reported but cannot fail the run: a draft row never hard-gates and is excluded from the floor's numerator and denominator. The generator tags every row's metadata with its status; validation and the gate report draft counts. The one exception is a row with no graded components at all: the subject never answered, which measures the harness rather than the key, so it fails the run whatever its status.
4. **The suite's metadata is its `README.md`.** Frontmatter carries `skill` (which must equal the directory's parent name) and `min_pass_rate`. The body is free prose under headings (Description, Provenance, Case types, Coverage gaps, Notes) that the harness never parses. GitHub shows the README when the directory is opened.
5. **The loader produces the existing data shape.** `loadEvals` returns `{ skill, min_pass_rate, cases }` with the same case fields as before; `validateData`, `tests.mjs`, the asserts and `check-gate.mjs` are unchanged except where they name the file. Round-trip equality against the old JSON is the migration's proof.
6. **All three suites migrate at once.** Two authored formats would mean two loaders and two validation paths. The existing `code-comment-register` and `prose-register` cases migrate as `approved` (they carry the author's hand edits and five CI calibration runs); the eighteen new `code-review-register` cases migrate as `draft` and flip to `approved` one at a time as the author reads them.
7. **The migration script is not committed.** Its output is the artifact. The round-trip check and the deletion of the three `evals.json` files are the evidence it ran.

## Layout

```
home/.agents/skills/<skill>/
  SKILL.md
  evals/
    README.md      # suite: frontmatter skill, min_pass_rate; body is prose
    disc-01.md     # one case per file; filename stem equals frontmatter id
    trans-01.md
    det-01.md
```

The `evals/` directory ships with the skill wherever the skill is deployed, as `evals.json` did. Nothing under it is loaded by Claude Code as skill content; only `SKILL.md` is.

## Case file format

Frontmatter fields, all types: `id` (equals the filename stem), `type`, `status`. Per type: discrimination and discrimination-structural add `correct`, `expected_rule`, optional `accepted_rules` (list) and `arguable`; discrimination-rank adds `correct_ranking` (list) and `expected_rule_for_worst`; detection adds optional `min_recall`; transformation adds nothing.

Body sections are H2 headings. Text before the first H2 is the `prompt` for discrimination, rank and detection cases; transformation cases have no prompt and their pre-heading text must be empty. Reserved section names map to fields:

| section | field | types |
|---|---|---|
| `## rule` | `rule_quote` | all |
| `## note` | `grading_note` | all |
| `## evidence` | `evidence` | discrimination |
| `## input` | `input` | transformation |
| `## task` | `task` | transformation |
| `## reference` | `reference_after` | transformation |
| `## rubric` | `rubric` (YAML mapping) | transformation |
| `## document` | `input_document` | detection |
| `## violations` | `violations` (YAML list of `quote`, `rule`, optional `reason`, `anchor`) | detection |
| `## traps` | `traps` (YAML list of `quote`, `why_valid`) | detection |

Every other H2 in a discrimination or structural case is a variant, keyed by the heading text exactly as written, in file order. Reserved headings are lowercase; a capitalized one is an error rather than a variant. In a rank case the same rule produces `stages`. A heading that is neither reserved nor a variant for its type is an error.

Section text is the lines between headings with leading and trailing blank lines removed and interior whitespace preserved. Any section whose whole content is one fenced block is unwrapped, so a section can hold text that Markdown would otherwise mangle: a code variant whose `#` comment lines would render as headings, an indented block, or a detection document that carries its own suggestion fence. The outer fence must be longer than any fence inside it. The migration fences a section when it contains a line starting with `#`, a line starting with whitespace, or a fence, and writes the fence one backtick longer than the longest run inside. The three YAML sections (`rubric`, `violations`, `traps`) are always fenced as ```yaml blocks so their structure survives rendering. Plain prose is written raw. Frontmatter fields the harness does not name (prose-register's per-case `source_*` provenance) pass through the loader unchanged, and list entries under `violations` and `traps` keep whatever keys they have.

An example discrimination case:

```markdown
---
id: disc-01
type: discrimination
status: approved
correct: with_reason
expected_rule: A question carries the reason it is asked or the answer that would resolve it; a bare question is never posted.
---

Which draft follows code-review-register, and which rule decides it?

## rule

Attach the reason you're asking or the answer that would resolve it. Never post a bare question.

## bare

Why does the retry loop start at 1 instead of 0?

## with_reason

Why does the retry loop start at 1 instead of 0? I want to know whether the first attempt is meant to count as a retry, since the log line prints "retry 1" on the very first call.

## note

Both drafts ask the same thing. Only the attached reason differs.
```

## Harness changes

- `evals/lib/load-evals.mjs`: `findEvalFiles` becomes `findSuites`, returning each suite's `README.md` path; `loadEvals(readmePath)` reads the README frontmatter and every sibling `*.md`, parses each into a case, and returns the existing shape. The loader checks that `id` equals the filename stem and that the README's `skill` equals the directory's parent name, since only it sees the filesystem; `validateData` gains the check that `status` is `draft` or `approved`. Frontmatter and the YAML sections parse with the `yaml` package, added as a devDependency.
- `evals/tests.mjs`, `bin/validate.mjs`, `bin/check-gate.mjs`, `bin/affected-skills.mjs`: call the new finder; error messages name `evals/README.md`. The generator adds `status` to each row's metadata.
- `bin/check-gate.mjs`: a row whose metadata `status` is `draft` never hard-gates and is excluded from the floor computation; the summary line reports `n draft rows, m passed` when any exist. `bin/validate.mjs` reports `X cases ok (Y draft)`.
- Tests: a fixture suite under `evals/test/fixtures/suite/` exercises every section kind and the error paths (unknown heading, duplicate section, id mismatch, missing type, non-mapping frontmatter, YAML errors named by file, capitalized reserved heading, unclosed fence) and the verbatim-preservation case of an inner fence that closes the outer one early; the missing-status check is tested through validateData. `check-gate.test.mjs` writes throwaway suites in the new layout. The generator's leak test and the suite-enumeration tests read the new layout.

## Migration

A one-off script reads each `evals.json`, writes `evals/README.md` and one file per case, and deletes the JSON. It sets `status: approved` on `code-comment-register` and `prose-register` cases and `status: draft` on `code-review-register` cases. Proof: loading each new directory deep-equals the old parsed JSON once `status` is removed from every case and the top-level prose fields are dropped, and `make eval-validate` reports the same case counts. No model sessions are needed; CI's `evals` job runs all three suites on the PR because `evals/` changed, and that run is the behavioral check.

## Docs

`CLAUDE.md`'s `make eval` bullet, the comment at the top of `evals/promptfooconfig.yaml`, and decision 2 of the 2026-08-29 spec point at this document. The 2026-08-29 and 2026-09-19 plans are historical and keep their `evals.json` references.

## Out of scope

- Re-keying or reordering any existing case, including the `code-comment-register` suite's correct-answer position bias (all ten pairs list the correct variant second). That is a separate change to a calibrated control suite.
- Rendering or tooling beyond GitHub's own Markdown view.
- The prose-register handoff documents beside its `SKILL.md`; they are historical and unchanged.
