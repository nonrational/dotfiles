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
