import test from 'node:test';
import assert from 'node:assert/strict';
import assertDiscrimination from '../asserts/discrimination.mjs';
import assertDetection from '../asserts/detection.mjs';

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

const rankVars = {
  letter_to_key: { A: 'original', B: 'over_tight', C: 'restored' },
  correct_ranking: 'restored,original,over_tight',
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

test('discrimination reads the last ANSWER line, not one echoed from the format template', () => {
  const output = 'Format: ANSWER: <letter>\n...\nANSWER: B\nRULE: r';
  const result = assertDiscrimination(output, { vars: discVars });
  assert.equal(result.pass, true);
});

const detVars = {
  violations: [
    { quote: 'Larger chunks use more memory. Smaller chunks use more CPU.', rule: 'generic tradeoff' },
    { quote: 'Parse all records and drop the header before writing.', rule: 'mechanical narration' },
  ],
  traps: [
    { quote: '`binary_part/3` returns a view', why_valid: 'surprising runtime behavior' },
  ],
};

test('detection passes on full recall with no trap hits', () => {
  const output = [
    '- QUOTE: "Larger chunks use more memory. Smaller chunks use more CPU." | RULE: generic tradeoff',
    '- QUOTE: "Parse all records and drop the header before writing." | RULE: narration',
  ].join('\n');
  const result = assertDetection(output, { vars: detVars });
  assert.equal(result.pass, true);
  assert.equal(result.score, 1);
});

test('detection fails on a missed violation', () => {
  const output = '- QUOTE: "Larger chunks use more memory. Smaller chunks use more CPU." | RULE: generic tradeoff';
  const result = assertDetection(output, { vars: detVars });
  assert.equal(result.pass, false);
  assert.match(result.reason, /1\/2 violations/);
});

test('detection fails when a trap is flagged', () => {
  const output = [
    '- QUOTE: "Larger chunks use more memory. Smaller chunks use more CPU." | RULE: generic tradeoff',
    '- QUOTE: "Parse all records and drop the header before writing." | RULE: narration',
    '- QUOTE: "`binary_part/3` returns a view" | RULE: needless jargon',
  ].join('\n');
  const result = assertDetection(output, { vars: detVars });
  assert.equal(result.pass, false);
  assert.match(result.reason, /1 trap/);
});

test('detection ignores lines outside the QUOTE format', () => {
  const output = [
    'Here is my analysis of `binary_part/3` returns a view and more.',
    '- QUOTE: "Larger chunks use more memory. Smaller chunks use more CPU." | RULE: generic tradeoff',
    '- QUOTE: "Parse all records and drop the header before writing." | RULE: narration',
  ].join('\n');
  const result = assertDetection(output, { vars: detVars });
  assert.equal(result.pass, true, 'prose mention of a trap outside violation lines must not count');
});
