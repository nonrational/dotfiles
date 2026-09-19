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
