import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import os from 'node:os';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const GATE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../bin/check-gate.mjs');

// Rows mirror promptfoo 0.122.2 output: each assert echoes into
// gradingResult.componentResults with its `metric`; a subject error leaves
// no components at all.
const choice = (pass) => ({ pass, assertion: { type: 'javascript', metric: 'choice' } });
const rule = (pass) => ({ pass, assertion: { type: 'llm-rubric', metric: 'rule' } });
const detect = (pass) => ({ pass, assertion: { type: 'javascript' } });
const row = (id, components, metadata = {}) => ({
  success: components.length > 0 && components.every((c) => c.pass),
  testCase: { metadata: { case_id: id, ...metadata } },
  gradingResult: components.length ? { componentResults: components } : null,
});
const passing = (n) => Array.from({ length: n }, (_, i) => row(`ok-${i}`, [choice(true), rule(true)]));

function runGate(rows, ...args) {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'gate-'));
  const file = path.join(dir, 'results.json');
  writeFileSync(file, JSON.stringify({ results: { results: rows } }));
  return spawnSync(process.execPath, [GATE, file, ...args], { encoding: 'utf8' });
}

test('a failed rule judgment is informational: counts as passed for the floor and is reported', () => {
  const result = runGate([...passing(6), ...[7, 8, 9, 10].map((i) => row(`disc-${i}`, [choice(true), rule(false)]))]);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /10\/10 passed/);
  assert.match(result.stdout, /rule 6\/10 informational/);
});

