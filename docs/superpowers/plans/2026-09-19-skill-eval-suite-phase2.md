# Skill Eval Suite Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `prose-register` grades end to end through promptfoo, discrimination gates only on the choice, every model call runs through `claude -p` on one subscription token, and CI runs the offline checks in `preflight` plus an advisory keyed run for the skills a PR touches.

**Architecture:** A shared `lib/claude-cli.mjs` spawns `claude -p` for both the subject provider and a new judge provider, so no API key is needed anywhere. Discrimination emits two asserts: a deterministic choice check tagged `metric: choice` and an `llm-rubric` rule check. `check-gate` reads promptfoo's per-assert `componentResults` and treats only a failed `choice` assert (or a subject error, which leaves no components) as hard. The generator gains `discrimination-structural` and `discrimination-rank` plus per-skill prompt framing for `prose-register`. A new advisory `evals.yml` workflow computes affected skills and runs `make eval` per skill.

**Tech Stack:** Node ≥ 22 (`node:test`), promptfoo 0.122.2 (pinned; do not bump in this plan), `claude` CLI 2.1.278, GitHub Actions, Make.

**Spec:** `docs/superpowers/specs/2026-08-29-skill-eval-suite-design.md` (read the "Phase 2 revisions" decisions 5–9, "Grading", and "Pass criteria" first).

## Global Constraints

- Work in the worktree `.worktrees/skill-eval-phase2` on branch `skill-eval-phase2` (cut from `origin/main` at `d5b8dcb`; the spec commit is already on it). Commands assume cwd is the worktree root unless a step says otherwise.
- Bootstrap once: `git submodule update --init` (already done) and `cd evals && npm ci`. A worktree without submodules fails `check-symlinks` on dangling skill links; that is a worktree artifact, not a regression.
- Commit messages: plain descriptive sentences, NO Conventional Commit prefixes. End every message with `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`. One task = one commit; fixes within a task amend that task's commit (see the `atomic-commits` skill).
- editorconfig: 2-space indent, LF, final newline, no trailing whitespace; Makefile recipes use tabs.
- `home/.agents/skills/*/evals.json` are read-only in this plan. If a keyed run shows a case is wrong, report it; do not edit the case.
- Judge model pinned to `claude-sonnet-5`, run through `claude -p`. Subject model defaults to `sonnet` via `EVAL_MODEL`. No `ANTHROPIC_API_KEY` anywhere: if one is set in the shell or in `evals/.env`, `claude -p` prefers it over the subscription login and bills the API. Unset it before any keyed run.
- `claude --bare` is off limits for the judge: bare mode reads only `ANTHROPIC_API_KEY`, never an OAuth token.
- Public repo: never commit `evals/.env`, `evals/results/`, stray `eval_*.out` files, or any token value. Never paste a token into this transcript.
- Keyed runs (`make eval`) spend subscription usage. Run them only where a step says so.
- Model per task (name it when dispatching): Tasks 2, 3, 4, 7 Sonnet at high effort; Task 6 Sonnet at low effort; Tasks 1 and 5 run in the main session because they need the user or judgment calls on live results. The final adversarial review before merge runs on Opus (or Fable) at high effort.

## File Structure

```
evals/
  lib/claude-cli.mjs          # NEW: runClaude() — spawn claude -p, parse the JSON envelope
  lib/affected.mjs            # NEW: affectedSkills(changedPaths, evaluatedSkills)
  lib/prompts.mjs             # per-skill framing for prose-register; rank prompts;
                              #   buildRuleRubric(); rubric criteria from the case
  lib/load-evals.mjs          # SUPPORTED_TYPES gains structural + rank; rank validation
  providers/subject.mjs       # delegates to runClaude()
  providers/judge.mjs         # NEW: llm-rubric grader via claude -p, tools and skills off
  asserts/discrimination.mjs  # choice only (letter, or full ranking)
  asserts/heuristics.mjs      # keywordOverlap deleted; normalize stays
  bin/check-gate.mjs          # hard = failed `choice` component or no components
  bin/affected-skills.mjs     # NEW: CLI over lib/affected.mjs for the workflow
  bin/validate.mjs            # comment only
  tests.mjs                   # two asserts per discrimination case; judge provider id
  test/claude-cli.test.mjs    # NEW
  test/judge-provider.test.mjs# NEW
  test/affected.test.mjs      # NEW
  test/fixtures/stub-claude-echo.mjs  # NEW: echoes argv + cwd as the result
  test/fixtures/gate-*.json   # DELETED: check-gate tests build rows inline
.github/workflows/ci.yml      # setup-node before preflight
.github/workflows/evals.yml   # NEW: advisory keyed runs of affected skills
Makefile                      # eval-test target; preflight runs eval-validate + eval-test
CLAUDE.md                     # preflight description; eval entry points
home/.agents/skills/prose-register/run-evals.mjs  # DELETED
```

## Commit series

1. (no commit) Verify subscription auth and skill discovery in a bare `$HOME`
2. `Judge llm-rubric asserts through claude -p`
3. `Gate discrimination on the choice and judge the stated rule`
4. `Grade prose-register's rank and structural cases`
5. `Retire the prose-register bespoke runner`
6. `Run the offline eval checks in preflight`
7. `Run affected skill evals on pull requests`

---

### Task 1: Verify subscription auth and skill discovery in a bare `$HOME`

No code and no commit. This task shows that a `claude -p` with only `CLAUDE_CODE_OAUTH_TOKEN` and one linked skill (the CI setup in Task 7) authenticates and sees the skill, before anything builds on it. The user runs the token-bearing commands in their own terminal so the token never enters the transcript.

**Files:** none.

- [ ] **Step 1: User generates the token and stores the secret**

Ask the user to run these in a separate terminal (not via `!`, since both are interactive):

```bash
claude setup-token                      # browser OAuth; prints a long-lived token
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo nonrational/dotfiles   # paste the token at the prompt
```

Verify (agent may run): `gh secret list --repo nonrational/dotfiles` lists `CLAUDE_CODE_OAUTH_TOKEN`.

- [ ] **Step 2: User runs the bare-`$HOME` probe**

Ask the user to run, from the worktree root, in the same terminal with the token exported (`export CLAUDE_CODE_OAUTH_TOKEN=...` in that shell only):

```bash
unset ANTHROPIC_API_KEY
H=$(mktemp -d); mkdir -p "$H/.claude/skills"
ln -s "$PWD/home/.agents/skills/code-comment-register" "$H/.claude/skills/code-comment-register"
HOME="$H" claude -p --output-format json --allowedTools Skill \
  "List the names of the skills available to you, one per line, nothing else." | jq -r '.is_error, .result'
HOME="$H" CLAUDE_CODE_OAUTH_TOKEN=bogus claude -p --output-format json "Say ok." | jq -r '.is_error, .result'
```

