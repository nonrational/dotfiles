#!/usr/bin/env node
// Offline structural validation of every eval suite: zero model calls.
// Unsupported case types warn rather than fail, so a new type can be
// authored as a case file before the generator grades it.
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { findSuites, loadSuite, suiteSkill, validateData } from '../lib/load-evals.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

const files = findSuites(REPO_ROOT);
if (files.length === 0) {
  console.error('no evals/README.md files found under home/.agents/skills');
  process.exit(1);
}

let failed = false;
for (const file of files) {
  const skill = suiteSkill(file);
  try {
    const { caseCount, unsupported, draftCount } = validateData(loadSuite(file));
    const warning = unsupported.length
      ? ` (${unsupported.length} case(s) of unsupported type skipped: ${[...new Set(unsupported.map((u) => u.type))].join(', ')})`
      : '';
    console.log(`${skill}: ${caseCount} cases ok${draftCount ? ` (${draftCount} draft)` : ''}${warning}`);
  } catch (error) {
    failed = true;
    console.error(`${skill}: INVALID — ${error.message}`);
  }
}

process.exit(failed ? 1 : 0);
