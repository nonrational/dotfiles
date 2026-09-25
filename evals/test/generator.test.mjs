import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import generateTests from '../tests.mjs';
import { findEvalFiles, loadEvals } from '../lib/load-evals.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

// Fields the subject prompt is built from (buildSubjectPrompt in lib/prompts.mjs);
// a value that also appears here isn't a leak even if it happens to match an
// answer-key field too (e.g. a transformation's reference_after repeating an
// unchanged input line).
function subjectVisibleValues(item) {
  const values = [];
  for (const key of ['prompt', 'task', 'input', 'input_document']) {
    if (typeof item[key] === 'string') values.push(item[key]);
  }
  for (const key of ['variants', 'stages']) {
    if (item[key] && typeof item[key] === 'object') values.push(...Object.values(item[key]));
  }
  return values;
}

function answerKeyValues(item) {
  const values = [];
  for (const key of ['expected_rule', 'expected_rule_for_worst', 'rule_quote', 'grading_note', 'reference_after']) {
    if (typeof item[key] === 'string' && item[key].length > 0) values.push(item[key]);
  }
  if (item.rubric && typeof item.rubric === 'object') values.push(...Object.values(item.rubric));
  if (Array.isArray(item.correct_ranking)) values.push(item.correct_ranking.join(','));
  if (Array.isArray(item.accepted_rules)) values.push(...item.accepted_rules);
  return values;
}

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
    assert.deepEqual(t.assert[0], {
      type: 'javascript', value: 'file://asserts/discrimination.mjs', metric: 'choice',
    });
    assert.equal(t.assert[1].type, 'llm-rubric');
    assert.equal(t.assert[1].metric, 'rule');
    assert.equal(t.assert[1].provider, 'file://providers/judge.mjs');
    assert.ok(t.vars.letter_to_key && t.vars.correct);
    assert.equal(t.vars.expected_rule, undefined, 'the rule reaches only the judge');
  }
  for (const t of byType.detection) {
    assert.equal(t.assert[0].value, 'file://asserts/detection.mjs');
    assert.ok(Array.isArray(t.vars.violations) && Array.isArray(t.vars.traps));
  }
  for (const t of byType.transformation) {
    assert.equal(t.assert[0].type, 'llm-rubric');
    assert.equal(t.assert[0].metric, 'rubric');
    assert.equal(t.assert[0].threshold, 0.75);
    assert.equal(t.assert[0].provider, 'file://providers/judge.mjs');
    assert.match(t.assert[0].value, /ALL 3 criteria/);
  }

  // Answer-key fields never leak into the subject prompt.
  for (const t of tests) {
    assert.ok(t.vars.subject_prompt.length > 0);
  }

  // promptfoo renders vars and llm-rubric values as nunjucks; wrap them so case text
  // (e.g. Hugo shortcodes) passes through literally instead of failing to render.
  for (const t of tests) {
    assert.ok(t.vars.subject_prompt.startsWith('{% raw %}'));
    assert.ok(t.vars.subject_prompt.endsWith('{% endraw %}'));
    for (const a of t.assert) {
      if (a.type !== 'llm-rubric') continue;
      assert.ok(a.value.startsWith('{% raw %}'));
      assert.ok(a.value.endsWith('{% endraw %}'));
    }
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

test('generates all 24 prose-register tests, rank and structural included', async () => {
  const tests = await withEnv(
    { EVAL_SKILL: 'prose-register', EVAL_ONLY: undefined, EVAL_TYPES: undefined },
    generateTests,
  );
  assert.equal(tests.length, 24);
  const byType = Object.groupBy(tests, (t) => t.metadata.case_type);
  assert.equal(byType['discrimination-rank'].length, 1);
  assert.equal(byType['discrimination-structural'].length, 2);

  for (const t of [...byType.discrimination, ...byType['discrimination-structural'], ...byType['discrimination-rank']]) {
    assert.equal(t.assert[0].metric, 'choice');
    assert.equal(t.assert[1].metric, 'rule');
  }
  for (const t of byType['discrimination-rank']) {
    assert.equal(t.vars.correct_ranking, 'restored,original,over_tight');
    assert.equal(t.vars.correct, undefined);
  }
  for (const t of byType.transformation) {
    assert.match(t.assert[0].value, /voice_match/);
  }

  // promptfoo expands any array-of-primitives var into one test per element; guard against
  // reintroducing one (arrays of objects, like detection's violations/traps, are unaffected).
  for (const t of tests) {
    for (const [k, v] of Object.entries(t.vars)) {
      assert.ok(
        !(Array.isArray(v) && v.some((x) => typeof x !== 'object')),
        `${t.metadata.case_id}.${k} would expand`,
      );
    }
  }

  // promptfoo renders vars and llm-rubric values as nunjucks; wrap them so case text
  // (e.g. Hugo shortcodes) passes through literally instead of failing to render.
  for (const t of tests) {
    assert.ok(t.vars.subject_prompt.startsWith('{% raw %}'));
    assert.ok(t.vars.subject_prompt.endsWith('{% endraw %}'));
    for (const a of t.assert) {
      if (a.type !== 'llm-rubric') continue;
      assert.ok(a.value.startsWith('{% raw %}'));
      assert.ok(a.value.endsWith('{% endraw %}'));
    }
  }
  const det02 = tests.find((t) => t.metadata.case_id === 'det-02');
  assert.ok(det02.vars.subject_prompt.includes('{{<'));

  // det-01 and det-02 record recall on a non-exhaustive list; det-03's single em-dash still gates.
  for (const t of byType.detection) {
    assert.equal(t.vars.min_recall, t.metadata.case_id === 'det-03' ? undefined : 0, t.metadata.case_id);
  }
});

test('subject prompts never leak an answer-key value the subject cannot already see', async () => {
  for (const skill of ['code-comment-register', 'prose-register', 'code-review-register']) {
    const evalsPath = findEvalFiles(REPO_ROOT).find((f) => path.basename(path.dirname(f)) === skill);
    const data = loadEvals(evalsPath);
    const casesById = Object.fromEntries(data.cases.map((c) => [c.id, c]));
    const tests = await withEnv(
      { EVAL_SKILL: skill, EVAL_ONLY: undefined, EVAL_TYPES: undefined },
      generateTests,
    );

    for (const t of tests) {
      const item = casesById[t.metadata.case_id];
      const visible = subjectVisibleValues(item);
      for (const value of answerKeyValues(item)) {
        if (visible.some((v) => v.includes(value))) continue;
        assert.ok(
          !t.vars.subject_prompt.includes(value),
          `${skill}/${t.metadata.case_id} subject_prompt leaks answer-key value: ${value.slice(0, 60)}`,
        );
      }
    }
  }
});

test('only the prose-register cases with an arguable key carry the flag', async () => {
  const tests = await withEnv(
    { EVAL_SKILL: 'prose-register', EVAL_ONLY: undefined, EVAL_TYPES: undefined },
    generateTests,
  );
  const flagged = tests.filter((t) => t.metadata.arguable === true).map((t) => t.metadata.case_id);
  assert.deepEqual(flagged.sort(), ['disc-04', 'disc-08', 'disc-09', 'disc-11', 'disc-12', 'disc-13', 'disc-14']);
  assert.ok(tests.every((t) => t.metadata.arguable === undefined || t.metadata.arguable === true));
});