Expected: the first call prints `false` and a list that includes `code-comment-register`. The second call (negative control) fails authentication, which shows the first call authenticated with the real token and not a keychain login.

- [ ] **Step 3: Record the result**

If both expectations hold, continue. If the skill is missing from the list, stop and report: Task 7's skill-link step would not work, and the spec's discovery section needs revisiting. If the negative control succeeds, the probe proves nothing about the token on this machine; note it and rely on Task 7's CI run as the proof.

---

### Task 2: Judge `llm-rubric` asserts through `claude -p`

**Files:**
- Create: `evals/lib/claude-cli.mjs`, `evals/providers/judge.mjs`, `evals/test/claude-cli.test.mjs`, `evals/test/judge-provider.test.mjs`, `evals/test/fixtures/stub-claude-echo.mjs`
- Modify: `evals/providers/subject.mjs` (whole `callApi` body), `evals/tests.mjs` (`JUDGE_PROVIDER` constant), `evals/test/generator.test.mjs` (the `provider` assertion)

**Interfaces:**
- Produces: `runClaude({ args: string[], prompt: string, cwd: string }) => Promise<{ output, cost, tokenUsage } | { error }>` in `lib/claude-cli.mjs`; `JudgeProvider` default export with `id() === 'claude-code:judge'`; `JUDGE_MODEL = 'claude-sonnet-5'` exported from `providers/judge.mjs`; `JUDGE_PROVIDER = 'file://providers/judge.mjs'` in `tests.mjs`.

- [ ] **Step 1: Write the echo stub**

`evals/test/fixtures/stub-claude-echo.mjs`, then `chmod +x` it:

```js
#!/usr/bin/env node
// Stands in for `claude -p` and echoes its argv and cwd back as the result,
// so tests can assert how a provider invokes the CLI without a model call.
process.stdin.resume();
process.stdin.on('end', () => {
  const result = JSON.stringify({ args: process.argv.slice(2), cwd: process.cwd() });
  process.stdout.write(JSON.stringify({ result, is_error: false, total_cost_usd: 0, usage: {} }));
});
```

- [ ] **Step 2: Write the failing tests**

`evals/test/claude-cli.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runClaude } from '../lib/claude-cli.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const STUB = path.join(HERE, 'fixtures/stub-claude.sh');
const ECHO = path.join(HERE, 'fixtures/stub-claude-echo.mjs');

test('runClaude parses the envelope into output, cost, and token usage', async () => {
  process.env.EVAL_CLAUDE_CMD = STUB;
  const result = await runClaude({ args: ['-p'], prompt: 'p', cwd: HERE });
  delete process.env.EVAL_CLAUDE_CMD;
  assert.equal(result.output, 'ANSWER: A\nRULE: stub rule');
  assert.equal(result.cost, 0.01);
  assert.deepEqual(result.tokenUsage, { total: 120, prompt: 100, completion: 20 });
});

test('runClaude passes args through verbatim, empty strings included', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const result = await runClaude({ args: ['-p', '--tools', ''], prompt: 'p', cwd: HERE });
  delete process.env.EVAL_CLAUDE_CMD;
  assert.deepEqual(JSON.parse(result.output).args, ['-p', '--tools', '']);
});

test('runClaude returns an error result on spawn failure instead of throwing', async () => {
  process.env.EVAL_CLAUDE_CMD = '/nonexistent/definitely-not-claude';
  const result = await runClaude({ args: [], prompt: 'p', cwd: HERE });
  delete process.env.EVAL_CLAUDE_CMD;
  assert.ok(result.error);
});
```

`evals/test/judge-provider.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import JudgeProvider, { JUDGE_MODEL } from '../providers/judge.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(HERE, '../..');
const ECHO = path.join(HERE, 'fixtures/stub-claude-echo.mjs');

test('judge disables tools and skills, pins its model, and runs outside the repo', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const { output } = await new JudgeProvider().callApi('grade this');
  delete process.env.EVAL_CLAUDE_CMD;
  const { args, cwd } = JSON.parse(output);
  const tools = args.indexOf('--tools');
  assert.deepEqual(args.slice(tools, tools + 2), ['--tools', '']);
  assert.ok(args.includes('--disable-slash-commands'));
  assert.ok(!args.includes('--bare'), '--bare ignores OAuth tokens');
  assert.equal(args[args.indexOf('--model') + 1], JUDGE_MODEL);
  assert.equal(JUDGE_MODEL, 'claude-sonnet-5');
  assert.ok(!cwd.startsWith(REPO_ROOT), `judge cwd ${cwd} is inside the repo`);
});

test('judge id is stable for promptfoo result attribution', () => {
  assert.equal(new JudgeProvider().id(), 'claude-code:judge');
});
```

In `evals/test/generator.test.mjs`, change:

```js
    assert.equal(t.assert[0].provider, 'anthropic:messages:claude-sonnet-5');
```

to:

```js
    assert.equal(t.assert[0].provider, 'file://providers/judge.mjs');
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd evals && npm test`
Expected: FAIL — `Cannot find module '../lib/claude-cli.mjs'`, `'../providers/judge.mjs'`, and the generator provider mismatch.

- [ ] **Step 4: Implement**

`evals/lib/claude-cli.mjs`:

```js
import { spawn } from 'node:child_process';

// Subject and judge both run a headless Claude Code session, so every model
// call rides the same subscription auth and no API key is needed.
export async function runClaude({ args, prompt, cwd }) {
  const cmd = process.env.EVAL_CLAUDE_CMD || 'claude';
  let stdout = '';
  let stderr = '';

  try {
    await new Promise((resolve, reject) => {
      const proc = spawn(cmd, args, { cwd });
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
```

`evals/providers/subject.mjs` becomes:

```js
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runClaude } from '../lib/claude-cli.mjs';

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
    const model = process.env.EVAL_MODEL || 'sonnet';
    const args = this.baseline
      ? ['-p', '--output-format', 'json', '--model', model, '--disable-slash-commands']
      : ['-p', '--output-format', 'json', '--model', model, '--allowedTools', 'Skill'];
    return runClaude({ args, prompt, cwd: REPO_ROOT });
  }
}
```

`evals/providers/judge.mjs`:

```js
import os from 'node:os';
import { runClaude } from '../lib/claude-cli.mjs';

export const JUDGE_MODEL = 'claude-sonnet-5';

// Grades llm-rubric asserts. Tools and skills are off, and cwd sits outside
// the repo, so neither this repo's skills nor its CLAUDE.md reach the judge.
// Not --bare: bare mode ignores the OAuth token CI authenticates with.
export default class JudgeProvider {
  id() {
    return 'claude-code:judge';
  }

  async callApi(prompt) {
    const model = process.env.EVAL_JUDGE_MODEL || JUDGE_MODEL;
    const args = [
      '-p', '--output-format', 'json', '--model', model,
      '--tools', '', '--disable-slash-commands', '--no-session-persistence',
    ];
    return runClaude({ args, prompt, cwd: os.tmpdir() });
  }
}
```

