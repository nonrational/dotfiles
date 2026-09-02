# Skill Eval Suite Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `code-comment-register` scoring end to end through promptfoo, at parity with its bespoke `run-evals.mjs`, which is then deleted.

**Architecture:** A new top-level `evals/` npm package where promptfoo is the runner. `evals.json` stays canonical next to each `SKILL.md`; a JS test generator (`tests.mjs`) loads it, builds subject prompts, and attaches per-case asserts. The subject provider is a custom JS provider spawning `claude -p` with cwd at the repo root so skills resolve as project skills. Discrimination/detection grade deterministically (ported heuristics); transformation grades via `llm-rubric` against a pinned Anthropic API judge. A gate script enforces "deterministic all pass, suite ≥ 90%".

**Tech Stack:** Node ≥ 22 (`node:test` for unit tests, no test framework dep), promptfoo (only npm dependency, pinned exact), `claude` CLI as the subject harness, Make targets for entry points.

**Spec:** `docs/superpowers/specs/2026-08-29-skill-eval-suite-design.md`

## Global Constraints

- All work happens in the worktree `.worktrees/skill-eval-suite` on branch `skill-eval-suite` (already created; spec commit `5250720` is on it). Commands below assume cwd is the worktree root unless the step says otherwise.
- Commit messages: plain descriptive sentences, NO Conventional Commit prefixes (`feat:`, `fix:` are banned in this repo). End every commit message with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- editorconfig applies to all new files: 2-space indent, LF, UTF-8, final newline, no trailing whitespace. Makefile recipes use tabs.
- `promptfoo` pinned exact-version (`npm install --save-dev --save-exact promptfoo`; 0.122.2 is current at plan time — pin whatever `npm` resolves that day).
- Judge model pinned to `claude-sonnet-5` (Anthropic API direct; needs `ANTHROPIC_API_KEY` in the environment for transformation cases only).
- Subject model defaults to `sonnet` via env `EVAL_MODEL` (matches the old runner's default). Subject auth is the local `claude` CLI login; no key needed.
- `home/.agents/skills/*/evals.json` files are read-only for this plan — never edit them.
- Besides promptfoo, use only Node built-ins (`node:fs`, `node:path`, `node:child_process`, `node:test`, `node:url`, `node:assert`).
- Only `code-comment-register`'s runner is deleted in this plan. `prose-register`'s `run-evals.mjs` and its two extra case types are Phase 2.

## File Structure

```
evals/
  package.json               # promptfoo pinned; scripts: test
  package-lock.json
  .gitignore                 # node_modules/, results/
  promptfooconfig.yaml       # default run: skill condition only
  promptfooconfig.compare.yaml  # skill + baseline conditions side by side
  tests.mjs                  # promptfoo test generator (reads evals.json)
  lib/load-evals.mjs         # locate + parse + validate evals.json
  lib/prompts.mjs            # subject prompt builders + transformation rubric
  providers/subject.mjs      # custom provider spawning `claude -p`
  asserts/heuristics.mjs     # normalize + keywordOverlap (ported)
  asserts/discrimination.mjs # deterministic grader (ported)
  asserts/detection.mjs      # deterministic grader (ported)
  bin/validate.mjs           # offline structural validation (all skills)
  bin/check-gate.mjs         # pass/fail gate over promptfoo results JSON
  test/*.test.mjs            # node:test unit tests
  test/fixtures/stub-claude.sh   # canned `claude -p` stand-in (offline tests)
  test/fixtures/gate-*.json      # synthetic promptfoo results for gate tests
Makefile                     # + eval-validate, eval, eval-compare targets
```

---

### Task 1: Scaffold the evals package

**Files:**
- Create: `evals/package.json` (via npm)
- Create: `evals/package-lock.json` (via npm)
- Create: `evals/.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: an npm package where `npx promptfoo` and `npm test` (node --test) run; later tasks add files into it.

- [ ] **Step 1: Init the package and pin promptfoo**

```bash
mkdir -p evals && cd evals
npm init -y
npm install --save-dev --save-exact promptfoo
```

- [ ] **Step 2: Replace the generated package.json with the curated one**

Overwrite `evals/package.json` (keep the exact promptfoo version npm just wrote in `devDependencies`):

```json
{
  "name": "skill-evals",
  "private": true,
  "type": "module",
  "description": "Promptfoo-based eval suite for skills in home/.agents/skills",
  "scripts": {
    "test": "node --test"
  },
  "devDependencies": {
    "promptfoo": "0.122.2"
  }
}
```

Run `npm install` once more so `package-lock.json` matches the edited manifest.

- [ ] **Step 3: Add evals/.gitignore**

```gitignore
node_modules/
results/
```

- [ ] **Step 4: Verify the toolchain**

Run: `cd evals && npx promptfoo --version && node --test`
Expected: promptfoo prints its version; `node --test` reports 0 tests, exit 0.

- [ ] **Step 5: Commit**

```bash
git add evals/package.json evals/package-lock.json evals/.gitignore
git commit -m "Scaffold evals package with pinned promptfoo

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: evals.json loader and validation

**Files:**
- Create: `evals/lib/load-evals.mjs`
- Test: `evals/test/load-evals.test.mjs`

**Interfaces:**
- Consumes: `home/.agents/skills/*/evals.json` (real files, read-only).
- Produces:
  - `SUPPORTED_TYPES: Set<string>` — `discrimination`, `transformation`, `detection`.
  - `findEvalFiles(repoRoot: string): string[]` — absolute paths of every `home/.agents/skills/*/evals.json`, sorted.
  - `loadEvals(evalsPath: string): object` — parsed JSON (throws on unreadable/unparsable).
  - `validateData(data: object): { caseCount: number, unsupported: {id: string, type: string}[] }` — throws `Error` on structural problems in supported-type cases; unknown types are collected, not fatal (Phase 2 turns them into errors).

- [ ] **Step 1: Write the failing test**

`evals/test/load-evals.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { SUPPORTED_TYPES, findEvalFiles, loadEvals, validateData } from '../lib/load-evals.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

test('findEvalFiles locates both existing suites', () => {
  const files = findEvalFiles(REPO_ROOT);
  const skills = files.map((f) => path.basename(path.dirname(f)));
  assert.ok(skills.includes('code-comment-register'));
  assert.ok(skills.includes('prose-register'));
});

test('code-comment-register evals validate with zero unsupported cases', () => {
  const data = loadEvals(
    path.join(REPO_ROOT, 'home/.agents/skills/code-comment-register/evals.json'),
  );
  const { caseCount, unsupported } = validateData(data);
  assert.equal(caseCount, 16);
  assert.equal(unsupported.length, 0);
});

test('prose-register evals validate, with its two extra types reported as unsupported', () => {
  const data = loadEvals(
    path.join(REPO_ROOT, 'home/.agents/skills/prose-register/evals.json'),
  );
  const { unsupported } = validateData(data);
  const types = new Set(unsupported.map((u) => u.type));
  assert.deepEqual([...types].sort(), ['discrimination-rank', 'discrimination-structural']);
});

test('validateData throws on a duplicate case id', () => {
  const bad = {
    skill: 'x',
    cases: [
      { id: 'a', type: 'transformation', input: 'i', task: 't', reference_after: 'r',
        rubric: { violation_fixed: 'v', placement: 'p', no_new_violation: 'n' } },
      { id: 'a', type: 'transformation', input: 'i', task: 't', reference_after: 'r',
        rubric: { violation_fixed: 'v', placement: 'p', no_new_violation: 'n' } },
    ],
  };
  assert.throws(() => validateData(bad), /Duplicate case id/);
});

test('validateData throws on a discrimination case whose correct key names no variant', () => {
  const bad = {
    skill: 'x',
    cases: [{ id: 'd1', type: 'discrimination', prompt: 'p', expected_rule: 'r',
      variants: { a: '1', b: '2' }, correct: 'zzz' }],
  };
  assert.throws(() => validateData(bad), /does not name a variant/);
});

test('SUPPORTED_TYPES is exactly the three Phase 1 types', () => {
  assert.deepEqual([...SUPPORTED_TYPES].sort(), ['detection', 'discrimination', 'transformation']);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd evals && node --test`
Expected: FAIL — cannot find module `../lib/load-evals.mjs`.

- [ ] **Step 3: Implement the loader**

`evals/lib/load-evals.mjs` — the validation logic is ported from `home/.agents/skills/code-comment-register/run-evals.mjs`, generalized to any skill name and tolerant of unknown case types:

```js
import { readFileSync, readdirSync, existsSync, lstatSync } from 'node:fs';
import path from 'node:path';

export const SUPPORTED_TYPES = new Set(['discrimination', 'transformation', 'detection']);

export function findEvalFiles(repoRoot) {
  const skillsDir = path.join(repoRoot, 'home/.agents/skills');
  const files = [];
  for (const entry of readdirSync(skillsDir)) {
    const dir = path.join(skillsDir, entry);
    // Vendored skills are symlinks into the submodule; only real directories
    // in this repo can carry evals we maintain.
    if (lstatSync(dir).isSymbolicLink() || !lstatSync(dir).isDirectory()) continue;
    const evalsPath = path.join(dir, 'evals.json');
    if (existsSync(evalsPath)) files.push(evalsPath);
  }
  return files.sort();
}

export function loadEvals(evalsPath) {
  return JSON.parse(readFileSync(evalsPath, 'utf8'));
}

function requireField(value, label) {
  if (value === undefined || value === null || value === '') {
    throw new Error(`Missing ${label}`);
  }
}

export function validateData(data) {
  requireField(data.skill, 'skill');
  if (!Array.isArray(data.cases) || data.cases.length === 0) {
    throw new Error('cases must be a non-empty array');
  }

  const ids = new Set();
  const unsupported = [];

  for (const item of data.cases) {
    requireField(item.id, 'case.id');
    requireField(item.type, `${item.id}.type`);
    if (ids.has(item.id)) throw new Error(`Duplicate case id: ${item.id}`);
    ids.add(item.id);

    if (!SUPPORTED_TYPES.has(item.type)) {
      unsupported.push({ id: item.id, type: item.type });
      continue;
    }

    if (item.type === 'discrimination') {
      requireField(item.prompt, `${item.id}.prompt`);
      requireField(item.expected_rule, `${item.id}.expected_rule`);
      if (!item.variants || Object.keys(item.variants).length < 2) {
        throw new Error(`${item.id}.variants must contain at least two choices`);
      }
      if (!Object.hasOwn(item.variants, item.correct)) {
        throw new Error(`${item.id}.correct does not name a variant`);
      }
    }

    if (item.type === 'transformation') {
      requireField(item.input, `${item.id}.input`);
      requireField(item.task, `${item.id}.task`);
      requireField(item.reference_after, `${item.id}.reference_after`);
      for (const key of ['violation_fixed', 'placement', 'no_new_violation']) {
        requireField(item.rubric?.[key], `${item.id}.rubric.${key}`);
      }
    }

    if (item.type === 'detection') {
      requireField(item.prompt, `${item.id}.prompt`);
      requireField(item.input_document, `${item.id}.input_document`);
      if (!Array.isArray(item.violations) || item.violations.length === 0) {
        throw new Error(`${item.id}.violations must be non-empty`);
      }
      if (!Array.isArray(item.traps)) {
        throw new Error(`${item.id}.traps must be an array`);
      }
      for (const violation of item.violations) {
        requireField(violation.quote, `${item.id}.violations[].quote`);
        requireField(violation.rule, `${item.id}.violations[].rule`);
      }
      for (const trap of item.traps) {
        requireField(trap.quote, `${item.id}.traps[].quote`);
        requireField(trap.why_valid, `${item.id}.traps[].why_valid`);
      }
    }
  }

  return { caseCount: data.cases.length, unsupported };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd evals && node --test`
Expected: all 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add evals/lib/load-evals.mjs evals/test/load-evals.test.mjs
git commit -m "Add evals.json loader with structural validation

Ported from the code-comment-register runner, generalized to any skill
and tolerant of case types Phase 1 does not grade yet.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Grading heuristics module

**Files:**
- Create: `evals/asserts/heuristics.mjs`
- Test: `evals/test/heuristics.test.mjs`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `normalize(value: string): string` — lowercase, straighten smart quotes, collapse whitespace.
  - `keywordOverlap(candidate: string, reference: string): number` — 0..1 share of reference keywords present in candidate.

- [ ] **Step 1: Write the failing test**

`evals/test/heuristics.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { normalize, keywordOverlap } from '../asserts/heuristics.mjs';

test('normalize lowercases, straightens smart quotes, collapses whitespace', () => {
  assert.equal(normalize('  “Hello”\n\t‘World’  '), '"hello" \'world\'');
});

test('keywordOverlap is 1 when candidate restates the reference', () => {
  const reference = 'delete generic tradeoffs that do not explain the chosen value';
  assert.equal(keywordOverlap(reference, reference), 1);
});

test('keywordOverlap is 0 for unrelated text', () => {
  assert.equal(keywordOverlap('completely different words entirely', 'delete generic tradeoffs'), 0);
});

test('keywordOverlap ignores stop words and short words', () => {
  // "that", "with", "this" are stop words; "the", "a" are <= 3 chars.
  const score = keywordOverlap('placement decides that', 'that placement with this decides');
  assert.equal(score, 1);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd evals && node --test test/heuristics.test.mjs`
Expected: FAIL — cannot find module `../asserts/heuristics.mjs`.

- [ ] **Step 3: Implement — verbatim port from run-evals.mjs**

`evals/asserts/heuristics.mjs` (bodies ported from `home/.agents/skills/code-comment-register/run-evals.mjs` `normalize`/`keywordOverlap`; keep the stop-word list identical so parity holds):

```js
export function normalize(value) {
  return value
    .toLowerCase()
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/\s+/g, ' ')
    .trim();
}

const STOP_WORDS = new Set([
  'about', 'after', 'against', 'also', 'because', 'before', 'comment', 'does',
  'every', 'from', 'have', 'into', 'only', 'rather', 'that', 'their', 'there',
  'these', 'they', 'this', 'when', 'where', 'which', 'with',
]);

export function keywordOverlap(candidate, reference) {
  const words = (text) =>
    new Set(
      text
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, ' ')
        .split(/\s+/)
        .filter((word) => word.length > 3 && !STOP_WORDS.has(word)),
    );

  const candidateWords = words(candidate);
  const referenceWords = words(reference);
  if (referenceWords.size === 0) return 0;

  let shared = 0;
  for (const word of referenceWords) {
    if (candidateWords.has(word)) shared++;
  }

  return shared / referenceWords.size;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd evals && node --test test/heuristics.test.mjs`
Expected: all 4 PASS.

- [ ] **Step 5: Commit**

```bash
git add evals/asserts/heuristics.mjs evals/test/heuristics.test.mjs
git commit -m "Port grading heuristics from the bespoke runner

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Subject prompt builders

**Files:**
- Create: `evals/lib/prompts.mjs`
- Test: `evals/test/prompts.test.mjs`

**Interfaces:**
- Consumes: case objects from `loadEvals` (Task 2).
- Produces:
  - `buildSubjectPrompt(skillName: string, item: object): { prompt: string, letterToKey?: Record<string,string> }` — dispatches on `item.type`; `letterToKey` present only for discrimination.
  - `buildTransformationRubric(item: object): string` — the llm-rubric text for a transformation case (contains the answer key; never enters the subject prompt).
  - `SKILL_FRAMING: Record<string, {review: string, edit: string, detect: string}>` — per-skill first-line framing; Phase 1 carries only `code-comment-register`. Phase 2 may move this into `evals.json`.

- [ ] **Step 1: Write the failing test**

`evals/test/prompts.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { buildSubjectPrompt, buildTransformationRubric } from '../lib/prompts.mjs';

const SKILL = 'code-comment-register';

test('discrimination prompt letters variants and demands ANSWER/RULE lines', () => {
  const item = {
    id: 'disc-x', type: 'discrimination', prompt: 'Which version follows the register?',
    variants: { first: 'AAA', second: 'BBB' }, correct: 'second', expected_rule: 'r',
  };
  const { prompt, letterToKey } = buildSubjectPrompt(SKILL, item);
  assert.deepEqual(letterToKey, { A: 'first', B: 'second' });
  assert.ok(prompt.startsWith('Review these inline source comments. Use the code-comment-register skill if it is available.'));
  assert.ok(prompt.includes('A.\nAAA'));
  assert.ok(prompt.includes('B.\nBBB'));
  assert.ok(prompt.includes('ANSWER: <letter>'));
  assert.ok(prompt.includes('RULE: <one sentence>'));
  // The answer key never enters the subject prompt.
  assert.ok(!prompt.includes('expected_rule'));
});

test('transformation prompt carries task and input, demands code-only reply', () => {
  const item = { id: 't-x', type: 'transformation', task: 'Do the thing.', input: 'CODE HERE' };
  const { prompt, letterToKey } = buildSubjectPrompt(SKILL, item);
  assert.equal(letterToKey, undefined);
  assert.ok(prompt.startsWith('Edit inline source comments. Use the code-comment-register skill if it is available.'));
  assert.ok(prompt.includes('Do the thing.'));
  assert.ok(prompt.includes('Code:\nCODE HERE'));
  assert.ok(prompt.includes('Reply with only the revised code, nothing else.'));
});

test('detection prompt carries the document and the QUOTE|RULE line format', () => {
  const item = { id: 'd-x', type: 'detection', prompt: 'Find failures.', input_document: 'DOC' };
  const { prompt } = buildSubjectPrompt(SKILL, item);
  assert.ok(prompt.startsWith('Review inline source comments. Use the code-comment-register skill if it is available.'));
  assert.ok(prompt.includes('Code:\nDOC'));
  assert.ok(prompt.includes('- QUOTE: "<exact offending comment text>" | RULE: <rule in your own words>'));
});

test('unknown skill framing throws rather than silently mis-framing', () => {
  assert.throws(
    () => buildSubjectPrompt('mystery-skill', { id: 'x', type: 'detection', prompt: 'p', input_document: 'd' }),
    /No prompt framing/,
  );
});

test('transformation rubric embeds task, reference, and all three criteria', () => {
  const item = {
    id: 't-x', type: 'transformation', task: 'Do the thing.', input: 'IN',
    rule_quote: 'The rule.', reference_after: 'AFTER', grading_note: 'Note.',
    rubric: { violation_fixed: 'VF?', placement: 'PL?', no_new_violation: 'NV?' },
  };
  const rubric = buildTransformationRubric(item);
  for (const needle of ['Do the thing.', 'The rule.', 'AFTER', 'VF?', 'PL?', 'NV?', 'Note.', 'ALL THREE']) {
    assert.ok(rubric.includes(needle), `missing: ${needle}`);
  }
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd evals && node --test test/prompts.test.mjs`
Expected: FAIL — cannot find module `../lib/prompts.mjs`.

- [ ] **Step 3: Implement — prompt text ported verbatim from run-evals.mjs**

`evals/lib/prompts.mjs`. The three subject-prompt templates are byte-for-byte the old runner's (`buildDiscriminationPrompt`, `buildTransformationPrompt`, `buildDetectionPrompt`) with the skill name parameterized — parity in Task 9 depends on this:

```js
export const SKILL_FRAMING = {
  'code-comment-register': {
    review: 'Review these inline source comments.',
    edit: 'Edit inline source comments.',
    detect: 'Review inline source comments.',
  },
};

function framing(skillName) {
  const entry = SKILL_FRAMING[skillName];
  if (!entry) throw new Error(`No prompt framing registered for skill "${skillName}"`);
  return entry;
}

export function buildSubjectPrompt(skillName, item) {
  const frame = framing(skillName);
  const useSkill = `Use the ${skillName} skill if it is available.`;

  if (item.type === 'discrimination') {
    const keys = Object.keys(item.variants);
    const letters = keys.map((_, index) => String.fromCharCode(65 + index));
    const letterToKey = Object.fromEntries(letters.map((letter, index) => [letter, keys[index]]));
    const listing = keys.map((key, index) => `${letters[index]}.\n${item.variants[key]}`).join('\n\n');

    const prompt = `${frame.review} ${useSkill}

${item.prompt}

${listing}

Pick one version. Name the specific rule that decides it.

End with exactly these two lines and nothing after:
ANSWER: <letter>
RULE: <one sentence>`;

    return { prompt, letterToKey };
  }

  if (item.type === 'transformation') {
    return {
      prompt: `${frame.edit} ${useSkill}

${item.task}

Code:
${item.input}

Reply with only the revised code, nothing else.`,
    };
  }

  if (item.type === 'detection') {
    return {
      prompt: `${frame.detect} ${useSkill}

${item.prompt}

Code:
${item.input_document}

List each violation on one line:
- QUOTE: "<exact offending comment text>" | RULE: <rule in your own words>

Reply only with violation lines in that format. Do not explain or mention
comments that pass the register.`,
    };
  }

  throw new Error(`No subject prompt builder for case type "${item.type}"`);
}

export function buildTransformationRubric(item) {
  return `Grade a source-comment rewrite against the rubric. Similar wording to the reference is not required.

Rule:
${item.rule_quote || ''}

Task given to the writer:
${item.task}

Original:
${item.input}

Reference-quality answer:
${item.reference_after}

The output passes ONLY if ALL THREE criteria hold:
1. violation_fixed: ${item.rubric.violation_fixed}
2. placement: ${item.rubric.placement}
3. no_new_violation: ${item.rubric.no_new_violation}

Notes:
${item.grading_note || 'None.'}`;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd evals && node --test test/prompts.test.mjs`
Expected: all 5 PASS.

- [ ] **Step 5: Commit**

```bash
git add evals/lib/prompts.mjs evals/test/prompts.test.mjs
git commit -m "Add subject prompt builders and transformation rubric

Subject prompt templates are ported verbatim from the bespoke runner so
the parity check compares like with like.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Deterministic assert modules

**Files:**
- Create: `evals/asserts/discrimination.mjs`
- Create: `evals/asserts/detection.mjs`
- Test: `evals/test/asserts.test.mjs`

**Interfaces:**
- Consumes: `normalize`, `keywordOverlap` from `evals/asserts/heuristics.mjs` (Task 3).
- Produces: two promptfoo file-assert modules, each `export default (output: string, context: { vars }) => { pass: boolean, score: number, reason: string }`.
  - discrimination vars: `letter_to_key: Record<string,string>`, `correct: string`, `expected_rule: string`.
  - detection vars: `violations: {quote, rule}[]`, `traps: {quote, why_valid}[]`.

- [ ] **Step 1: Write the failing test**

`evals/test/asserts.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import assertDiscrimination from '../asserts/discrimination.mjs';
import assertDetection from '../asserts/detection.mjs';

const discVars = {
  letter_to_key: { A: 'generic_comment', B: 'no_comment' },
  correct: 'no_comment',
  expected_rule: 'No comment is a valid result; delete generic tradeoffs that do not explain the chosen value.',
};

test('discrimination passes on correct letter and overlapping rule', () => {
  const output = 'ANSWER: B\nRULE: Delete the generic tradeoff; no comment is a valid result.';
  const result = assertDiscrimination(output, { vars: discVars });
  assert.equal(result.pass, true);
  assert.equal(result.score, 1);
});

test('discrimination fails on the wrong letter', () => {
  const output = 'ANSWER: A\nRULE: Delete generic tradeoffs; no comment is a valid result.';
  const result = assertDiscrimination(output, { vars: discVars });
  assert.equal(result.pass, false);
  assert.equal(result.score, 0);
});

test('discrimination half-scores a correct letter with an unrelated rule', () => {
  const output = 'ANSWER: B\nRULE: Brevity wins everywhere.';
  const result = assertDiscrimination(output, { vars: discVars });
  assert.equal(result.pass, false);
  assert.equal(result.score, 0.5);
  assert.match(result.reason, /weak rule match/);
});

test('discrimination fails cleanly when no ANSWER line is present', () => {
  const result = assertDiscrimination('I refuse to pick.', { vars: discVars });
  assert.equal(result.pass, false);
  assert.match(result.reason, /No ANSWER line/);
});

const detVars = {
  violations: [
    { quote: 'Larger chunks use more memory. Smaller chunks use more CPU.', rule: 'generic tradeoff' },
    { quote: 'Parse all records and drop the header before writing.', rule: 'mechanical narration' },
  ],
  traps: [
    { quote: '`binary_part/3` returns a view', why_valid: 'surprising runtime behavior' },
  ],
};

test('detection passes on full recall with no trap hits', () => {
  const output = [
    '- QUOTE: "Larger chunks use more memory. Smaller chunks use more CPU." | RULE: generic tradeoff',
    '- QUOTE: "Parse all records and drop the header before writing." | RULE: narration',
  ].join('\n');
  const result = assertDetection(output, { vars: detVars });
  assert.equal(result.pass, true);
  assert.equal(result.score, 1);
});

test('detection fails on a missed violation', () => {
  const output = '- QUOTE: "Larger chunks use more memory. Smaller chunks use more CPU." | RULE: generic tradeoff';
  const result = assertDetection(output, { vars: detVars });
  assert.equal(result.pass, false);
  assert.match(result.reason, /1\/2 violations/);
});

test('detection fails when a trap is flagged', () => {
  const output = [
    '- QUOTE: "Larger chunks use more memory. Smaller chunks use more CPU." | RULE: generic tradeoff',
    '- QUOTE: "Parse all records and drop the header before writing." | RULE: narration',
    '- QUOTE: "`binary_part/3` returns a view" | RULE: needless jargon',
  ].join('\n');
  const result = assertDetection(output, { vars: detVars });
  assert.equal(result.pass, false);
  assert.match(result.reason, /1 trap/);
});

test('detection ignores lines outside the QUOTE format', () => {
  const output = [
    'Here is my analysis of `binary_part/3` returns a view and more.',
    '- QUOTE: "Larger chunks use more memory. Smaller chunks use more CPU." | RULE: generic tradeoff',
    '- QUOTE: "Parse all records and drop the header before writing." | RULE: narration',
  ].join('\n');
  const result = assertDetection(output, { vars: detVars });
  assert.equal(result.pass, true, 'prose mention of a trap outside violation lines must not count');
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd evals && node --test test/asserts.test.mjs`
Expected: FAIL — cannot find the two assert modules.

- [ ] **Step 3: Implement both assert modules — grading logic ported from run-evals.mjs**

`evals/asserts/discrimination.mjs` (port of `gradeDiscrimination`; the old runner's PASS maps to pass, its two REVIEW states map to fail with distinguishing reasons and a 0.5 score for correct-but-weak-rule):

```js
import { keywordOverlap } from './heuristics.mjs';

export default function assertDiscrimination(output, context) {
  const { letter_to_key: letterToKey, correct, expected_rule: expectedRule } = context.vars;
  const answerMatch = output.match(/ANSWER:\s*([A-Za-z])/i);
  const ruleMatch = output.match(/RULE:\s*([^\n]+)/i);

  if (!answerMatch) {
    return { pass: false, score: 0, reason: 'No ANSWER line in output' };
  }

  const chosenKey = letterToKey[answerMatch[1].toUpperCase()];
  const ruleText = ruleMatch ? ruleMatch[1].trim() : '';
  const overlap = ruleText ? keywordOverlap(ruleText, expectedRule) : 0;
  const variantCorrect = chosenKey === correct;
  const pass = variantCorrect && overlap >= 0.2;

  if (pass) {
    return { pass, score: 1, reason: `chose ${chosenKey}; rule overlap ${overlap.toFixed(2)}` };
  }
  if (variantCorrect) {
    return {
      pass: false,
      score: 0.5,
      reason: `correct choice, weak rule match (${overlap.toFixed(2)}): "${ruleText}"`,
    };
  }
  return {
    pass: false,
    score: 0,
    reason: `chose ${chosenKey ?? answerMatch[1]}, expected ${correct}`,
  };
}
```

`evals/asserts/detection.mjs` (port of `gradeDetection`, same 60/40-char normalized-prefix matching):

```js
import { normalize } from './heuristics.mjs';

export default function assertDetection(output, context) {
  const { violations, traps } = context.vars;
  const violationLines = output
    .split('\n')
    .filter((line) => /^-\s*QUOTE:/i.test(line))
    .join('\n');
  const normalized = normalize(violationLines);

  const missed = violations.filter(
    (violation) => !normalized.includes(normalize(violation.quote).slice(0, 60)),
  );
  const trapHits = traps.filter(
    (trap) => normalized.includes(normalize(trap.quote).slice(0, 40)),
  );

  const found = violations.length - missed.length;
  const pass = missed.length === 0 && trapHits.length === 0;
  const score = Math.max(0, (found - trapHits.length) / violations.length);
  const reason = pass
    ? `${found}/${violations.length} violations, 0 traps`
    : `${found}/${violations.length} violations, ${trapHits.length} trap(s) flagged` +
      (missed.length ? `; missed: ${missed.map((m) => m.quote.slice(0, 40)).join(' | ')}` : '') +
      (trapHits.length ? `; traps: ${trapHits.map((t) => t.quote.slice(0, 40)).join(' | ')}` : '');

  return { pass, score, reason };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd evals && node --test test/asserts.test.mjs`
Expected: all 8 PASS.

- [ ] **Step 5: Commit**

```bash
git add evals/asserts/discrimination.mjs evals/asserts/detection.mjs evals/test/asserts.test.mjs
git commit -m "Add deterministic assert modules for discrimination and detection

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Subject provider

**Files:**
- Create: `evals/providers/subject.mjs`
- Create: `evals/test/fixtures/stub-claude.sh` (executable)
- Test: `evals/test/subject-provider.test.mjs`

**Interfaces:**
- Consumes: env `EVAL_CLAUDE_CMD` (default `claude`), `EVAL_MODEL` (default `sonnet`).
- Produces: promptfoo custom provider class (default export) — `constructor(options)` reading `options.config.baseline` and `options.label`; `id(): string`; `callApi(prompt): Promise<{output, cost, tokenUsage} | {error}>`. Spawns the CLI with cwd at the repo root (two levels above `evals/providers/`) so skills resolve as project skills from the checkout.

- [ ] **Step 1: Create the stub CLI fixture**

`evals/test/fixtures/stub-claude.sh`:

```bash
#!/usr/bin/env bash
# Stands in for `claude -p --output-format json` in offline tests: swallows
# the prompt on stdin, echoes a canned result envelope on stdout.
cat > /dev/null
printf '%s' '{"result": "ANSWER: A\nRULE: stub rule", "is_error": false, "total_cost_usd": 0.01, "usage": {"input_tokens": 100, "output_tokens": 20}}'
```

Run: `chmod +x evals/test/fixtures/stub-claude.sh`

- [ ] **Step 2: Write the failing test**

`evals/test/subject-provider.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import SubjectProvider from '../providers/subject.mjs';

const STUB = path.resolve(path.dirname(fileURLToPath(import.meta.url)), 'fixtures/stub-claude.sh');

test('callApi returns the result field from the CLI JSON envelope', async () => {
  process.env.EVAL_CLAUDE_CMD = STUB;
  const provider = new SubjectProvider({ label: 'skill', config: {} });
  const result = await provider.callApi('any prompt');
  assert.equal(result.output, 'ANSWER: A\nRULE: stub rule');
  assert.equal(result.cost, 0.01);
  assert.deepEqual(result.tokenUsage, { total: 120, prompt: 100, completion: 20 });
  delete process.env.EVAL_CLAUDE_CMD;
});

test('provider ids distinguish skill and baseline conditions', () => {
  const skill = new SubjectProvider({ label: 'skill', config: {} });
  const baseline = new SubjectProvider({ label: 'baseline', config: { baseline: true } });
  assert.equal(skill.id(), 'claude-code:skill');
  assert.equal(baseline.id(), 'claude-code:baseline');
});

test('callApi surfaces a spawn failure as an error result, not a throw', async () => {
  process.env.EVAL_CLAUDE_CMD = '/nonexistent/definitely-not-claude';
  const provider = new SubjectProvider({ label: 'skill', config: {} });
  const result = await provider.callApi('any prompt');
  assert.ok(result.error, 'expected an error result');
  delete process.env.EVAL_CLAUDE_CMD;
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd evals && node --test test/subject-provider.test.mjs`
Expected: FAIL — cannot find module `../providers/subject.mjs`.

- [ ] **Step 4: Implement the provider**

`evals/providers/subject.mjs` (CLI arguments match the old runner's `callClaude` exactly — `--allowedTools Skill` for the skill condition, `--disable-slash-commands` for baseline):

```js
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

export default class SubjectProvider {
  constructor(options = {}) {
    this.baseline = options.config?.baseline === true;
    this.label = options.label || (this.baseline ? 'baseline' : 'skill');
  }

  id() {
    return `claude-code:${this.baseline ? 'baseline' : 'skill'}`;
  }

  async callApi(prompt) {
    const cmd = process.env.EVAL_CLAUDE_CMD || 'claude';
    const model = process.env.EVAL_MODEL || 'sonnet';
    const args = this.baseline
      ? ['-p', '--output-format', 'json', '--model', model, '--disable-slash-commands']
      : ['-p', '--output-format', 'json', '--model', model, '--allowedTools', 'Skill'];

    let stdout = '';
    let stderr = '';

    try {
      await new Promise((resolve, reject) => {
        const proc = spawn(cmd, args, { cwd: REPO_ROOT });
        proc.stdout.on('data', (chunk) => (stdout += chunk));
        proc.stderr.on('data', (chunk) => (stderr += chunk));
        proc.on('error', reject);
        proc.on('close', (code) => {
          if (code !== 0) reject(new Error(`${cmd} exited ${code}: ${stderr.slice(0, 2000)}`));
          else resolve();
        });
        proc.stdin.write(prompt);
        proc.stdin.end();
      });

      const parsed = JSON.parse(stdout);
      if (parsed.is_error) {
        return { error: `claude reported an error: ${parsed.result}` };
      }

      const usage = parsed.usage || {};
      const promptTokens = usage.input_tokens || 0;
      const completionTokens = usage.output_tokens || 0;
      return {
        output: parsed.result ?? '',
        cost: parsed.total_cost_usd ?? 0,
        tokenUsage: {
          total: promptTokens + completionTokens,
          prompt: promptTokens,
          completion: completionTokens,
        },
      };
    } catch (error) {
      return { error: String(error.message || error) };
    }
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd evals && node --test test/subject-provider.test.mjs`
Expected: all 3 PASS.

- [ ] **Step 6: Commit**

```bash
git add evals/providers/subject.mjs evals/test/fixtures/stub-claude.sh evals/test/subject-provider.test.mjs
git commit -m "Add claude-code subject provider with offline stub fixture

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Test generator and promptfoo configs

**Files:**
- Create: `evals/tests.mjs`
- Create: `evals/promptfooconfig.yaml`
- Create: `evals/promptfooconfig.compare.yaml`
- Test: `evals/test/generator.test.mjs`

**Interfaces:**
- Consumes: Tasks 2 and 4 (`findEvalFiles`, `loadEvals`, `validateData`, `buildSubjectPrompt`, `buildTransformationRubric`); env `EVAL_SKILL` (required), `EVAL_ONLY` (comma-separated case ids, optional), `EVAL_TYPES` (comma-separated case types, optional).
- Produces: `tests.mjs` default export — async function returning promptfoo test cases shaped:
  - every case: `description: "<id> (<type>)"`, `vars.subject_prompt`, `metadata: { skill, case_id, case_type }`.
  - discrimination: vars `letter_to_key`, `correct`, `expected_rule`; assert `[{ type: 'javascript', value: 'file://asserts/discrimination.mjs' }]`.
  - detection: vars `violations`, `traps`; assert `[{ type: 'javascript', value: 'file://asserts/detection.mjs' }]`.
  - transformation: assert `[{ type: 'llm-rubric', value: <built rubric>, threshold: 0.75, provider: 'anthropic:messages:claude-sonnet-5' }]`.

- [ ] **Step 1: Write the failing test**

`evals/test/generator.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import generateTests from '../tests.mjs';

async function withEnv(env, fn) {
  const saved = {};
  for (const [key, value] of Object.entries(env)) {
    saved[key] = process.env[key];
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  try {
    return await fn();
  } finally {
    for (const [key, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

test('generates all 16 code-comment-register tests with per-type asserts', async () => {
  const tests = await withEnv(
    { EVAL_SKILL: 'code-comment-register', EVAL_ONLY: undefined, EVAL_TYPES: undefined },
    generateTests,
  );
  assert.equal(tests.length, 16);

  const byType = Object.groupBy(tests, (t) => t.metadata.case_type);
  assert.equal(byType.discrimination.length, 10);
  assert.equal(byType.transformation.length, 4);
  assert.equal(byType.detection.length, 2);

  for (const t of byType.discrimination) {
    assert.equal(t.assert[0].type, 'javascript');
    assert.equal(t.assert[0].value, 'file://asserts/discrimination.mjs');
    assert.ok(t.vars.letter_to_key && t.vars.correct && t.vars.expected_rule);
  }
  for (const t of byType.detection) {
    assert.equal(t.assert[0].value, 'file://asserts/detection.mjs');
    assert.ok(Array.isArray(t.vars.violations) && Array.isArray(t.vars.traps));
  }
  for (const t of byType.transformation) {
    assert.equal(t.assert[0].type, 'llm-rubric');
    assert.equal(t.assert[0].threshold, 0.75);
    assert.equal(t.assert[0].provider, 'anthropic:messages:claude-sonnet-5');
    assert.match(t.assert[0].value, /ALL THREE/);
  }

  // Answer-key fields never leak into the subject prompt.
  for (const t of tests) {
    assert.ok(t.vars.subject_prompt.length > 0);
    assert.ok(!t.vars.subject_prompt.includes('reference_after'));
  }
});

test('EVAL_ONLY filters to named case ids', async () => {
  const tests = await withEnv(
    { EVAL_SKILL: 'code-comment-register', EVAL_ONLY: 'disc-01,det-01', EVAL_TYPES: undefined },
    generateTests,
  );
  assert.deepEqual(tests.map((t) => t.metadata.case_id).sort(), ['det-01', 'disc-01']);
});

test('EVAL_TYPES filters to named case types', async () => {
  const tests = await withEnv(
    { EVAL_SKILL: 'code-comment-register', EVAL_TYPES: 'discrimination,detection', EVAL_ONLY: undefined },
    generateTests,
  );
  assert.equal(tests.length, 12);
  assert.ok(tests.every((t) => t.metadata.case_type !== 'transformation'));
});

test('missing EVAL_SKILL is a hard error', async () => {
  await assert.rejects(
    withEnv({ EVAL_SKILL: undefined, EVAL_ONLY: undefined, EVAL_TYPES: undefined }, generateTests),
    /EVAL_SKILL/,
  );
});

test('unknown EVAL_SKILL is a hard error', async () => {
  await assert.rejects(
    withEnv({ EVAL_SKILL: 'no-such-skill', EVAL_ONLY: undefined, EVAL_TYPES: undefined }, generateTests),
    /no evals\.json/,
  );
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd evals && node --test test/generator.test.mjs`
Expected: FAIL — cannot find module `../tests.mjs`.

- [ ] **Step 3: Implement the generator**

`evals/tests.mjs`:

```js
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { findEvalFiles, loadEvals, validateData, SUPPORTED_TYPES } from './lib/load-evals.mjs';
import { buildSubjectPrompt, buildTransformationRubric } from './lib/prompts.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const JUDGE_PROVIDER = 'anthropic:messages:claude-sonnet-5';
const RUBRIC_THRESHOLD = 0.75;

function csvEnv(name) {
  const raw = process.env[name];
  return raw ? raw.split(',').map((s) => s.trim()).filter(Boolean) : null;
}

export default async function generateTests() {
  const skillName = process.env.EVAL_SKILL;
  if (!skillName) {
    throw new Error('EVAL_SKILL is required (e.g. EVAL_SKILL=code-comment-register)');
  }

  const evalsPath = findEvalFiles(REPO_ROOT).find(
    (file) => path.basename(path.dirname(file)) === skillName,
  );
  if (!evalsPath) {
    throw new Error(`no evals.json found for skill "${skillName}" under home/.agents/skills`);
  }

  const data = loadEvals(evalsPath);
  validateData(data);

  const onlyIds = csvEnv('EVAL_ONLY');
  const onlyTypes = csvEnv('EVAL_TYPES');

  const cases = data.cases.filter(
    (item) =>
      SUPPORTED_TYPES.has(item.type) &&
      (!onlyIds || onlyIds.includes(item.id)) &&
      (!onlyTypes || onlyTypes.includes(item.type)),
  );
  if (cases.length === 0) {
    throw new Error('no cases match the EVAL_ONLY / EVAL_TYPES filters');
  }

  return cases.map((item) => {
    const { prompt, letterToKey } = buildSubjectPrompt(data.skill, item);
    const base = {
      description: `${item.id} (${item.type})`,
      vars: { subject_prompt: prompt },
      metadata: { skill: data.skill, case_id: item.id, case_type: item.type },
    };

    if (item.type === 'discrimination') {
      base.vars.letter_to_key = letterToKey;
      base.vars.correct = item.correct;
      base.vars.expected_rule = item.expected_rule;
      base.assert = [{ type: 'javascript', value: 'file://asserts/discrimination.mjs' }];
    } else if (item.type === 'detection') {
      base.vars.violations = item.violations;
      base.vars.traps = item.traps;
      base.assert = [{ type: 'javascript', value: 'file://asserts/detection.mjs' }];
    } else {
      base.assert = [
        {
          type: 'llm-rubric',
          value: buildTransformationRubric(item),
          threshold: RUBRIC_THRESHOLD,
          provider: JUDGE_PROVIDER,
        },
      ];
    }

    return base;
  });
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd evals && node --test test/generator.test.mjs`
Expected: all 5 PASS. (`Object.groupBy` needs Node ≥ 21 — present.)

- [ ] **Step 5: Write both promptfoo configs**

`evals/promptfooconfig.yaml`:

```yaml
# Runner entry point only — test cases live in home/.agents/skills/*/evals.json
# and are generated by tests.mjs. Requires EVAL_SKILL; see Makefile `eval`.
description: Per-skill eval suite (subject runs inside Claude Code)
prompts:
  - '{{subject_prompt}}'
providers:
  - id: file://providers/subject.mjs
    label: skill
tests: file://tests.mjs
```

`evals/promptfooconfig.compare.yaml`:

```yaml
# Skill-on vs skill-off, side by side — the successor to the old runner's
# --compare flag. Costs double the default config; not part of any gate.
description: Per-skill eval suite, skill vs baseline comparison
prompts:
  - '{{subject_prompt}}'
providers:
  - id: file://providers/subject.mjs
    label: skill
  - id: file://providers/subject.mjs
    label: baseline
    config:
      baseline: true
tests: file://tests.mjs
```

- [ ] **Step 6: Offline end-to-end smoke through promptfoo**

Run the deterministic subset against the stub CLI (no API calls, no judge):

```bash
cd evals && mkdir -p results && \
EVAL_CLAUDE_CMD="$PWD/test/fixtures/stub-claude.sh" \
EVAL_SKILL=code-comment-register \
EVAL_TYPES=discrimination,detection \
npx promptfoo eval --no-cache -o results/smoke.json
```

Expected: the run completes with 12 rows; some pass (cases whose correct answer is letter A and whose expected rule overlaps "stub rule" will still fail — that's fine), zero crashes, `results/smoke.json` exists. Then verify row count:

```bash
cd evals && node -e "
const d = require('./results/smoke.json');
const rows = d.results?.results ?? d.results;
if (!Array.isArray(rows) || rows.length !== 12) { console.error('expected 12 rows, got', rows?.length); process.exit(1); }
console.log('smoke ok: 12 rows');"
```

Expected: `smoke ok: 12 rows`. If the results JSON shape differs from both guesses, adjust `bin/check-gate.mjs`'s row extraction in Task 8 to match what this file actually contains — inspect it, don't assume.

- [ ] **Step 7: Commit**

```bash
git add evals/tests.mjs evals/promptfooconfig.yaml evals/promptfooconfig.compare.yaml evals/test/generator.test.mjs
git commit -m "Add promptfoo test generator and runner configs

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Gate script, validate script, Make targets

**Files:**
- Create: `evals/bin/validate.mjs`
- Create: `evals/bin/check-gate.mjs`
- Create: `evals/test/fixtures/gate-pass.json`
- Create: `evals/test/fixtures/gate-det-fail.json`
- Create: `evals/test/fixtures/gate-rate-fail.json`
- Test: `evals/test/check-gate.test.mjs`
- Modify: `Makefile` (append eval targets; update `.PHONY`)

**Interfaces:**
- Consumes: Task 2 loader (validate); promptfoo results JSON from `-o` (gate).
- Produces:
  - `node bin/validate.mjs` — validates every discovered `evals.json`; prints per-skill case counts and unsupported-type warnings; exit 1 only on structural errors. This is what `make eval-validate` runs.
  - `node bin/check-gate.mjs <results.json> [minRate]` — exit 1 if any non-transformation row failed OR overall pass rate < minRate (default 0.90).
  - Make targets: `eval-validate`, `eval SKILL=<name>`, `eval-compare SKILL=<name>`. NOT added to `preflight` (Phase 2).

- [ ] **Step 1: Create the gate fixtures**

`evals/test/fixtures/gate-pass.json` (15/16 with the one failure a transformation → rate 0.9375, deterministic clean):

```json
{
  "results": {
    "results": [
      { "success": true, "testCase": { "metadata": { "case_id": "disc-01", "case_type": "discrimination" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "disc-02", "case_type": "discrimination" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "disc-03", "case_type": "discrimination" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "disc-04", "case_type": "discrimination" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "disc-05", "case_type": "discrimination" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "disc-06", "case_type": "discrimination" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "disc-07", "case_type": "discrimination" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "disc-08", "case_type": "discrimination" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "disc-09", "case_type": "discrimination" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "disc-10", "case_type": "discrimination" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "trans-01", "case_type": "transformation" } } },
      { "success": false, "testCase": { "metadata": { "case_id": "trans-02", "case_type": "transformation" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "trans-03", "case_type": "transformation" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "trans-04", "case_type": "transformation" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "det-01", "case_type": "detection" } } },
      { "success": true, "testCase": { "metadata": { "case_id": "det-02", "case_type": "detection" } } }
    ]
  }
}
```

`evals/test/fixtures/gate-det-fail.json` — copy of gate-pass.json with `disc-01` flipped to `"success": false` and `trans-02` back to `true` (one deterministic failure, rate 0.9375 — must still gate-fail).

`evals/test/fixtures/gate-rate-fail.json` — copy of gate-pass.json with `trans-01` AND `trans-02` set to `"success": false` (deterministic clean, rate 0.875 < 0.90 — must gate-fail).

- [ ] **Step 2: Write the failing test**

`evals/test/check-gate.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const GATE = path.resolve(HERE, '../bin/check-gate.mjs');
const fixture = (name) => path.join(HERE, 'fixtures', name);

function runGate(...args) {
  return spawnSync(process.execPath, [GATE, ...args], { encoding: 'utf8' });
}

test('passes when deterministic rows are clean and rate is above threshold', () => {
  const result = runGate(fixture('gate-pass.json'));
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /15\/16/);
});

test('fails on any deterministic failure even above the rate threshold', () => {
  const result = runGate(fixture('gate-det-fail.json'));
  assert.equal(result.status, 1);
  assert.match(result.stdout + result.stderr, /disc-01/);
});

test('fails when pass rate drops below the threshold', () => {
  const result = runGate(fixture('gate-rate-fail.json'));
  assert.equal(result.status, 1);
  assert.match(result.stdout + result.stderr, /pass rate/i);
});

test('threshold is overridable via argv', () => {
  const result = runGate(fixture('gate-rate-fail.json'), '0.80');
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('unreadable results file is a hard error', () => {
  const result = runGate(fixture('no-such-file.json'));
  assert.equal(result.status, 1);
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd evals && node --test test/check-gate.test.mjs`
Expected: FAIL — `bin/check-gate.mjs` missing.

- [ ] **Step 4: Implement both scripts**

`evals/bin/check-gate.mjs`:

```js
#!/usr/bin/env node
// Gate semantics from the design spec: deterministic cases must all pass;
// judged (transformation) cases only drag the suite below a pass-rate floor.
import { readFileSync } from 'node:fs';

const [, , resultsPath, minRateArg] = process.argv;
const minRate = Number(minRateArg ?? '0.90');

if (!resultsPath) {
  console.error('usage: check-gate.mjs <results.json> [minRate]');
  process.exit(1);
}

let data;
try {
  data = JSON.parse(readFileSync(resultsPath, 'utf8'));
} catch (error) {
  console.error(`cannot read ${resultsPath}: ${error.message}`);
  process.exit(1);
}

const rows = Array.isArray(data.results?.results)
  ? data.results.results
  : Array.isArray(data.results)
    ? data.results
    : null;
if (!rows || rows.length === 0) {
  console.error('unrecognized or empty promptfoo results format');
  process.exit(1);
}

const meta = (row) => row.testCase?.metadata ?? row.metadata ?? {};
const JUDGED_TYPES = new Set(['transformation']);

const deterministicFailures = rows.filter(
  (row) => !row.success && !JUDGED_TYPES.has(meta(row).case_type),
);
const passed = rows.filter((row) => row.success).length;
const passRate = passed / rows.length;

console.log(`${passed}/${rows.length} passed (rate ${(passRate * 100).toFixed(1)}%, floor ${(minRate * 100).toFixed(0)}%)`);

let failed = false;
if (deterministicFailures.length > 0) {
  failed = true;
  console.error('deterministic failures (these always gate):');
  for (const row of deterministicFailures) {
    console.error(`  ${meta(row).case_id ?? '(unknown case)'}`);
  }
}
if (passRate < minRate) {
  failed = true;
  console.error(`pass rate ${(passRate * 100).toFixed(1)}% is below the ${(minRate * 100).toFixed(0)}% floor`);
}

process.exit(failed ? 1 : 0);
```

`evals/bin/validate.mjs`:

```js
#!/usr/bin/env node
// Offline structural validation of every evals.json — zero model calls.
// Unsupported case types warn rather than fail until Phase 2 grades them.
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { findEvalFiles, loadEvals, validateData } from '../lib/load-evals.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

const files = findEvalFiles(REPO_ROOT);
if (files.length === 0) {
  console.error('no evals.json files found under home/.agents/skills');
  process.exit(1);
}

let failed = false;
for (const file of files) {
  const skill = path.basename(path.dirname(file));
  try {
    const { caseCount, unsupported } = validateData(loadEvals(file));
    const warning = unsupported.length
      ? ` (${unsupported.length} case(s) of unsupported type skipped: ${[...new Set(unsupported.map((u) => u.type))].join(', ')})`
      : '';
    console.log(`${skill}: ${caseCount} cases ok${warning}`);
  } catch (error) {
    failed = true;
    console.error(`${skill}: INVALID — ${error.message}`);
  }
}

process.exit(failed ? 1 : 0);
```

- [ ] **Step 5: Run tests and the validator to verify**

Run: `cd evals && node --test test/check-gate.test.mjs && node bin/validate.mjs`
Expected: all 5 gate tests PASS; validator prints both skills ok, `prose-register` with an unsupported-type warning, exit 0.

- [ ] **Step 6: Add Make targets**

Append to `Makefile` (recipes use tabs), after the `preflight` target block:

```make
# Skill eval suite (evals/). eval-validate is offline and free; eval and
# eval-compare spend real API tokens (a headless claude session per case,
# plus judge calls for transformation cases). Phase 2 wires eval-validate
# into preflight and CI; until then all three are manual entry points.
evals/node_modules: evals/package.json evals/package-lock.json
	cd evals && npm ci

eval-validate: evals/node_modules
	cd evals && node bin/validate.mjs

eval: evals/node_modules
	@test -n "$(SKILL)" || { echo "usage: make eval SKILL=<skill-name>"; exit 1; }
	cd evals && mkdir -p results && EVAL_SKILL=$(SKILL) npx promptfoo eval --no-cache -o results/latest.json
	cd evals && node bin/check-gate.mjs results/latest.json

eval-compare: evals/node_modules
	@test -n "$(SKILL)" || { echo "usage: make eval-compare SKILL=<skill-name>"; exit 1; }
	cd evals && EVAL_SKILL=$(SKILL) npx promptfoo eval --no-cache -c promptfooconfig.compare.yaml
```

Add `eval-validate eval eval-compare` to the `.PHONY` line.

- [ ] **Step 7: Verify the Make targets**

Run: `make eval-validate` then `make eval` (no SKILL)
Expected: validate prints both skills ok, exit 0; bare `make eval` prints the usage line and exits 1.

- [ ] **Step 8: Commit**

```bash
git add evals/bin/validate.mjs evals/bin/check-gate.mjs evals/test/fixtures/gate-pass.json evals/test/fixtures/gate-det-fail.json evals/test/fixtures/gate-rate-fail.json evals/test/check-gate.test.mjs Makefile
git commit -m "Add eval gate and validation scripts with Make entry points

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Live parity run against the old runner

This task spends real API tokens (roughly 16 + 16 subject sessions plus ~8 judge calls; expect low single-digit dollars total). It needs the `claude` CLI logged in and `ANTHROPIC_API_KEY` exported for the promptfoo judge.

**Files:**
- No repo files change unless a discrepancy reveals a porting bug (fix in the module at fault, with its unit test updated to pin the fix).

**Interfaces:**
- Consumes: everything from Tasks 1–8; `home/.agents/skills/code-comment-register/run-evals.mjs` (the reference implementation, one last time).
- Produces: recorded parity evidence in the Task 10 commit message (old-runner and promptfoo per-case statuses).

- [ ] **Step 1: Run the old runner as the reference**

```bash
node home/.agents/skills/code-comment-register/run-evals.mjs --model sonnet --judge --out /tmp/old-runner-parity.json
```

Expected: completes; note the per-case PASS/FAIL/REVIEW summary and total cost.

- [ ] **Step 2: Run the promptfoo suite**

```bash
export ANTHROPIC_API_KEY=<key>   # judge only; subject uses the CLI login
make eval SKILL=code-comment-register
```

Expected: 16 rows; gate result printed by check-gate.

- [ ] **Step 3: Compare per-case outcomes**

```bash
node -e "
const old = require('/tmp/old-runner-parity.json');
const now = require('./evals/results/latest.json');
const rows = now.results?.results ?? now.results;
const newById = new Map(rows.map((r) => [(r.testCase?.metadata ?? r.metadata).case_id, r.success]));
for (const r of old.results) {
  const oldPass = r.status === 'PASS';
  const newPass = newById.get(r.id);
  const mark = oldPass === newPass ? 'same' : 'DIFF';
  console.log(\`\${mark}  \${r.id}  old=\${r.status}  new=\${newPass ? 'PASS' : 'FAIL'}\`);
}"
```

Expected: every deterministic case (disc-*, det-*) shows `same` — old REVIEW states count as not-PASS on both sides. Transformation cases may legitimately differ (different judge protocol: old bespoke judge vs promptfoo llm-rubric); for each trans-* DIFF, read the rubric reason in `evals/results/latest.json` and confirm the grade is defensible rather than a plumbing bug.

- [ ] **Step 4: Fix any deterministic discrepancy at the source**

For each deterministic `DIFF`: diff the subject prompt and the grading inputs against the old runner's transcript (`/tmp/old-runner-parity.json` stores `subjectPrompt` per case). The likely culprits are prompt drift (Task 4) or assert porting (Task 5). Fix the module, add or adjust the unit test that should have caught it, re-run `cd evals && node --test`, then re-run only the affected cases:

```bash
cd evals && EVAL_SKILL=code-comment-register EVAL_ONLY=<ids> npx promptfoo eval --no-cache -o results/retry.json
```

Repeat until deterministic parity is clean. Commit any fixes:

```bash
git add -A evals
git commit -m "Fix parity discrepancies found against the bespoke runner

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Record the evidence**

Keep `/tmp/old-runner-parity.json` and `evals/results/latest.json` until Task 10's commit message summarizing the parity outcome is written. Do not commit either file (`results/` is gitignored; the old runner's output holds full transcripts).

---

### Task 10: Retire the old runner, align the spec, preflight

**Files:**
- Delete: `home/.agents/skills/code-comment-register/run-evals.mjs`
- Modify: `docs/superpowers/specs/2026-08-29-skill-eval-suite-design.md` (layout snippet only)

**Interfaces:**
- Consumes: parity evidence from Task 9.
- Produces: the Phase 1 end state — promptfoo is the only runner for `code-comment-register`.

- [ ] **Step 1: Delete the superseded runner**

```bash
git rm home/.agents/skills/code-comment-register/run-evals.mjs
```

Leave `home/.agents/skills/prose-register/run-evals.mjs` alone — it retires in Phase 2.

- [ ] **Step 2: Align the spec's layout snippet with what was built**

In `docs/superpowers/specs/2026-08-29-skill-eval-suite-design.md`, replace the layout code block under "### Layout" with:

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

- [ ] **Step 3: Run the full local suite and preflight**

Run: `cd evals && node --test` then, from the worktree root, `make preflight` and `make eval-validate`
Expected: all unit tests pass; preflight fully green (deploy tests, symlinks, skills, frontmatter, editorconfig, copilot mirrors); validate green.

- [ ] **Step 4: Commit, summarizing parity**

```bash
git add -A
git commit -m "Retire the code-comment-register bespoke runner

Promptfoo suite reached parity: all deterministic cases match the old
runner's outcomes (<fill in: N/N same>), transformation grading moved
to llm-rubric (<fill in: one line on any judged differences and why
they are defensible>).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Replace the two `<fill in: ...>` slots with the actual Task 9 numbers before committing.

---

## Verification (whole plan)

- `cd evals && node --test` — every unit suite green.
- `make eval-validate` — both skills validate; prose-register warns on its two Phase 2 types.
- `make eval SKILL=code-comment-register` — 16 live rows, gate green (allowing ≤1 transformation flake).
- `make preflight` — untouched checks stay green; no dangling symlinks introduced.
- `git log --oneline main..skill-eval-suite` — spec + one commit per task, plain messages, no conventional-commit prefixes.