test('a wrong arguable choice counts against the floor, and its rule verdict still reports', () => {
  const arguable = [1, 2].map((i) => row(`disc-0${i}`, [choice(false), rule(false)], { arguable: true }));
  const result = runGate([...passing(8), ...arguable]);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /8\/10 passed/);
  assert.match(result.stdout, /rule 8\/10 informational/);
  assert.match(result.stderr, /pass rate/i);
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

test('a wrong choice on an arguable case is soft: passes at the floor', () => {
  const arguable = row('disc-11', [choice(false), rule(true)], { arguable: true });
  const result = runGate([...passing(9), arguable]);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('an arguable case still counts against the floor when it fails', () => {
  const arguable = [1, 2].map((i) => row(`disc-0${i}`, [choice(false), rule(true)], { arguable: true }));
  const result = runGate([...passing(8), ...arguable]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /pass rate/i);
  assert.doesNotMatch(result.stderr, /hard failures/);
});

test('a subject error on an arguable case still gates because no assert ran', () => {
  const result = runGate([...passing(19), row('disc-11', [], { arguable: true })]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /disc-11/);
});

test('a subject error gates because no assert ran', () => {
  const result = runGate([...passing(19), row('disc-02', [])]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /disc-02/);
});

test('soft failures below the floor fail the gate', () => {
  const soft = [1, 2, 3].map((i) => row(`det-0${i}`, [detect(false)]));
  const result = runGate([...passing(7), ...soft]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /pass rate/i);
});

test('the floor is overridable via argv', () => {
  const soft = [1, 2, 3].map((i) => row(`det-0${i}`, [detect(false)]));
  const result = runGate([...passing(7), ...soft], '0.70');
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

// EVAL_REPO_ROOT points the gate at a throwaway skills tree, so the floor
// tests don't depend on the real suites' values.
function runGateWithSkills(skills, rows, ...args) {
  const root = mkdtempSync(path.join(os.tmpdir(), 'gate-root-'));
  for (const [name, content] of Object.entries(skills)) {
    const dir = path.join(root, 'home/.agents/skills', name, 'evals');
    mkdirSync(dir, { recursive: true });
    writeFileSync(path.join(dir, 'README.md'), content);
  }
  const file = path.join(mkdtempSync(path.join(os.tmpdir(), 'gate-')), 'results.json');
  writeFileSync(file, JSON.stringify({ results: { results: rows } }));
  return spawnSync(process.execPath, [GATE, file, ...args], {
    encoding: 'utf8',
    env: { ...process.env, EVAL_REPO_ROOT: root },
  });
}

// A README with only frontmatter is a valid, empty suite.
const readme = (extra = {}) =>
  `---\n${Object.entries({ skill: 'alpha', ...extra }).map(([k, v]) => `${k}: ${v}`).join('\n')}\n---\n`;
const MALFORMED_README = '---\nskill: [unclosed\n---\n';
// 6 of 11 rows pass (54.5%): under the 90% default, over a 50% floor.
const elevenRows = (skill) => [
  ...Array.from({ length: 6 }, (_, i) => row(`ok-${i}`, [choice(true), rule(true)], { skill })),
  ...Array.from({ length: 5 }, (_, i) => row(`det-0${i}`, [detect(false)], { skill })),
];

test("a skill's README can set its own floor", () => {
  const result = runGateWithSkills({ alpha: readme({ min_pass_rate: 0.5 }) }, elevenRows('alpha'));
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /floor 50%/);
});

test('a skill without a min_pass_rate keeps the 90% default', () => {
  const result = runGateWithSkills({ alpha: readme() }, elevenRows('alpha'));
  assert.equal(result.status, 1);
  assert.match(result.stdout, /floor 90%/);
});

test("an argv floor overrides the skill's own", () => {
  const result = runGateWithSkills({ alpha: readme({ min_pass_rate: 0.5 }) }, elevenRows('alpha'), '0.90');
  assert.equal(result.status, 1);
  assert.match(result.stderr, /below the 90% floor/);
});

test("a sibling skill's malformed README does not touch this skill's gate", () => {
  const skills = { alpha: readme({ min_pass_rate: 0.5 }), beta: MALFORMED_README };
  const result = runGateWithSkills(skills, elevenRows('alpha'));
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test("the skill's own unreadable README warns and falls back to the default floor", () => {
  const result = runGateWithSkills({ alpha: MALFORMED_README }, elevenRows('alpha'));
  assert.equal(result.status, 1);
  assert.match(result.stderr, /cannot read alpha's min_pass_rate/);
  assert.match(result.stdout, /floor 90%/);
});

test('a missing skills tree falls back to the default floor', () => {
  const result = runGateWithSkills({}, elevenRows('alpha'));
  assert.equal(result.status, 1);
  assert.match(result.stdout, /floor 90%/);
});

test('rows from more than one skill fall back to the default floor', () => {
  const rows = [...elevenRows('alpha'), ...elevenRows('beta')];
  const result = runGateWithSkills({ alpha: readme({ min_pass_rate: 0.5 }) }, rows);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /floor 90%/);
});

test('an empty, non-numeric or out-of-range floor is rejected, not read as zero or NaN', () => {
  const ok = [...Array(10)].map((_, i) => row(`ok-${i}`, [choice(true), rule(true)], { skill: 'alpha' }));
  for (const bad of ['', 'abc', '0', '1.5']) {
    const result = runGateWithSkills({ alpha: readme() }, ok, bad);
    assert.equal(result.status, 1, `argv ${JSON.stringify(bad)}`);
    assert.match(result.stderr, /floor must be a number in \(0, 1\]/);
  }
  const zero = runGateWithSkills({ alpha: readme({ min_pass_rate: 0 }) }, ok);
  assert.equal(zero.status, 1);
  assert.match(zero.stderr, /floor must be a number in \(0, 1\]/);
});

test('an unreadable results file is a hard error', () => {
  const result = spawnSync(process.execPath, [GATE, '/nonexistent/results.json'], { encoding: 'utf8' });
  assert.equal(result.status, 1);
});

test('a draft row with a wrong choice never hard-gates and stays out of the floor', () => {
  const rows = [...passing(9), row('draft-1', [choice(false), rule(true)], { status: 'draft' })];
  const result = runGate(rows);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /9\/9 passed/);
  assert.match(result.stdout, /1 draft rows, 0 passed/);
});

test('draft rows do not lift the pass rate either', () => {
  // 8 of 9 gated rows pass (88.9%), under the 90% default; 5 passing drafts must not rescue it.
  const rows = [
    ...passing(8),
    row('det-0', [detect(false)]),
    ...Array.from({ length: 5 }, (_, i) => row(`draft-${i}`, [choice(true), rule(true)], { status: 'draft' })),
  ];
  const result = runGate(rows);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /8\/9 passed/);
  assert.match(result.stdout, /5 draft rows, 5 passed/);
});

test('a run of only draft rows passes and says so', () => {
  const rows = Array.from({ length: 3 }, (_, i) => row(`draft-${i}`, [choice(false), rule(false)], { status: 'draft' }));
  const result = runGate(rows);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /no approved rows; nothing gated/);
  assert.match(result.stdout, /3 draft rows, 0 passed/);
});

test('a draft row with no components hard-gates because the harness never got an answer', () => {
  const rows = [...passing(9), row('draft-2', [], { status: 'draft' })];
  const result = runGate(rows);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stdout, /9\/9 passed/);
  assert.match(result.stderr, /draft-2/);
});

test('the informational rule tally is scoped to gated rows, not drafts', () => {
  const gatedRows = Array.from({ length: 3 }, (_, i) => row(`ok-${i}`, [choice(true), rule(true)]));
  const draftRows = Array.from({ length: 2 }, (_, i) => row(`draft-${i}`, [choice(true), rule(false)], { status: 'draft' }));
  const result = runGate([...gatedRows, ...draftRows]);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /rule 3\/3 informational/);
  assert.match(result.stdout, /2 draft rows, 2 passed/);
});
