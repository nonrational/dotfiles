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
