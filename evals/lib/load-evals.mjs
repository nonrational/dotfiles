import { readFileSync, readdirSync, existsSync, lstatSync } from 'node:fs';
import path from 'node:path';

export const SUPPORTED_TYPES = new Set(['discrimination', 'transformation', 'detection']);

export function findEvalFiles(repoRoot) {
  const skillsDir = path.join(repoRoot, 'home/.agents/skills');
  const files = [];
  for (const entry of readdirSync(skillsDir)) {
    const dir = path.join(skillsDir, entry);
    // Vendored skills are symlinks into the submodule; only real directories
    // in this repo can carry evals we maintain.
    if (lstatSync(dir).isSymbolicLink() || !lstatSync(dir).isDirectory()) continue;
    const evalsPath = path.join(dir, 'evals.json');
    if (existsSync(evalsPath)) files.push(evalsPath);
  }
  return files.sort();
}

export function loadEvals(evalsPath) {
  return JSON.parse(readFileSync(evalsPath, 'utf8'));
}

function requireField(value, label) {
  if (value === undefined || value === null || value === '') {
    throw new Error(`Missing ${label}`);
  }
}

export function validateData(data) {
  requireField(data.skill, 'skill');
  if (!Array.isArray(data.cases) || data.cases.length === 0) {
    throw new Error('cases must be a non-empty array');
  }

  const ids = new Set();
  const unsupported = [];

  for (const item of data.cases) {
    requireField(item.id, 'case.id');
    requireField(item.type, `${item.id}.type`);
    if (ids.has(item.id)) throw new Error(`Duplicate case id: ${item.id}`);
    ids.add(item.id);

    if (!SUPPORTED_TYPES.has(item.type)) {
      unsupported.push({ id: item.id, type: item.type });
      continue;
    }

    if (item.type === 'discrimination') {
      requireField(item.prompt, `${item.id}.prompt`);
      requireField(item.expected_rule, `${item.id}.expected_rule`);
      if (!item.variants || Object.keys(item.variants).length < 2) {
        throw new Error(`${item.id}.variants must contain at least two choices`);
      }
      if (!Object.hasOwn(item.variants, item.correct)) {
        throw new Error(`${item.id}.correct does not name a variant`);
      }
    }

    if (item.type === 'transformation') {
      requireField(item.input, `${item.id}.input`);
      requireField(item.task, `${item.id}.task`);
      requireField(item.reference_after, `${item.id}.reference_after`);
      if (!item.rubric || typeof item.rubric !== 'object' || Array.isArray(item.rubric) || Object.keys(item.rubric).length === 0) {
        throw new Error(`${item.id}.rubric must be a non-empty object`);
      }
      for (const key in item.rubric) {
        requireField(item.rubric[key], `${item.id}.rubric.${key}`);
      }
    }

    if (item.type === 'detection') {
      requireField(item.prompt, `${item.id}.prompt`);
      requireField(item.input_document, `${item.id}.input_document`);
      if (!Array.isArray(item.violations) || item.violations.length === 0) {
        throw new Error(`${item.id}.violations must be non-empty`);
      }
      if (!Array.isArray(item.traps)) {
        throw new Error(`${item.id}.traps must be an array`);
      }
      for (const violation of item.violations) {
        requireField(violation.quote, `${item.id}.violations[].quote`);
        requireField(violation.rule, `${item.id}.violations[].rule`);
      }
      for (const trap of item.traps) {
        requireField(trap.quote, `${item.id}.traps[].quote`);
      }
    }
  }

  return { caseCount: data.cases.length, unsupported };
}
