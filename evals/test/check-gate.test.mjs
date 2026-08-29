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
