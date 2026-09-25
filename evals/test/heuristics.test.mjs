import test from 'node:test';
import assert from 'node:assert/strict';
import { normalize } from '../asserts/heuristics.mjs';

test('normalize lowercases, straightens smart quotes, collapses whitespace', () => {
  assert.equal(normalize('  “Hello”\n\t‘World’  '), '"hello" \'world\'');
});
