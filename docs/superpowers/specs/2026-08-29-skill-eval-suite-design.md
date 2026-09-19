# Skill Eval Suite: Promptfoo Runner for Per-Skill Evals

**Date:** 2026-08-29\
**Status:** Approved design; Phase 1 shipped (#58); Phase 2 revision approved 2026-09-19

## TL;DR

Replace the two duplicated per-skill eval runners (`run-evals.mjs` in `prose-register` and `code-comment-register`) with promptfoo as the shared runner. `evals.json` stays the canonical authored format next to each `SKILL.md`; a generator feeds it to promptfoo at runtime. CI validates structure on every push and spends model tokens only on PRs that touch an evaluated skill or the suite itself. Every model call, subject and judge, runs through `claude -p` on one subscription token.

## What this is, and what it is not

This suite answers one question: **did my change regress skill behavior I have already pinned down?** The subject is one skill, the config is this repo's, and it changes over time. It is a regression gate, the same species as `make preflight`, just expensive enough that full runs cannot happen on every commit.

It is explicitly not [Bernard](https://github.com/nonrational/bernard), which answers a different question — does a whole config repo (anyone's) measurably change agent behavior, with attribution back to config lines. Bernard snapshots whole repos, sandboxes `$HOME`, runs a task battery against a fixture project, and judges blind. The two projects share nothing but the general shape of "headless `claude -p` plus a judge," which is too thin to justify a shared library. Connective ideas (Bernard importing a subject's own `evals.json` as probes; Bernard runs feeding `find-inspiration` triage) are recorded as future threads, not dependencies.

## Current state

- `home/.agents/skills/code-comment-register/` — `evals.json` (16 cases: 10 discrimination, 4 transformation, 2 detection) + `run-evals.mjs`.
- `home/.agents/skills/prose-register/` — `evals.json` (22 cases, adding `discrimination-structural` and `discrimination-rank` types) + `run-evals.mjs`.
- The two runners are ~90% identical: spawn `claude -p --output-format json` per case, grade discrimination/detection with heuristics, optionally judge transformations with a second model call, write JSON transcripts with cost, support `--compare` (skill available vs. hidden).

## Decisions

1. **Runner: promptfoo**, replacing both `run-evals.mjs` copies. It brings the assertion library, web viewer for eyeballing judge transcripts, run-to-run diffing, caching, and a maintained CI action.
2. **Data: `evals.json` stays canonical.** It carries provenance, evidence maps, answer-key separation, traps, and coverage gaps that promptfoo's native test format has no home for. A generator is the only consumer; cases are never rewritten into promptfoo YAML.
3. **CI: validate always, full runs path-filtered.** Structural validation (zero model calls) joins `preflight`. Full model runs trigger only on PRs touching the evaluated skill's directory.
4. **Phase 1 skill: `code-comment-register`**, because 14 of its 16 cases grade deterministically, making parity with the old runner checkable without judge noise. `prose-register` follows as proof the generator generalizes.

### Phase 2 revisions (2026-09-19)

Phase 1's keyed runs surfaced one flaky grader, and CI planning surfaced an auth constraint. These decisions supersede the matching Phase 1 text below, which has been edited to match.

5. **Discrimination grades the choice hard and the rule soft.** The model picks the correct letter every run, but the ported keyword-overlap check on its stated rule (threshold 0.2) failed a different case each run: a correct paraphrase shares few words with the answer key. The choice (letter, or full ordering for rank cases) stays a deterministic assert that always gates. The stated rule moves to an `llm-rubric` judgment that counts only toward the pass-rate floor. This departs from the byte-for-byte port on purpose.
6. **Every model call runs through `claude -p` on a subscription token.** CI authenticates with a single `CLAUDE_CODE_OAUTH_TOKEN` secret; no `ANTHROPIC_API_KEY` anywhere. The judge becomes a second `claude -p` provider rather than a direct API provider, trading some latency and Claude Code's system prompt in the judge's context for one credential and no API billing.
7. **The CI full-run job starts advisory.** Its thresholds are still Phase 1 guesses; it reports on skill PRs without blocking merge until real runs tune them.
8. **Only the discrimination choice gates hard.** Detection and every judged assert count toward the pass-rate floor; see Pass criteria.
9. **Transformation rubrics list whatever criteria the case defines.** `prose-register` uses `voice_match` where `code-comment-register` uses `placement`; the rubric builder stops hardcoding three keys.

## Architecture

### Layout

A new top-level `evals/` directory — not under `home/`, since nothing here deploys to `$HOME`:

```
evals/
  package.json           # promptfoo pinned as the only dependency
  promptfooconfig.yaml   # runner entry point: provider + tests pointer (no test cases)
  promptfooconfig.compare.yaml  # skill-vs-baseline comparison runs
  tests.mjs              # generator: reads home/.agents/skills/*/evals.json,
                         # emits one promptfoo test per case with per-type asserts
  lib/                   # evals.json loader/validation, subject prompt builders,
                         # claude -p spawning (claude-cli.mjs), affected-skill selection (affected.mjs)
  providers/subject.mjs  # custom JS provider spawning `claude -p` (JS rather than
                         # an exec script: JSON envelope parsing and error surfacing)
  providers/judge.mjs    # custom provider: llm-rubric grader via claude -p
  asserts/               # deterministic graders ported from the retired runners
  bin/                   # validate (offline) and check-gate (pass criteria)
```

The schema validation currently embedded in each runner moves into the generator.

### Subject provider

The model under test must run inside Claude Code — a direct API call never sees skills or the Skill tool. The provider is a custom JS provider (`providers/subject.mjs`) spawning `claude -p --output-format json`, cwd at the repo root. The repo has no root `.claude/`, so skills resolve as user skills: locally through the deployed `~/.claude/skills` symlink into `home/.agents/skills` (the mechanism the retired runners also relied on), and in CI through a job step that links only the skill under test into the runner's `~/.claude/skills`. Without that step the subject silently runs as the baseline. CI needs no full deploy and no manifest step.

The baseline condition (skill hidden) is a second provider entry passing `--disable-slash-commands`, giving promptfoo's side-by-side view as the skill-on/skill-off compare — the successor to the old `--compare` flag.

**Accepted asymmetry:** locally, the developer's live `~/.claude` global config is also visible to the subject; in CI, `$HOME` is bare. Phase 1 accepts and records this. If it turns out to move scores, the fix is the sandbox-`$HOME` pattern already proven by `test/test_deploy.sh`.

### Grading

The existing heuristics port into per-case asserts the generator emits:

- **discrimination** — two asserts. Deterministic: regex-extract the `ANSWER:` line and check the chosen variant against `correct`. Judged: an `llm-rubric` asking whether the `RULE:` line names the same principle as `expected_rule`. (Phase 1 used keyword overlap for the rule; see decision 5.)
- **discrimination-structural** — identical to discrimination; the variants are whole openings or closings rather than sentences.
- **discrimination-rank** — the prompt lists `stages` and asks for an ordering. Deterministic: the full ordering must equal `correct_ranking`. Judged: the rule is compared against `expected_rule_for_worst`.
- **detection** — deterministic: the existing quote-matching-with-traps logic as a javascript assert (recall against violations, precision against traps).
- **transformation** — `llm-rubric` built from whatever rubric fields the case defines (`code-comment-register`: `violation_fixed`, `placement`, `no_new_violation`; `prose-register`: `voice_match` in place of `placement`).

**Judge provider.** Every `llm-rubric` names `providers/judge.mjs`, a custom provider spawning `claude -p` with skills and tools disabled and cwd in a scratch directory, so the repo's skills and its `CLAUDE.md` do not reach the judge; the developer's user config still does locally (see After Phase 2). Its model is pinned in the provider. An offline probe (2026-09-19) confirmed promptfoo 0.122.2 accepts a `file://` custom provider as an `llm-rubric` grader and echoes each assertion, `metric` included, into the result's `componentResults`. The judge cannot use `claude --bare`: bare mode reads only `ANTHROPIC_API_KEY`, never an OAuth token.

The answer-key separation holds: the subject prompt never contains `rule_quote`, `expected_rule`, `reference_after`, or rubric fields — those reach only the asserts and the judge.

### Pass criteria

Every discrimination choice must be correct. Judged asserts carry a per-test threshold, with a suite gate at 90% overall, so one flaky rubric call does not block a PR. Both numbers are Phase-1 guesses to be tuned after the first real runs.

Because a discrimination case now carries both kinds of assert, `check-gate` classifies a failure by which assert failed (promptfoo's per-assert component results), not by case type. The generator tags the one hard assert, the discrimination choice, with `metric: choice`. A case whose `choice` assert failed gates, as does a case whose provider errored before any assert ran. Every other failure counts against the floor.

**Detection gates soft (decision 8).** Detection grades by exact quote match against a fixed violation list. That holds for `code-comment-register`'s short documents, but `prose-register`'s essays carry more true violations than their lists capture, so a correct reviewer quoting a different valid instance fails (its `det-02` grading note records a 0/5 run that found 3 real violations). The old prose runner never failed these cases. Detection failures therefore count against the floor in every skill rather than gating.

### Make and CI

- `make eval-validate` — generator parses and validates every `evals.json`, zero model calls. Joins `preflight` together with the suite's offline unit tests (`cd evals && npm test`), so both block in the existing CI job.
- `make eval SKILL=<name>` — one skill's full suite locally. Locally the developer's logged-in Claude Code session authenticates both subject and judge; `evals/.env` is optional.
- CI: a new `evals` job on pull requests, ubuntu only, advisory (not a required check). It computes the affected skills: a change under `home/.agents/skills/<skill>/**` selects that skill if it has an `evals.json`, and a change under `evals/**` selects every evaluated skill. It runs `make eval SKILL=<name>` per affected skill as a matrix, installs the `claude` CLI from npm, authenticates with `CLAUDE_CODE_OAUTH_TOKEN` from repo secrets, and uploads `evals/results/latest.json` as a build artifact. Runs draw on the subscription's usage limits: roughly 25–30 `claude -p` sessions per skill including judge calls. Repo secrets never reach fork PRs; the job skips cleanly when the secret is absent.

### Retirement

Each skill's `run-evals.mjs` is deleted once that skill passes through promptfoo: `code-comment-register`'s in Phase 1, `prose-register`'s in Phase 2 once every case type (including rank and structural) runs cleanly. Their transcript/`results/` conventions retire with them; promptfoo's own output takes over.

## Phases

- **Phase 1** — `code-comment-register` scoring end to end through promptfoo: layout, generator, subject provider, deterministic asserts, `llm-rubric` for the 4 transformation cases, parity check against the old runner, delete its `run-evals.mjs`. No CI.
- **Phase 2** — in order: verify `claude -p` auth with `CLAUDE_CODE_OAUTH_TOKEN` in CI; the `claude -p` judge provider; split discrimination grading and the assert-aware gate; generator support for `discrimination-structural` and `discrimination-rank`; a keyed `prose-register` run and deletion of its `run-evals.mjs`; CI wiring (`eval-validate` and unit tests into `preflight`, the advisory path-filtered full-run job).
- **After Phase 2** — tune the 90% floor and 0.75 rubric threshold from repeated CI runs, then make the `evals` job a required check. Each is a one-line change once the data exists. Separately, author an `evals.json` for `code-review-register`: its review comments fit the same discrimination, transformation, and detection shapes, and the generator and CI pick it up with no suite changes. Revise three prose-register cases whose answer keys their own grading notes call arguable, all of which failed their hard choice gate in Phase 2's keyed runs: disc-09 (a rank case whose note calls ranking 'original' first defensible; likely gate only on the worst stage), disc-04 (a KNOWN LIMITATION: the connective has nothing to join without its preceding paragraphs; flipped between runs), and disc-11 (answered 'before' in every run). Even with those revised, prose-register sits below the 90% floor: its detection cases are soft by design and expected to fail (substring matching against a fixed list), which alone exhausts the two-failure allowance in 22 rows, so threshold tuning should consider a per-skill floor or excluding detection from it. Isolate eval sessions from the developer's user config locally: in CI the runner's bare $HOME keeps user rules, plugins, and hooks away from subject and judge, but locally every session loads them (user rules, plugin SessionStart preambles, Stop hooks such as a session-cost logger that gains a row per session). Candidate: claude's --setting-sources or --settings flags; verify what each suppresses before relying on it.

## Out of scope

- Config-variant matrices beyond skill on/off — Bernard's territory.
- Cross-repo comparison, published scores, badges.
- Judge rubric redesign — the cases' existing rubric fields are used as-is until real runs show what varies.

## Future threads (recorded, not scheduled)

1. Run Bernard against this repo as a subject — the whole-config integration test this per-skill suite cannot be.
2. Bernard's `plan` stage imports a subject's own `evals.json` cases as probes ("does this config pass its own tests?").
3. The full loop: Bernard reports → `find-inspiration` triage → steals land here → this suite pins the stolen behavior against regression.
