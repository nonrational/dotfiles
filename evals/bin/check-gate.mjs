#!/usr/bin/env node
// Gate semantics from the design spec: only a wrong discrimination choice
// (the assert tagged metric "choice") or a subject that never answered gates
// outright. Judged asserts and detection only drag the suite toward a
// pass-rate floor.
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
const components = (row) => row.gradingResult?.componentResults ?? [];

// A subject error leaves no components; a judge error still leaves the
// choice component, so it stays soft. A case whose author flagged the answer
// key arguable never gates on the choice (the miss still counts against the
// floor), but a subject that gave no answer gates regardless.
const isHardFailure = (row) =>
  !row.success &&
  (components(row).length === 0 ||
    (meta(row).arguable !== true &&
      components(row).some((c) => !c.pass && c.assertion?.metric === 'choice')));

const hardFailures = rows.filter(isHardFailure);
const passed = rows.filter((row) => row.success).length;
const passRate = passed / rows.length;

console.log(`${passed}/${rows.length} passed (rate ${(passRate * 100).toFixed(1)}%, floor ${(minRate * 100).toFixed(0)}%)`);

let failed = false;
if (hardFailures.length > 0) {
  failed = true;
  console.error('hard failures (wrong choice or no answer; these always gate):');
  for (const row of hardFailures) {
    console.error(`  ${meta(row).case_id ?? '(unknown case)'}`);
  }
}
if (passRate < minRate) {
  failed = true;
  console.error(`pass rate ${(passRate * 100).toFixed(1)}% is below the ${(minRate * 100).toFixed(0)}% floor`);
}

process.exit(failed ? 1 : 0);
