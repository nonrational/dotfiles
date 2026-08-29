#!/usr/bin/env node
// Offline structural validation of every evals.json — zero model calls.
// Unsupported case types warn rather than fail until Phase 2 grades them.
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { findEvalFiles, loadEvals, validateData } from '../lib/load-evals.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

const files = findEvalFiles(REPO_ROOT);
if (files.length === 0) {
  console.error('no evals.json files found under home/.agents/skills');
  process.exit(1);
}

let failed = false;
for (const file of files) {
  const skill = path.basename(path.dirname(file));
  try {
    const { caseCount, unsupported } = validateData(loadEvals(file));
    const warning = unsupported.length
      ? ` (${unsupported.length} case(s) of unsupported type skipped: ${[...new Set(unsupported.map((u) => u.type))].join(', ')})`
      : '';
    console.log(`${skill}: ${caseCount} cases ok${warning}`);
  } catch (error) {
    failed = true;
    console.error(`${skill}: INVALID — ${error.message}`);
  }
}

process.exit(failed ? 1 : 0);
