import test from 'node:test';
import assert from 'node:assert/strict';
import { normalize, keywordOverlap } from '../asserts/heuristics.mjs';

test('normalize lowercases, straightens smart quotes, collapses whitespace', () => {
  assert.equal(normalize('  “Hello”\n\t‘World’  '), '"hello" \'world\'');
});

test('keywordOverlap is 1 when candidate restates the reference', () => {
  const reference = 'delete generic tradeoffs that do not explain the chosen value';
  assert.equal(keywordOverlap(reference, reference), 1);
});

test('keywordOverlap is 0 for unrelated text', () => {
  assert.equal(keywordOverlap('completely different words entirely', 'delete generic tradeoffs'), 0);
});

test('keywordOverlap ignores stop words and short words', () => {
  // "that", "with", "this" are stop words; "the", "a" are <= 3 chars.
  const score = keywordOverlap('placement decides that', 'that placement with this decides');
  assert.equal(score, 1);
});
