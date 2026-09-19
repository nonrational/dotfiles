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