In `evals/tests.mjs`, change:

```js
const JUDGE_PROVIDER = 'anthropic:messages:claude-sonnet-5';
```

to:

```js
const JUDGE_PROVIDER = 'file://providers/judge.mjs';
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd evals && npm test`
Expected: PASS, all tests (the existing `subject-provider.test.mjs` passes unchanged).

- [ ] **Step 6: One keyed judge call**

```bash
unset ANTHROPIC_API_KEY
cd evals && EVAL_ONLY=trans-01 EVAL_SKILL=code-comment-register npx promptfoo eval --no-cache -o results/latest.json
node -e "const r=require('./results/latest.json').results.results[0]; console.log(r.success, r.error, JSON.stringify(r.gradingResult?.componentResults?.map(c=>[c.pass,c.reason])))"
```

Expected: one row whose `llm-rubric` component carries a prose `reason` from the judge (pass or fail both acceptable). Failure signals: a reason like "Could not extract JSON" means promptfoo could not parse the judge's reply. In that case, append `\n\nReply with only the JSON object.` to the prompt inside `JudgeProvider.callApi` (`runClaude({ args, prompt: \`${prompt}\n\nReply with only the JSON object.\`, cwd: os.tmpdir() })`), add a judge test asserting the suffix, and rerun.

- [ ] **Step 7: Commit**

```bash
git add evals/lib/claude-cli.mjs evals/providers evals/tests.mjs evals/test
git commit -F - <<'EOF'
Judge llm-rubric asserts through claude -p

The judge now runs as a second claude -p provider with tools and skills
off, outside the repo, so subject and judge share one subscription auth
and no ANTHROPIC_API_KEY is needed. The spawn-and-parse logic both
providers need moves to lib/claude-cli.mjs.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
```

---

### Task 3: Gate discrimination on the choice and judge the stated rule

**Files:**
- Modify: `evals/asserts/discrimination.mjs` (whole file), `evals/asserts/heuristics.mjs` (delete `STOP_WORDS` and `keywordOverlap`), `evals/lib/prompts.mjs` (append `buildRuleRubric`), `evals/tests.mjs` (discrimination and transformation branches), `evals/bin/check-gate.mjs` (whole file)
- Modify tests: `evals/test/asserts.test.mjs` (discrimination tests), `evals/test/heuristics.test.mjs` (delete `keywordOverlap` tests), `evals/test/prompts.test.mjs` (append), `evals/test/generator.test.mjs` (discrimination and transformation loops), `evals/test/check-gate.test.mjs` (whole file)
- Delete: `evals/test/fixtures/gate-pass.json`, `gate-det-fail.json`, `gate-rate-fail.json`

**Interfaces:**
- Consumes: `JUDGE_PROVIDER` and `RUBRIC_THRESHOLD` in `tests.mjs` (Task 2).
- Produces: `buildRuleRubric(item) => string` in `lib/prompts.mjs`; discrimination tests carry `assert[0] = { type: 'javascript', value: 'file://asserts/discrimination.mjs', metric: 'choice' }` and `assert[1] = { type: 'llm-rubric', metric: 'rule', provider: JUDGE_PROVIDER, threshold: RUBRIC_THRESHOLD, value: buildRuleRubric(item) }`; transformation asserts carry `metric: 'rubric'`. `check-gate` hard-fails only on a failed component with `assertion.metric === 'choice'`, or a failed row with no components.

- [ ] **Step 1: Write the failing tests**

In `evals/test/asserts.test.mjs`, replace the four discrimination tests and `discVars` (lines 6–38) with:

```js
const discVars = {
  letter_to_key: { A: 'generic_comment', B: 'no_comment' },
  correct: 'no_comment',
};

test('discrimination passes on the correct letter whatever the rule says', () => {
  const output = 'ANSWER: B\nRULE: Brevity wins everywhere.';
  const result = assertDiscrimination(output, { vars: discVars });
  assert.equal(result.pass, true);
  assert.equal(result.score, 1);
});

test('discrimination fails on the wrong letter', () => {
  const result = assertDiscrimination('ANSWER: A\nRULE: whatever', { vars: discVars });
  assert.equal(result.pass, false);
  assert.equal(result.score, 0);
  assert.match(result.reason, /expected no_comment/);
});

test('discrimination fails cleanly when no ANSWER line is present', () => {
  const result = assertDiscrimination('I refuse to pick.', { vars: discVars });
  assert.equal(result.pass, false);
  assert.match(result.reason, /No ANSWER line/);
});
```

In `evals/test/heuristics.test.mjs`, change the import to `import { normalize } from '../asserts/heuristics.mjs';` and delete the three `keywordOverlap` tests (lines 9–22).

Append to `evals/test/prompts.test.mjs` (and add `buildRuleRubric` to its import from `../lib/prompts.mjs`):

```js
test('rule rubric grades only the RULE line against the reference rule', () => {
  const item = { id: 'd', type: 'discrimination', expected_rule: 'Explain why, not what.', rule_quote: 'Quote.' };
  const rubric = buildRuleRubric(item);
  assert.match(rubric, /RULE:/);
  assert.ok(rubric.includes('Explain why, not what.'));
  assert.ok(rubric.includes('Quote.'));
  assert.match(rubric, /Ignore which option was chosen/);
});
```

In `evals/test/generator.test.mjs`, replace the discrimination loop and the transformation loop:

```js
  for (const t of byType.discrimination) {
    assert.deepEqual(t.assert[0], {
      type: 'javascript', value: 'file://asserts/discrimination.mjs', metric: 'choice',
    });
    assert.equal(t.assert[1].type, 'llm-rubric');
    assert.equal(t.assert[1].metric, 'rule');
    assert.equal(t.assert[1].provider, 'file://providers/judge.mjs');
    assert.ok(t.vars.letter_to_key && t.vars.correct);
    assert.equal(t.vars.expected_rule, undefined, 'the rule reaches only the judge');
  }
```

```js
  for (const t of byType.transformation) {
    assert.equal(t.assert[0].type, 'llm-rubric');
    assert.equal(t.assert[0].metric, 'rubric');
    assert.equal(t.assert[0].threshold, 0.75);
    assert.equal(t.assert[0].provider, 'file://providers/judge.mjs');
    assert.match(t.assert[0].value, /ALL THREE/);
  }
```

Replace `evals/test/check-gate.test.mjs` entirely:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import os from 'node:os';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const GATE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../bin/check-gate.mjs');

