import test from 'node:test';
import assert from 'node:assert/strict';
import { buildSubjectPrompt, buildTransformationRubric, buildRuleRubric } from '../lib/prompts.mjs';

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

test('discrimination prompt asks for reasoning before the ANSWER/RULE lines, so the verdict is not the first thing written', () => {
  const item = {
    id: 'disc-x', type: 'discrimination', prompt: 'p', variants: { first: 'AAA', second: 'BBB' },
    correct: 'second', expected_rule: 'r',
  };
  const rank = { id: 'r-x', type: 'discrimination-rank', prompt: 'p', stages: { a: '1', b: '2', c: '3' },
    correct_ranking: ['a', 'b', 'c'], expected_rule_for_worst: 'w' };
  for (const [name, c] of [['pick', item], ['rank', rank]]) {
    const { prompt } = buildSubjectPrompt(SKILL, c);
    const reasoning = prompt.indexOf('a few sentences');
    assert.ok(reasoning > prompt.indexOf('\n\n' + (name === 'pick' ? 'Pick one' : 'Rank the')), `${name}: instruction precedes reasoning ask`);
    assert.ok(reasoning < prompt.indexOf('End with exactly these two lines'), `${name}: reasoning ask precedes the format lines`);
  }
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
  for (const needle of ['Do the thing.', 'The rule.', 'AFTER', 'VF?', 'PL?', 'NV?', 'Note.', 'ALL 3 criteria']) {
    assert.ok(rubric.includes(needle), `missing: ${needle}`);
  }
});

test('rule rubric grades only the RULE line against the reference rule', () => {
  const item = {
    id: 'd', type: 'discrimination', expected_rule: 'Explain why, not what.', rule_quote: 'Quote.',
    grading_note: 'Also accept X.',
  };
  const rubric = buildRuleRubric(item);
  assert.match(rubric, /RULE:/);
  assert.ok(rubric.includes('Explain why, not what.'));
  assert.ok(rubric.includes('Quote.'));
  assert.match(rubric, /Ignore which option was chosen/);
  assert.match(rubric, /part of a compound reference rule/);
  assert.ok(rubric.includes('Also accept X.'));
});

test('rule rubric defaults the author notes to None when a case sets no grading_note', () => {
  const item = { id: 'd', type: 'discrimination', expected_rule: 'Explain why, not what.', rule_quote: 'Quote.' };
  const rubric = buildRuleRubric(item);
  assert.ok(rubric.includes('Author\'s notes (may list accepted alternative rules):\nNone.'));
});

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
