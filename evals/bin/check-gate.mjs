#!/usr/bin/env node
// Gate semantics from the design spec: only a wrong discrimination choice
// (the assert tagged metric "choice") or a subject that never answered gates
// outright. Judged asserts and detection only drag the suite toward a
// pass-rate floor.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { findSuites, loadSuite, suiteSkill } from '../lib/load-evals.mjs';

// EVAL_REPO_ROOT lets the unit tests point the gate at a throwaway skills tree.
const REPO_ROOT = process.env.EVAL_REPO_ROOT ?? path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const DEFAULT_MIN_RATE = 0.9;

const [, , resultsPath, minRateArg] = process.argv;

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

// A draft case has not been approved by its author, so it runs for
// information only: it can neither hard-gate on a wrong choice nor move the
// floor. A subject that never answered is a different failure mode though;
// it measures the harness (a provider or CLI error), not the key, so it
// fails the run whatever the row's status.
const isDraft = (row) => meta(row).status === 'draft';

// A subject error leaves no components; a judge error still leaves the
// choice component, so it stays soft. A case whose author flagged the answer
// key arguable never gates on the choice (the miss still counts against the
// floor), but a subject that gave no answer gates regardless, draft or not.
const isHardFailure = (row) =>
  !row.success &&
  (components(row).length === 0 ||
    (!isDraft(row) &&
      meta(row).arguable !== true &&
      components(row).some((c) => !c.pass && c.assertion?.metric === 'choice')));

// The rule judgment is recorded but never counts: a passage breaks more than
// one rule, and the judge rejects a true rule the key did not name. A row
// whose only failed asserts are informational passes for the floor.
const INFORMATIONAL_METRICS = new Set(['rule']);
const isInformational = (component) => INFORMATIONAL_METRICS.has(component.assertion?.metric);
const countsAsPassed = (row) =>
  row.success ||
  (components(row).length > 0 && components(row).every((c) => c.pass || isInformational(c)));

// Precedence: argv, then the skill's own `min_pass_rate` in evals/README.md, then
// the default. A skill whose keys are contested or whose detection cases
// record recall instead of failing (prose-register) can carry a lower floor
// than one whose cases all have a single right answer.
//
// Only the named skill's file is parsed (the generator locates it the same
// way), so a sibling's broken evals/README.md cannot fail this gate; an unreadable
// one falls back to the stricter default and says so.
function skillMinRate(skill) {
  if (!skill) return undefined;
  try {
    const file = findSuites(REPO_ROOT).find((candidate) => suiteSkill(candidate) === skill);
    return file ? loadSuite(file).min_pass_rate : undefined;
  } catch (error) {
    console.error(`cannot read ${skill}'s min_pass_rate, using the default: ${error.message}`);
    return undefined;
  }
}

// A results file that mixes skills has no single floor to apply.
const skills = new Set(rows.map((row) => meta(row).skill));
const skill = skills.size === 1 ? [...skills][0] : undefined;
const minRate = Number(minRateArg ?? skillMinRate(skill) ?? DEFAULT_MIN_RATE);
// Number('') is 0 and Number('abc') is NaN; either would let any run pass.
if (!(minRate > 0 && minRate <= 1)) {
  console.error('floor must be a number in (0, 1]');
  process.exit(1);
}

const gated = rows.filter((row) => !isDraft(row));
const drafts = rows.filter(isDraft);

// Hard failures are checked over every row, draft or not: a subject that
// never answered still fails the run. passed/passRate/informational stay
// scoped to gated rows, the population the floor applies to.
const hardFailures = rows.filter(isHardFailure);
const passed = gated.filter(countsAsPassed).length;
const passRate = gated.length ? passed / gated.length : 1;

// Scoped to gated rows so this count shares a population with the N/N passed fraction beside it.
const informational = gated.flatMap((row) => components(row).filter(isInformational));
const informationalNote = informational.length
  ? `; rule ${informational.filter((c) => c.pass).length}/${informational.length} informational`
  : '';
const draftNote = drafts.length ? `; ${drafts.length} draft rows, ${drafts.filter(countsAsPassed).length} passed` : '';
const gatedSummary = gated.length
  ? `${passed}/${gated.length} passed (rate ${(passRate * 100).toFixed(1)}%, floor ${(minRate * 100).toFixed(0)}%)`
  : 'no approved rows; nothing gated';
console.log(`${gatedSummary}${informationalNote}${draftNote}`);

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
