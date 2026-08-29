# Skill Eval Suite: Promptfoo Runner for Per-Skill Evals

**Date:** 2026-08-29\
**Status:** Approved design

## TL;DR

Replace the two duplicated per-skill eval runners (`run-evals.mjs` in `prose-register` and `code-comment-register`) with promptfoo as the shared runner. `evals.json` stays the canonical authored format next to each `SKILL.md`; a generator feeds it to promptfoo at runtime. CI validates structure on every push and spends model tokens only on PRs that touch an evaluated skill.

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
  lib/                   # evals.json loader/validation, subject prompt builders
  providers/subject.mjs  # custom JS provider spawning `claude -p` (JS rather than
                         # an exec script: JSON envelope parsing and error surfacing)
  asserts/               # deterministic graders ported from the retired runners
  bin/                   # validate (offline) and check-gate (pass criteria)
```

The schema validation currently embedded in each runner moves into the generator.

### Subject provider

The model under test must run inside Claude Code — a direct API call never sees skills or the Skill tool. The provider is an exec script around `claude -p --output-format json`, cwd at the repo root, so skills resolve as project skills from the checkout. This is the same discovery mechanism the current runners use, and it means CI needs no `$HOME` deploy and no manifest step.

The baseline condition (skill hidden) is a second provider entry passing `--disable-slash-commands`, giving promptfoo's side-by-side view as the skill-on/skill-off compare — the successor to the old `--compare` flag.

**Accepted asymmetry:** locally, the developer's live `~/.claude` global config is also visible to the subject; in CI, `$HOME` is bare. Phase 1 accepts and records this. If it turns out to move scores, the fix is the sandbox-`$HOME` pattern already proven by `test/test_deploy.sh`.

### Grading

The existing heuristics port into per-case asserts the generator emits:

- **discrimination** — deterministic: regex-extract the `ANSWER:` line, javascript assert for the correct variant plus keyword overlap on the stated rule.
- **detection** — deterministic: the existing quote-matching-with-traps logic as a javascript assert (recall against violations, precision against traps).
- **transformation** — `llm-rubric` built from the case's own rubric fields (`violation_fixed`, `placement`, `no_new_violation`), judged by a direct Anthropic API provider. The judge needs no harness; its model is pinned in `promptfooconfig.yaml`.

The answer-key separation holds: the subject prompt never contains `rule_quote`, `expected_rule`, `reference_after`, or rubric fields — those reach only the asserts and the judge.

### Pass criteria

Deterministic cases must all pass. Judged cases carry a per-test threshold, with a suite gate at 90% overall, so one flaky rubric call does not block a PR. Both numbers are Phase-1 guesses to be tuned after the first real runs.

### Make and CI

- `make eval-validate` — generator parses and validates every `evals.json`, zero model calls. Joins `preflight`.
- `make eval SKILL=<name>` — one skill's full suite locally.
- CI: a new job, path-filtered per skill (changes under `home/.agents/skills/<skill>/**` trigger that skill's full run), `ANTHROPIC_API_KEY` from repo secrets, `claude` CLI installed on the runner.

### Retirement

Both `run-evals.mjs` copies are deleted once `code-comment-register` passes at parity with its old runner. Their transcript/`results/` conventions retire with them; promptfoo's own output takes over.

## Phases

- **Phase 1** — `code-comment-register` scoring end to end through promptfoo: layout, generator, subject provider, deterministic asserts, `llm-rubric` for the 4 transformation cases, parity check against the old runner, delete its `run-evals.mjs`. No CI.
- **Phase 2** — `prose-register` (generator support for `discrimination-structural` and `discrimination-rank`), then CI wiring: `eval-validate` into `preflight`, the path-filtered full-run job, secrets.

## Out of scope

- Config-variant matrices beyond skill on/off — Bernard's territory.
- Cross-repo comparison, published scores, badges.
- Judge rubric redesign — the cases' existing rubric fields are used as-is until real runs show what varies.

## Future threads (recorded, not scheduled)

1. Run Bernard against this repo as a subject — the whole-config integration test this per-skill suite cannot be.
2. Bernard's `plan` stage imports a subject's own `evals.json` cases as probes ("does this config pass its own tests?").
3. The full loop: Bernard reports → `find-inspiration` triage → steals land here → this suite pins the stolen behavior against regression.
