import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { SUPPORTED_TYPES, findEvalFiles, loadEvals, validateData } from '../lib/load-evals.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

test('findEvalFiles locates every existing suite', () => {
  const files = findEvalFiles(REPO_ROOT);
  const skills = files.map((f) => path.basename(path.dirname(f)));
  assert.ok(skills.includes('code-comment-register'));
  assert.ok(skills.includes('prose-register'));
  assert.ok(skills.includes('code-review-register'));
});

test('code-comment-register evals validate with zero unsupported cases', () => {
  const data = loadEvals(
    path.join(REPO_ROOT, 'home/.agents/skills/code-comment-register/evals.json'),
  );
  const { caseCount, unsupported } = validateData(data);
  assert.equal(caseCount, 16);
  assert.equal(unsupported.length, 0);
});

test('prose-register evals validate with zero unsupported cases', () => {
  const data = loadEvals(path.join(REPO_ROOT, 'home/.agents/skills/prose-register/evals.json'));
  const { caseCount, unsupported } = validateData(data);
  assert.equal(caseCount, 24);
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

test('SUPPORTED_TYPES covers both skills\' case types', () => {
  assert.deepEqual([...SUPPORTED_TYPES].sort(), [
    'detection', 'discrimination', 'discrimination-rank', 'discrimination-structural', 'transformation',
  ]);
});

const arguableCase = (extra) => ({
  skill: 'x',
  cases: [{ id: 'd1', type: 'discrimination', prompt: 'p', expected_rule: 'r',
    variants: { a: '1', b: '2' }, correct: 'a', ...extra }],
});

test('validateData rejects arguable on a case type with no choice to soften', () => {
  const bad = { skill: 'x', cases: [{ id: 'x1', type: 'detection', arguable: true, grading_note: 'n' }] };
  assert.throws(() => validateData(bad), /x1\.arguable applies only to discrimination cases/);
});

test('validateData accepts an arguable case that says why in its grading_note', () => {
  const ok = arguableCase({ arguable: true, grading_note: 'Both answers are defensible.' });
  assert.doesNotThrow(() => validateData(ok));
});

test('validateData rejects a non-boolean arguable flag', () => {
  const bad = arguableCase({ arguable: 'yes', grading_note: 'n' });
  assert.throws(() => validateData(bad), /d1\.arguable must be a boolean/);
});

test('validateData rejects an arguable case with no grading_note', () => {
  assert.throws(() => validateData(arguableCase({ arguable: true })), /^Error: d1\.arguable needs a grading_note saying why$/);
});

test('validateData accepts a min_pass_rate in (0, 1]', () => {
  const ok = { ...arguableCase({}), min_pass_rate: 0.5 };
  assert.doesNotThrow(() => validateData(ok));
});

test('validateData accepts accepted_rules as a non-empty list of rule strings on a discrimination case', () => {
  assert.doesNotThrow(() => validateData(arguableCase({ accepted_rules: ['Another rule.'] })));
});

test('validateData rejects an empty or non-string accepted_rules list', () => {
  for (const bad of [[], 'Another rule.', ['ok', ''], [1]]) {
    assert.throws(() => validateData(arguableCase({ accepted_rules: bad })), /d1\.accepted_rules must be a non-empty array of rule strings/);
  }
});

test('validateData rejects accepted_rules on a case type with no stated rule to judge', () => {
  const bad = {
    skill: 'x',
    cases: [{ id: 't1', type: 'transformation', input: 'i', task: 't', reference_after: 'r',
      rubric: { violation_fixed: 'v' }, accepted_rules: ['x'] }],
  };
  assert.throws(() => validateData(bad), /t1\.accepted_rules applies only to discrimination cases/);
});

const detectionCase = (extra) => ({
  skill: 'x',
  cases: [{ id: 'x1', type: 'detection', prompt: 'p', input_document: 'the quoted line',
    violations: [{ quote: 'quoted line', rule: 'r' }], traps: [], ...extra }],
});

test('validateData accepts a min_recall in [0, 1] on a detection case', () => {
  for (const ok of [0, 0.5, 1]) {
    assert.doesNotThrow(() => validateData(detectionCase({ min_recall: ok })));
  }
});

test('validateData rejects a min_recall outside [0, 1]', () => {
  for (const bad of [-0.1, 1.5, '0.5']) {
    assert.throws(() => validateData(detectionCase({ min_recall: bad })), /x1\.min_recall must be a number in \[0, 1\]/);
  }
});

test('validateData accepts an anchor that sits inside its quote', () => {
  const ok = detectionCase({});
  ok.cases[0].violations = [{ quote: 'quoted line', anchor: 'ed li', rule: 'r' }];
  assert.doesNotThrow(() => validateData(ok));
});

test('validateData rejects an anchor that is empty or not inside its quote', () => {
  for (const bad of ['', 'the quoted', 7]) {
    const data = detectionCase({});
    data.cases[0].violations = [{ quote: 'quoted line', anchor: bad, rule: 'r' }];
    assert.throws(() => validateData(data), /x1 anchor must be a non-empty substring of its quote/, `anchor ${JSON.stringify(bad)}`);
  }
});

test('validateData rejects a detection quote the document does not contain verbatim', () => {
  const bad = detectionCase({ input_document: 'Therefore, trust the pilot.', traps: [{ quote: 'Therefore, trust...' }] });
  bad.cases[0].violations = [{ quote: 'trust the pilot', rule: 'r' }];
  assert.throws(() => validateData(bad), /x1 quote is not in input_document verbatim: "Therefore, trust\.\.\."/);
});

test('validateData rejects min_recall on a case type with no recall to floor', () => {
  assert.throws(() => validateData(arguableCase({ min_recall: 0.5 })), /d1\.min_recall applies only to detection cases/);
});

test('validateData rejects a min_pass_rate outside (0, 1]', () => {
  for (const bad of [0, 1.5, '0.5', -1]) {
    const data = { ...arguableCase({}), min_pass_rate: bad };
    assert.throws(() => validateData(data), /min_pass_rate must be a number in \(0, 1\]/);
  }
});
