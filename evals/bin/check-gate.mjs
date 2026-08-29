#!/usr/bin/env node
// Gate semantics from the design spec: deterministic cases must all pass;
// judged (transformation) cases only drag the suite below a pass-rate floor.
import { readFileSync } from 'node:fs';

const [, , resultsPath, minRateArg] = process.argv;
const minRate = Number(minRateArg ?? '0.90');

if (!resultsPath) {
  console.error('usage: check-gate.mjs <results.json> [minRate]');
  process.exit(1);
}

let data;
try {
  data = JSON.parse(readFileSync(resultsPath, 'utf8'));
} catch (error) {
  console.error(`cannot read ${resultsPath}: ${error.message}`);
  process.exit(1);
}

const rows = Array.isArray(data.results?.results)
  ? data.results.results
  : Array.isArray(data.results)
    ? data.results
    : null;
if (!rows || rows.length === 0) {
  console.error('unrecognized or empty promptfoo results format');
  process.exit(1);
}

const meta = (row) => row.testCase?.metadata ?? row.metadata ?? {};
const JUDGED_TYPES = new Set(['transformation']);

const deterministicFailures = rows.filter(
  (row) => !row.success && !JUDGED_TYPES.has(meta(row).case_type),
);
const passed = rows.filter((row) => row.success).length;
const passRate = passed / rows.length;

console.log(`${passed}/${rows.length} passed (rate ${(passRate * 100).toFixed(1)}%, floor ${(minRate * 100).toFixed(0)}%)`);

let failed = false;
if (deterministicFailures.length > 0) {
  failed = true;
  console.error('deterministic failures (these always gate):');
  for (const row of deterministicFailures) {
    console.error(`  ${meta(row).case_id ?? '(unknown case)'}`);
  }
}
if (passRate < minRate) {
  failed = true;
  console.error(`pass rate ${(passRate * 100).toFixed(1)}% is below the ${(minRate * 100).toFixed(0)}% floor`);
}

process.exit(failed ? 1 : 0);