// Rows mirror promptfoo 0.122.2 output: each assert echoes into
// gradingResult.componentResults with its `metric`; a subject error leaves
// no components at all.
const choice = (pass) => ({ pass, assertion: { type: 'javascript', metric: 'choice' } });
const rule = (pass) => ({ pass, assertion: { type: 'llm-rubric', metric: 'rule' } });
const detect = (pass) => ({ pass, assertion: { type: 'javascript' } });
const row = (id, components) => ({
  success: components.length > 0 && components.every((c) => c.pass),
  testCase: { metadata: { case_id: id } },
  gradingResult: components.length ? { componentResults: components } : null,
});
const passing = (n) => Array.from({ length: n }, (_, i) => row(`ok-${i}`, [choice(true), rule(true)]));

function runGate(rows, ...args) {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'gate-'));
  const file = path.join(dir, 'results.json');
  writeFileSync(file, JSON.stringify({ results: { results: rows } }));
  return spawnSync(process.execPath, [GATE, file, ...args], { encoding: 'utf8' });
}

test('a failed rule judgment is soft: passes at the floor', () => {
  const result = runGate([...passing(9), row('disc-07', [choice(true), rule(false)])]);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /9\/10/);
});

test('a failed detection is soft: passes at the floor', () => {
  const result = runGate([...passing(9), row('det-02', [detect(false)])]);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('a wrong choice gates even above the floor', () => {
  const result = runGate([...passing(19), row('disc-01', [choice(false), rule(true)])]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /disc-01/);
});

test('a subject error gates because no assert ran', () => {
  const result = runGate([...passing(19), row('disc-02', [])]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /disc-02/);
});

test('soft failures below the floor fail the gate', () => {
  const soft = [1, 2, 3].map((i) => row(`trans-0${i}`, [rule(false)]));
  const result = runGate([...passing(7), ...soft]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /pass rate/i);
});

test('the floor is overridable via argv', () => {
  const soft = [1, 2, 3].map((i) => row(`trans-0${i}`, [rule(false)]));
  const result = runGate([...passing(7), ...soft], '0.70');
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('an unreadable results file is a hard error', () => {
  const result = spawnSync(process.execPath, [GATE, '/nonexistent/results.json'], { encoding: 'utf8' });
  assert.equal(result.status, 1);
});
```

Delete the three `evals/test/fixtures/gate-*.json` files.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd evals && npm test`
Expected: FAIL: the old discrimination assert rejects `Brevity wins everywhere.`; `buildRuleRubric` is not exported; generator asserts lack `metric`; the gate treats the `det-02` and `disc-02` rows by case type.

- [ ] **Step 3: Implement**

`evals/asserts/discrimination.mjs`:

```js
// Grades only the choice. The stated rule is judged by a separate llm-rubric
// assert: keyword overlap failed correct paraphrases at random.
export default function assertDiscrimination(output, context) {
  const { letter_to_key: letterToKey, correct } = context.vars;
  const answerMatch = output.match(/ANSWER:\s*([A-Za-z])/i);

  if (!answerMatch) {
    return { pass: false, score: 0, reason: 'No ANSWER line in output' };
  }

  const chosenKey = letterToKey[answerMatch[1].toUpperCase()];
  if (chosenKey === correct) {
    return { pass: true, score: 1, reason: `chose ${chosenKey}` };
  }
  return { pass: false, score: 0, reason: `chose ${chosenKey ?? answerMatch[1]}, expected ${correct}` };
}
```

`evals/asserts/heuristics.mjs`: delete `STOP_WORDS` and `keywordOverlap` (lines 10–36), leaving only `normalize`.

Append to `evals/lib/prompts.mjs`:

```js
export function buildRuleRubric(item) {
  return `Grade only the line in the output that begins with "RULE:". Ignore which option was chosen and anything else in the output.

The RULE line passes if it names the same principle as the reference rule, in any wording. It fails if it names a different principle, is missing, or is too vague to tell this rule apart from the skill's other rules.

Reference rule:
${item.expected_rule}

Rule text from the skill:
${item.rule_quote || 'None.'}`;
}
```

In `evals/tests.mjs`: import `buildRuleRubric` alongside the existing prompt builders, add this helper above `export default`:

```js
const judged = (value, metric) => ({
  type: 'llm-rubric',
  value,
  metric,
  threshold: RUBRIC_THRESHOLD,
  provider: JUDGE_PROVIDER,
});
```

and replace the discrimination branch and the final `else` branch:

```js
    if (item.type === 'discrimination') {
      base.vars.letter_to_key = letterToKey;
      base.vars.correct = item.correct;
      base.assert = [
        { type: 'javascript', value: 'file://asserts/discrimination.mjs', metric: 'choice' },
        judged(buildRuleRubric(item), 'rule'),
      ];
    } else if (item.type === 'detection') {
      base.vars.violations = item.violations;
      base.vars.traps = item.traps;
      base.assert = [{ type: 'javascript', value: 'file://asserts/detection.mjs' }];
    } else {
      base.assert = [judged(buildTransformationRubric(item), 'rubric')];
    }
```

Replace `evals/bin/check-gate.mjs` entirely:

```js
#!/usr/bin/env node
// Gate semantics from the design spec: only a wrong discrimination choice
// (the assert tagged metric "choice") or a subject that never answered gates
// outright. Judged asserts and detection only drag the suite toward a
// pass-rate floor.
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
const components = (row) => row.gradingResult?.componentResults ?? [];

// A subject error leaves no components; a judge error still leaves the
// choice component, so it stays soft.
const isHardFailure = (row) =>
  !row.success &&
  (components(row).length === 0 ||
    components(row).some((c) => !c.pass && c.assertion?.metric === 'choice'));

const hardFailures = rows.filter(isHardFailure);
const passed = rows.filter((row) => row.success).length;
const passRate = passed / rows.length;

console.log(`${passed}/${rows.length} passed (rate ${(passRate * 100).toFixed(1)}%, floor ${(minRate * 100).toFixed(0)}%)`);

let failed = false;
if (hardFailures.length > 0) {
  failed = true;
  console.error('hard failures (wrong choice or no answer; these always gate):');
  for (const row of hardFailures) {
    console.error(`  ${meta(row).case_id ?? '(unknown case)'}`);
  }
}
if (passRate < minRate) {
  failed = true;
  console.error(`pass rate ${(passRate * 100).toFixed(1)}% is below the ${(minRate * 100).toFixed(0)}% floor`);
}

process.exit(failed ? 1 : 0);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd evals && npm test`
Expected: PASS.

Run: `grep -rn keywordOverlap evals --include=*.mjs --exclude-dir=node_modules`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add -A evals
git status --short   # confirm no results/ or .env staged
git commit -F - <<'EOF'
Gate discrimination on the choice and judge the stated rule

Keyword overlap on the stated rule failed a different correct paraphrase
each run. The choice stays a deterministic assert tagged metric "choice"
and is the only one that gates; the rule moves to an llm-rubric judgment
counted toward the pass-rate floor. check-gate now reads per-assert
component results instead of case type, which also makes detection soft.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
```

---

### Task 4: Grade prose-register's rank and structural cases

**Files:**
- Modify: `evals/lib/load-evals.mjs` (`SUPPORTED_TYPES`, discrimination validation), `evals/lib/prompts.mjs` (`SKILL_FRAMING`, `buildSubjectPrompt`, `buildTransformationRubric`, `buildRuleRubric`), `evals/asserts/discrimination.mjs`, `evals/tests.mjs` (discrimination branch), `evals/bin/validate.mjs` (header comment)
- Modify tests: `evals/test/load-evals.test.mjs`, `evals/test/prompts.test.mjs`, `evals/test/asserts.test.mjs`, `evals/test/generator.test.mjs`

**Interfaces:**
- Consumes: `buildRuleRubric`, `judged`, and the `choice`/`rule` metrics (Task 3).
- Produces: `SUPPORTED_TYPES` of five types; rank tests carry `vars.correct_ranking: string[]` (no `vars.correct`); `SKILL_FRAMING[skill]` entries with keys `review, edit, detect, material, unit, reply`.

- [ ] **Step 1: Write the failing tests**

In `evals/test/load-evals.test.mjs`, replace the last two-type test and the `SUPPORTED_TYPES` test:

```js
test('prose-register evals validate with zero unsupported cases', () => {
  const data = loadEvals(path.join(REPO_ROOT, 'home/.agents/skills/prose-register/evals.json'));
  const { caseCount, unsupported } = validateData(data);
  assert.equal(caseCount, 22);
  assert.equal(unsupported.length, 0);
});

test('validateData throws when a rank omits or repeats a stage', () => {
  const bad = {
    skill: 'x',
    cases: [{ id: 'r1', type: 'discrimination-rank', prompt: 'p', expected_rule_for_worst: 'w',
      stages: { a: '1', b: '2', c: '3' }, correct_ranking: ['a', 'b', 'b'] }],
  };
  assert.throws(() => validateData(bad), /must order every stage exactly once/);
});

test('SUPPORTED_TYPES covers both skills\' case types', () => {
  assert.deepEqual([...SUPPORTED_TYPES].sort(), [
    'detection', 'discrimination', 'discrimination-rank', 'discrimination-structural', 'transformation',
  ]);
});
```

Append to `evals/test/prompts.test.mjs`:

```js
test('rank prompt letters stages and asks for a best-first ordering', () => {
  const item = {
    id: 'r', type: 'discrimination-rank', prompt: 'Rank these.',
    stages: { original: 'O', over_tight: 'T', restored: 'R' },
    correct_ranking: ['restored', 'original', 'over_tight'], expected_rule_for_worst: 'w',
  };
  const { prompt, letterToKey } = buildSubjectPrompt('prose-register', item);
  assert.deepEqual(letterToKey, { A: 'original', B: 'over_tight', C: 'restored' });
  assert.ok(prompt.startsWith('Review these versions of a prose passage. Use the prose-register skill if it is available.'));
  assert.match(prompt, /most to least on-register/);
  assert.ok(prompt.includes('ANSWER: <letters, best first, comma-separated>'));
  assert.ok(!prompt.includes('restored,'), 'the ranking key never enters the prompt');
});

test('prose transformation and detection prompts use text framing', () => {
  const trans = buildSubjectPrompt('prose-register', { id: 't', type: 'transformation', task: 'T.', input: 'IN' });
  assert.ok(trans.prompt.includes('Text:\nIN'));
  assert.ok(trans.prompt.includes('Reply with only the rewritten passage, nothing else.'));
  const det = buildSubjectPrompt('prose-register', { id: 'd', type: 'detection', prompt: 'P.', input_document: 'DOC' });
  assert.ok(det.prompt.includes('Text:\nDOC'));
  assert.ok(det.prompt.includes('"<exact offending passage text>"'));
});

test('transformation rubric lists whatever criteria the case defines', () => {
  const item = {
    id: 't', type: 'transformation', task: 'T.', input: 'IN', reference_after: 'AFTER',
    rubric: { violation_fixed: 'VF?', no_new_violation: 'NV?', voice_match: 'VM?' },
  };
  const rubric = buildTransformationRubric(item);
  assert.ok(rubric.includes('3. voice_match: VM?'));
  assert.ok(!rubric.includes('placement'));
});

test('rank rule rubric uses the rule the worst version breaks', () => {
  const rubric = buildRuleRubric({ id: 'r', type: 'discrimination-rank', expected_rule_for_worst: 'WORST RULE' });
  assert.ok(rubric.includes('WORST RULE'));
});
```

In the same file, change the `'ALL THREE'` needle in the existing transformation rubric test to `'ALL 3 criteria'`.

Append to `evals/test/asserts.test.mjs`:

```js
const rankVars = {
  letter_to_key: { A: 'original', B: 'over_tight', C: 'restored' },
  correct_ranking: ['restored', 'original', 'over_tight'],
};

test('rank passes on the exact best-first ordering', () => {
  const result = assertDiscrimination('ANSWER: C, A, B\nRULE: r', { vars: rankVars });
  assert.equal(result.pass, true);
});

test('rank fails on any other ordering', () => {
  const result = assertDiscrimination('ANSWER: C, B, A\nRULE: r', { vars: rankVars });
  assert.equal(result.pass, false);
  assert.match(result.reason, /expected restored > original > over_tight/);
});

test('single choice ignores words on the ANSWER line', () => {
  const result = assertDiscrimination('ANSWER: Version B\nRULE: r', { vars: discVars });
  assert.equal(result.pass, true);
});
```

Append to `evals/test/generator.test.mjs`:

```js
test('generates all 22 prose-register tests, rank and structural included', async () => {
  const tests = await withEnv(
    { EVAL_SKILL: 'prose-register', EVAL_ONLY: undefined, EVAL_TYPES: undefined },
    generateTests,
  );
  assert.equal(tests.length, 22);
  const byType = Object.groupBy(tests, (t) => t.metadata.case_type);
  assert.equal(byType['discrimination-rank'].length, 2);
  assert.equal(byType['discrimination-structural'].length, 2);

  for (const t of [...byType.discrimination, ...byType['discrimination-structural'], ...byType['discrimination-rank']]) {
    assert.equal(t.assert[0].metric, 'choice');
    assert.equal(t.assert[1].metric, 'rule');
  }
  for (const t of byType['discrimination-rank']) {
    assert.deepEqual(t.vars.correct_ranking, ['restored', 'original', 'over_tight']);
    assert.equal(t.vars.correct, undefined);
  }
  for (const t of byType.transformation) {
    assert.match(t.assert[0].value, /voice_match/);
  }
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd evals && npm test`
Expected: FAIL: prose validation reports unsupported types; there's no `prose-register` framing; the rubric hardcodes three keys; rank ordering isn't graded.

- [ ] **Step 3: Implement `load-evals.mjs`**

Change `SUPPORTED_TYPES` to:

```js
export const SUPPORTED_TYPES = new Set([
  'discrimination',
  'discrimination-structural',
  'discrimination-rank',
  'transformation',
  'detection',
]);
```

Change the discrimination guard `if (item.type === 'discrimination') {` to `if (item.type === 'discrimination' || item.type === 'discrimination-structural') {`, and add after that block:

```js
    if (item.type === 'discrimination-rank') {
      requireField(item.prompt, `${item.id}.prompt`);
      requireField(item.expected_rule_for_worst, `${item.id}.expected_rule_for_worst`);
      const stages = Object.keys(item.stages ?? {});
      if (stages.length < 2) {
        throw new Error(`${item.id}.stages must contain at least two choices`);
      }
      const ranking = Array.isArray(item.correct_ranking) ? item.correct_ranking : [];
      if ([...ranking].sort().join('\n') !== [...stages].sort().join('\n')) {
        throw new Error(`${item.id}.correct_ranking must order every stage exactly once`);
      }
    }
```

- [ ] **Step 4: Implement `prompts.mjs`**

Replace `SKILL_FRAMING`:

```js
export const SKILL_FRAMING = {
  'code-comment-register': {
    review: 'Review these inline source comments.',
    edit: 'Edit inline source comments.',
    detect: 'Review inline source comments.',
    material: 'Code',
    unit: 'comment',
    reply: 'Reply with only the revised code, nothing else.',
  },
  'prose-register': {
    review: 'Review these versions of a prose passage.',
    edit: 'Edit this prose passage.',
    detect: 'Review this prose draft.',
    material: 'Text',
    unit: 'passage',
    reply: 'Reply with only the rewritten passage, nothing else.',
  },
};
```

Replace the three type branches of `buildSubjectPrompt` (keep the `framing`/`useSkill` lines above them and the final `throw`):

```js
  if (item.type.startsWith('discrimination')) {
    const isRank = item.type === 'discrimination-rank';
    const pool = isRank ? item.stages : item.variants;
    const keys = Object.keys(pool);
    const letters = keys.map((_, index) => String.fromCharCode(65 + index));
    const letterToKey = Object.fromEntries(letters.map((letter, index) => [letter, keys[index]]));
    const listing = keys.map((key, index) => `${letters[index]}.\n${pool[key]}`).join('\n\n');
    const instruction = isRank
      ? 'Rank the versions from most to least on-register. Name the specific rule the worst version breaks.'
      : 'Pick one version. Name the specific rule that decides it.';
    const answer = isRank ? 'ANSWER: <letters, best first, comma-separated>' : 'ANSWER: <letter>';

    const prompt = `${frame.review} ${useSkill}

${item.prompt}

${listing}

${instruction}

End with exactly these two lines and nothing after:
${answer}
RULE: <one sentence>`;

    return { prompt, letterToKey };
  }

  if (item.type === 'transformation') {
    return {
      prompt: `${frame.edit} ${useSkill}

${item.task}

${frame.material}:
${item.input}

${frame.reply}`,
    };
  }

  if (item.type === 'detection') {
    return {
      prompt: `${frame.detect} ${useSkill}

${item.prompt}

${frame.material}:
${item.input_document}

List each violation on one line:
- QUOTE: "<exact offending ${frame.unit} text>" | RULE: <rule in your own words>

Reply only with violation lines in that format. Do not explain or mention
${frame.unit}s that pass the register.`,
    };
  }
```

Replace `buildTransformationRubric`:

```js
export function buildTransformationRubric(item) {
  const criteria = Object.entries(item.rubric);
  return `Grade a rewrite against the rubric. Similar wording to the reference is not required.

Rule:
${item.rule_quote || ''}

Task given to the writer:
${item.task}

Original:
${item.input}

Reference-quality answer:
${item.reference_after}

The output passes ONLY if ALL ${criteria.length} criteria hold:
${criteria.map(([key, text], index) => `${index + 1}. ${key}: ${text}`).join('\n')}

Notes:
${item.grading_note || 'None.'}`;
}
```

In `buildRuleRubric`, change `${item.expected_rule}` to `${item.expected_rule ?? item.expected_rule_for_worst}`.

Update the Task 3 generator assertion `assert.match(t.assert[0].value, /ALL THREE/);` to `assert.match(t.assert[0].value, /ALL 3 criteria/);`.

- [ ] **Step 5: Implement rank grading and the generator branch**

Replace `evals/asserts/discrimination.mjs`:

```js
// Grades only the choice: one letter, or for rank cases the full best-first
// ordering. The stated rule is judged by a separate llm-rubric assert:
// keyword overlap failed correct paraphrases at random.
export default function assertDiscrimination(output, context) {
  const { letter_to_key: letterToKey, correct, correct_ranking: correctRanking } = context.vars;
  const answerLine = output.match(/ANSWER:\s*([^\n]+)/i);

  if (!answerLine) {
    return { pass: false, score: 0, reason: 'No ANSWER line in output' };
  }

  // Standalone letters only, so "Version B" reads as B rather than V.
  const letters = answerLine[1].toUpperCase().match(/\b[A-Z]\b/g) ?? [];
  const chosen = letters.map((letter) => letterToKey[letter] ?? letter);

  if (correctRanking) {
    const pass = chosen.join(',') === correctRanking.join(',');
    const ranked = chosen.join(' > ');
    return pass
      ? { pass, score: 1, reason: `ranked ${ranked}` }
      : { pass, score: 0, reason: `ranked ${ranked}, expected ${correctRanking.join(' > ')}` };
  }

  if (chosen[0] === correct) {
    return { pass: true, score: 1, reason: `chose ${chosen[0]}` };
  }
  return { pass: false, score: 0, reason: `chose ${chosen[0] ?? answerLine[1]}, expected ${correct}` };
}
```

In `evals/tests.mjs`, replace the discrimination branch:

```js
    if (item.type.startsWith('discrimination')) {
      base.vars.letter_to_key = letterToKey;
      if (item.type === 'discrimination-rank') base.vars.correct_ranking = item.correct_ranking;
      else base.vars.correct = item.correct;
      base.assert = [
        { type: 'javascript', value: 'file://asserts/discrimination.mjs', metric: 'choice' },
        judged(buildRuleRubric(item), 'rule'),
      ];
    } else if (item.type === 'detection') {
```

In `evals/bin/validate.mjs`, change the second header line to:

```js
// Unsupported case types warn rather than fail, so a new type can be
// authored in evals.json before the generator grades it.
```

- [ ] **Step 6: Run tests and validation**

Run: `cd evals && npm test && node bin/validate.mjs`
Expected: all tests PASS; validate prints `code-comment-register: 16 cases ok` and `prose-register: 22 cases ok` with no unsupported warning.

Also: `grep -n 'Code:\|revised code\|comment text\|comments that pass' evals/lib/prompts.mjs` shows no hardcoded code-comment wording outside `SKILL_FRAMING`.

- [ ] **Step 7: Commit**

```bash
git add evals
git status --short
git commit -F - <<'EOF'
Grade prose-register's rank and structural cases

Structural cases grade as ordinary discrimination; rank cases grade the
full best-first ordering and judge the rule the worst version breaks.
Prompt framing moves into a per-skill table so prose cases read as text,
not code, and transformation rubrics list whatever criteria the case
defines (prose uses voice_match where code uses placement).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
```

---

### Task 5: Retire the prose-register bespoke runner

Runs in the main session: keyed runs, then judgment on the results.

**Files:**
- Delete: `home/.agents/skills/prose-register/run-evals.mjs`

- [ ] **Step 1: Keyed run of both skills**

```bash
unset ANTHROPIC_API_KEY
SCRATCH="${TMPDIR:-/tmp}/skill-evals-phase2"; mkdir -p "$SCRATCH"   # or the session scratchpad; results never go in the repo
make eval SKILL=prose-register;        cp evals/results/latest.json "$SCRATCH/prose-run1.json"
make eval SKILL=code-comment-register; cp evals/results/latest.json "$SCRATCH/ccr-run1.json"
```

Expected: every row produced output (no subject errors). For each failure, read the component reasons:

```bash
node -e "for (const r of require(process.argv[1]).results.results) if (!r.success) console.log(r.testCase.metadata.case_id, JSON.stringify(r.gradingResult?.componentResults?.map(c=>[c.assertion?.metric??c.assertion?.type,c.pass,c.reason?.slice(0,160)])))" "$SCRATCH/prose-run1.json"
```

- [ ] **Step 2: Triage against the old runner's behavior**

- A `choice` failure: confirm the prompt shows the variants the case intends and the answer parse read the model's line correctly (a parse bug is a Task 4 fix, amended into that commit). If the model chose wrong, report it to the user with the case id and the model's answer. Do not edit `evals.json`.
- `rule` or `rubric` failures: read the judge's reason and decide whether it's a fair judgment. Report the counts; do not retune thresholds (that's after Phase 2).
- `det-*` failures on prose are expected (spec decision 8) and count toward the floor.

Run the prose suite a second time (`make eval SKILL=prose-register`) and compare which cases fail. A `choice` result that flips between runs is flakiness in a hard gate and must go to the user before continuing.

- [ ] **Step 3: Delete the runner**

```bash
git rm home/.agents/skills/prose-register/run-evals.mjs
grep -rn 'run-evals' --exclude-dir=node_modules --exclude-dir=.git . | grep -v '^./docs/superpowers/'
```

Expected: the only hits are inside `home/.agents/skills/prose-register/evals.json` grading notes, which record dated history and stay unedited (the file is read-only in this plan).

- [ ] **Step 4: Commit**

```bash
git commit -F - <<'EOF'
Retire the prose-register bespoke runner

Every prose-register case type now grades through promptfoo, so its
run-evals.mjs has no remaining job.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
```

Record the pass counts and any failing case ids from both skills' runs for the PR's Feedback section.

---

### Task 6: Run the offline eval checks in preflight

**Files:**
- Modify: `Makefile` (the `preflight:` line at "preflight: test check-symlinks", the comment block starting "# Skill eval suite (evals/).", `.PHONY`), `.github/workflows/ci.yml` (before `- run: make preflight`), `CLAUDE.md` (the `make preflight` bullet under Commands)

- [ ] **Step 1: Makefile**

Change:

```make
preflight: test check-symlinks check-skills check-skill-frontmatter check-editorconfig check-copilot-instructions
```

to:

```make
preflight: test check-symlinks check-skills check-skill-frontmatter check-editorconfig check-copilot-instructions eval-validate eval-test
```

Replace the comment block that begins `# Skill eval suite (evals/).` and ends `# into preflight and CI; until then all three are manual entry points.` with:

```make
# Skill eval suite (evals/). eval-validate and eval-test are offline and free,
# and run in preflight. eval and eval-compare spend subscription usage: a
# headless claude session per case plus one per judged assert.
```

Add after the `eval-validate` recipe:

```make
eval-test: evals/node_modules
	cd evals && npm test
```

Add `eval-test` to `.PHONY` right after `eval-validate`.

- [ ] **Step 2: CI Node version**

In `.github/workflows/ci.yml`, insert before `      - run: make preflight`:

```yaml
      - uses: actions/setup-node@v7
        with:
          node-version: "22"
```

- [ ] **Step 3: CLAUDE.md**

Replace the `make preflight` bullet's opening `` `test` plus every `check-*` target. `` with `` `test`, every `check-*` target, and the offline eval checks (`eval-validate`, `eval-test`; Node ≥ 22). ``. Leave the rest of the bullet unchanged. Add a bullet after it:

```markdown
- `make eval SKILL=<name>` — full keyed run of one skill's `evals.json` through promptfoo, gated by `evals/bin/check-gate.mjs`; spends subscription usage. `make eval-compare SKILL=<name>` runs skill vs baseline side by side. Unset `ANTHROPIC_API_KEY` first, or `claude -p` bills the API instead.
```

- [ ] **Step 4: Verify**

Run: `make preflight`
Expected: exit 0; output includes the two validate lines and the `node --test` summary with `# fail 0`.

Run: `editorconfig-checker Makefile CLAUDE.md .github/workflows/ci.yml`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add Makefile CLAUDE.md .github/workflows/ci.yml
git commit -F - <<'EOF'
Run the offline eval checks in preflight

eval-validate and the suite's unit tests cost no model calls, so they
join preflight and block in the existing CI job. CI pins Node 22 for
Object.groupBy.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
```

---

### Task 7: Run affected skill evals on pull requests

**Files:**
- Create: `evals/lib/affected.mjs`, `evals/bin/affected-skills.mjs`, `evals/test/affected.test.mjs`, `.github/workflows/evals.yml`

**Interfaces:**
- Consumes: `findEvalFiles(repoRoot)` from `lib/load-evals.mjs`; `make eval SKILL=<name>`.
- Produces: `affectedSkills(changedPaths: string[], evaluatedSkills: string[]) => string[]`; `bin/affected-skills.mjs` reads paths on stdin and prints a JSON array.

- [ ] **Step 1: Write the failing test**

`evals/test/affected.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { affectedSkills } from '../lib/affected.mjs';

const SKILLS = ['code-comment-register', 'prose-register'];

test('a change inside one evaluated skill selects only that skill', () => {
  assert.deepEqual(affectedSkills(['home/.agents/skills/prose-register/SKILL.md'], SKILLS), ['prose-register']);
});

test('a change to the suite selects every evaluated skill', () => {
  assert.deepEqual(affectedSkills(['evals/tests.mjs'], SKILLS), SKILLS);
  assert.deepEqual(affectedSkills(['.github/workflows/evals.yml'], SKILLS), SKILLS);
});

test('unrelated changes and unevaluated skills select nothing', () => {
  assert.deepEqual(affectedSkills(['README.md', 'home/.agents/skills/ux-review/SKILL.md'], SKILLS), []);
});

test('a skill name that prefixes another does not match it', () => {
  assert.deepEqual(affectedSkills(['home/.agents/skills/prose-register-extra/SKILL.md'], SKILLS), []);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd evals && node --test test/affected.test.mjs`
Expected: FAIL: `Cannot find module '../lib/affected.mjs'`.

- [ ] **Step 3: Implement**

`evals/lib/affected.mjs`:

```js
// A change to the suite can move any score, so it selects every evaluated
// skill; otherwise a skill runs only when its own directory changed.
const SUITE_PATHS = ['evals/', '.github/workflows/evals.yml'];

export function affectedSkills(changedPaths, evaluatedSkills) {
  if (changedPaths.some((file) => SUITE_PATHS.some((prefix) => file.startsWith(prefix)))) {
    return [...evaluatedSkills];
  }
  return evaluatedSkills.filter((skill) =>
    changedPaths.some((file) => file.startsWith(`home/.agents/skills/${skill}/`)),
  );
}
```

`evals/bin/affected-skills.mjs`:

```js
#!/usr/bin/env node
// Reads changed paths on stdin, one per line; prints the evaluated skills
// they affect as a JSON array for the evals workflow's matrix.
import path from 'node:path';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { findEvalFiles } from '../lib/load-evals.mjs';
import { affectedSkills } from '../lib/affected.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

const changed = readFileSync(0, 'utf8').split('\n').map((line) => line.trim()).filter(Boolean);
const evaluated = findEvalFiles(REPO_ROOT).map((file) => path.basename(path.dirname(file)));
console.log(JSON.stringify(affectedSkills(changed, evaluated)));
```

`.github/workflows/evals.yml`:

```yaml
name: evals

# Advisory: keyed runs of the evaluated skills a PR touches. Not a required
# check until repeated runs tune the gate thresholds; see
# docs/superpowers/specs/2026-08-29-skill-eval-suite-design.md.
on:
  pull_request:

jobs:
  plan:
    runs-on: ubuntu-latest
    outputs:
      skills: ${{ steps.affected.outputs.skills }}
      has_token: ${{ steps.affected.outputs.has_token }}
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v7
        with:
          node-version: "22"
      - id: affected
        env:
          HAS_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN != '' }}
        run: |
          skills=$(git diff --name-only "origin/${{ github.base_ref }}...HEAD" | node evals/bin/affected-skills.mjs)
          echo "skills=$skills" >> "$GITHUB_OUTPUT"
          echo "has_token=$HAS_TOKEN" >> "$GITHUB_OUTPUT"
          if [ "$HAS_TOKEN" != "true" ] && [ "$skills" != "[]" ]; then
            echo "::notice::CLAUDE_CODE_OAUTH_TOKEN unavailable (fork PR or unset secret); skipping evals for $skills"
          fi

  run:
    needs: plan
    if: needs.plan.outputs.skills != '[]' && needs.plan.outputs.has_token == 'true'
    runs-on: ubuntu-latest
    timeout-minutes: 20
    strategy:
      fail-fast: false
      matrix:
        skill: ${{ fromJSON(needs.plan.outputs.skills) }}
    env:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: "22"
      - run: npm install -g @anthropic-ai/claude-code@2.1.278
      # The repo has no root .claude/, so link the skill under test where
      # claude -p looks for user skills. Without it the subject silently runs
      # as the baseline.
      - run: |
          mkdir -p "$HOME/.claude/skills"
          ln -s "$GITHUB_WORKSPACE/home/.agents/skills/${{ matrix.skill }}" "$HOME/.claude/skills/${{ matrix.skill }}"
      - run: make eval SKILL=${{ matrix.skill }}
      - if: always()
        uses: actions/upload-artifact@v7
        with:
          name: eval-results-${{ matrix.skill }}
          path: evals/results/latest.json
          if-no-files-found: ignore
```

- [ ] **Step 4: Verify offline**

```bash
cd evals && npm test
printf 'evals/tests.mjs\n' | node bin/affected-skills.mjs            # ["code-comment-register","prose-register"]
printf 'README.md\n' | node bin/affected-skills.mjs                  # []
cd .. && git diff --name-only origin/main...HEAD | node evals/bin/affected-skills.mjs   # both skills
editorconfig-checker .github/workflows/evals.yml evals/lib evals/bin evals/test
```

Expected: tests PASS, the three printed arrays match the comments, and editorconfig prints nothing.

- [ ] **Step 5: Commit**

```bash
git add evals/lib/affected.mjs evals/bin/affected-skills.mjs evals/test/affected.test.mjs .github/workflows/evals.yml
git commit -F - <<'EOF'
Run affected skill evals on pull requests

An advisory workflow diffs the PR, selects the evaluated skills it
touches (every skill when the suite itself changes), links each skill
into the runner's ~/.claude/skills, and runs make eval on the
CLAUDE_CODE_OAUTH_TOKEN secret. Fork PRs and a missing secret skip with
a notice.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
```

- [ ] **Step 6: Verify in CI (after the user approves opening the PR)**

This branch changes `evals/`, so its own PR runs both skills. After the push:

```bash
gh pr checks <pr-number> --watch
gh run download <run-id> -n eval-results-prose-register -D "${TMPDIR:-/tmp}/skill-evals-phase2/ci-prose"
```

Expected: `ci` passes on both OSes. The `evals` `plan` job outputs both skills with `has_token=true`, and each `run` job completes its `make eval`. Its pass/fail status is advisory; what matters is that rows carry real subject output and judge reasons (no auth errors, no subject errors). Compare the CI pass counts with Task 5's local counts. A large drop in `choice` passes suggests the skill link didn't take; check a `run` job's log for the `ln -s` step.

---

## After the series

- `make preflight` green locally; `git log --oneline origin/main..HEAD` shows the spec commit plus the six commits above.
- Final adversarial review before merge on Opus (or Fable) at high effort (`par` or `code-review`), against the spec's Phase 2 decisions.
- PR body in the four-section format, `Part of` the tracking issue if one exists. The Feedback section carries Task 5's and Task 6's pass counts and the open threshold question.
- Prune `.worktrees/skill-eval-phase2` once the PR is open.
