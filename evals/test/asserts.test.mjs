import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assertDiscrimination from '../asserts/discrimination.mjs';
import assertDetection, { quotesOverlap } from '../asserts/detection.mjs';
import { findSuites, loadSuite } from '../lib/load-evals.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

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

// det-03's miss: the key begins "same artifact — one rewrite", the subject
// quoted from "artifact — one rewrite" onward and past the key's end.
test('detection counts a quote that starts inside the key and runs past it', () => {
  const vars = {
    violations: [{ quote: 'same artifact — one rewrite by strangers', rule: 'No em-dashes.' }],
    traps: [],
  };
  const output = '- QUOTE: "artifact — one rewrite by strangers, one by a machine" | RULE: em-dash';
  const result = assertDetection(output, { vars });
  assert.equal(result.pass, true, result.reason);
  assert.equal(result.score, 1);
});

// det-03's second miss: the subject quoted the text on the left of the dash,
// 15 characters of overlap with the key, under the floor.
const dashQuotedFromTheLeft = '- QUOTE: "Same company, same invoice, same artifact —" | RULE: em-dash';

test('detection counts a quote from the far side of a one-character violation when the key names an anchor', () => {
  const vars = {
    violations: [{ quote: 'same artifact — one rewrite by strangers', anchor: 'artifact —', rule: 'No em-dashes.' }],
    traps: [],
  };
  const result = assertDetection(dashQuotedFromTheLeft, { vars });
  assert.equal(result.pass, true, result.reason);
});

test('detection without an anchor misses a quote that overlaps the key by less than the floor', () => {
  const vars = {
    violations: [{ quote: 'same artifact — one rewrite by strangers', rule: 'No em-dashes.' }],
    traps: [],
  };
  const result = assertDetection(dashQuotedFromTheLeft, { vars });
  assert.equal(result.pass, false);
  assert.match(result.reason, /0\/1 violations/);
});

test('detection counts a quote that wraps the key in context on both sides', () => {
  const output = '- QUOTE: "Then: Larger chunks use more memory. Smaller chunks use more CPU. And so on." | RULE: generic';
  const result = assertDetection(output, { vars: { ...detVars, violations: detVars.violations.slice(0, 1) } });
  assert.equal(result.pass, true, result.reason);
});

test('detection does not count a fragment shorter than the overlap floor', () => {
  const output = '- QUOTE: "more memory" | RULE: generic tradeoff';
  const result = assertDetection(output, { vars: { ...detVars, violations: detVars.violations.slice(0, 1) } });
  assert.equal(result.pass, false);
  assert.match(result.reason, /0\/1 violations/);
});

test('detection flags a trap quoted from its middle, not only from its start', () => {
  const output = [
    '- QUOTE: "Larger chunks use more memory. Smaller chunks use more CPU." | RULE: generic tradeoff',
    '- QUOTE: "Parse all records and drop the header before writing." | RULE: narration',
    '- QUOTE: "returns a view of the buffer" | RULE: jargon',
  ].join('\n');
  const result = assertDetection(output, { vars: { ...detVars, traps: [{ quote: '`binary_part/3` returns a view of the buffer' }] } });
  assert.equal(result.pass, false);
  assert.match(result.reason, /1 trap/);
});

test('detection with min_recall 0 passes on partial recall and records recall as the score', () => {
  const output = '- QUOTE: "Larger chunks use more memory. Smaller chunks use more CPU." | RULE: generic tradeoff';
  const result = assertDetection(output, { vars: { ...detVars, min_recall: 0 } });
  assert.equal(result.pass, true, result.reason);
  assert.equal(result.score, 0.5);
  assert.match(result.reason, /1\/2 violations, 0 trap\(s\) flagged, floor 0/);
});

test('detection with min_recall 0 still fails on a trap hit', () => {
  const output = '- QUOTE: "`binary_part/3` returns a view" | RULE: needless jargon';
  const result = assertDetection(output, { vars: { ...detVars, min_recall: 0 } });
  assert.equal(result.pass, false);
  assert.match(result.reason, /1 trap/);
});

test('detection with a fractional min_recall gates at that floor', () => {
  const output = '- QUOTE: "Larger chunks use more memory. Smaller chunks use more CPU." | RULE: generic tradeoff';
  assert.equal(assertDetection(output, { vars: { ...detVars, min_recall: 0.5 } }).pass, true);
  assert.equal(assertDetection(output, { vars: { ...detVars, min_recall: 0.6 } }).pass, false);
});

const adjacentVars = {
  violations: [
    { quote: 'The creator of Bun spent the tokens. It took eleven days. A model wrote the commits.', rule: 'drumbeat' },
    { quote: 'Developers did not take it well. Soon it will run on that rewrite. We are users now.', rule: 'drumbeat' },
  ],
  traps: [],
};

// Seen on a CI run: one subject line quoting the first paragraph and the
// opening sentence of the next was credited to both violations.
test('detection credits a quote that runs from one key into the next to the key it holds whole', () => {
  const output = '- QUOTE: "The creator of Bun spent the tokens. It took eleven days. A model wrote the commits. Developers did not take it well." | RULE: drumbeat';
  const result = assertDetection(output, { vars: adjacentVars });
  assert.equal(result.pass, false);
  assert.match(result.reason, /1\/2 violations/);
});

test('detection credits a fragment straddling two keys to the one it overlaps most', () => {
  const output = '- QUOTE: "It took eleven days. A model wrote the commits. Developers did not take" | RULE: drumbeat';
  const result = assertDetection(output, { vars: adjacentVars });
  assert.match(result.reason, /1\/2 violations.*missed: Developers/);
});

test('detection credits a quote holding two whole keys to both', () => {
  const output = `- QUOTE: "${adjacentVars.violations[0].quote} ${adjacentVars.violations[1].quote}" | RULE: drumbeat`;
  const result = assertDetection(output, { vars: adjacentVars });
  assert.equal(result.pass, true, result.reason);
});

// Overlap matching is symmetric enough that a violation quote sharing a run of
// text with a trap would flag the trap on a correct answer; keep the fixtures
// free of that.
test('no detection case has a violation quote that would itself trip one of its traps', () => {
  for (const file of findSuites(REPO_ROOT)) {
    const data = loadSuite(file);
    for (const item of data.cases.filter((c) => c.type === 'detection')) {
      for (const violation of item.violations) {
        for (const trap of item.traps) {
          assert.ok(
            !quotesOverlap(trap.quote, violation.quote),
            `${data.skill}/${item.id}: violation "${violation.quote.slice(0, 40)}" overlaps trap "${trap.quote.slice(0, 40)}"`,
          );
        }
      }
    }
  }
});
