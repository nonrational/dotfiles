import { readFileSync, readdirSync, existsSync, lstatSync } from 'node:fs';
import path from 'node:path';
import { normalize } from '../asserts/heuristics.mjs';

export const SUPPORTED_TYPES = new Set([
  'discrimination',
  'discrimination-structural',
  'discrimination-rank',
  'transformation',
  'detection',
]);

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

  if (data.min_pass_rate !== undefined) {
    const rate = data.min_pass_rate;
    if (typeof rate !== 'number' || !(rate > 0 && rate <= 1)) {
      throw new Error('min_pass_rate must be a number in (0, 1]');
    }
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

    // The flag softens the hard choice gate, so the case must say why.
    if (item.arguable !== undefined) {
      if (typeof item.arguable !== 'boolean') throw new Error(`${item.id}.arguable must be a boolean`);
      if (item.arguable && !item.type.startsWith('discrimination')) {
        throw new Error(`${item.id}.arguable applies only to discrimination cases`);
      }
      if (item.arguable && !item.grading_note) {
        throw new Error(`${item.id}.arguable needs a grading_note saying why`);
      }
    }

    if (item.type === 'discrimination' || item.type === 'discrimination-structural') {
      requireField(item.prompt, `${item.id}.prompt`);
      requireField(item.expected_rule, `${item.id}.expected_rule`);
      if (!item.variants || Object.keys(item.variants).length < 2) {
        throw new Error(`${item.id}.variants must contain at least two choices`);
      }
      if (!Object.hasOwn(item.variants, item.correct)) {
        throw new Error(`${item.id}.correct does not name a variant`);
      }
    }

    if (item.type === 'discrimination-rank') {
      requireField(item.prompt, `${item.id}.prompt`);
      requireField(item.expected_rule_for_worst, `${item.id}.expected_rule_for_worst`);
      const stages = Object.keys(item.stages ?? {});
      if (stages.length < 2) {
        throw new Error(`${item.id}.stages must contain at least two choices`);
      }
      const ranking = Array.isArray(item.correct_ranking) ? item.correct_ranking : [];
      if ([...ranking].sort().join('\n') !== [...stages].sort().join('\n')) {
        throw new Error(`${item.id}.correct_ranking must order every stage exactly once`);
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

    // Alternatives the rule judge accepts besides expected_rule; only
    // discrimination cases have a stated rule to judge.
    if (item.accepted_rules !== undefined) {
      if (!item.type.startsWith('discrimination')) {
        throw new Error(`${item.id}.accepted_rules applies only to discrimination cases`);
      }
      const rules = item.accepted_rules;
      if (!Array.isArray(rules) || rules.length === 0 || rules.some((rule) => typeof rule !== 'string' || rule === '')) {
        throw new Error(`${item.id}.accepted_rules must be a non-empty array of rule strings`);
      }
    }

    // Below 1 the case records recall as its score instead of failing on a
    // non-exhaustive violation list; only detection has recall to floor.
    if (item.min_recall !== undefined) {
      if (item.type !== 'detection') {
        throw new Error(`${item.id}.min_recall applies only to detection cases`);
      }
      if (typeof item.min_recall !== 'number' || !(item.min_recall >= 0 && item.min_recall <= 1)) {
        throw new Error(`${item.id}.min_recall must be a number in [0, 1]`);
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
      // The grader matches by text overlap, so a quote the document does not
      // contain verbatim (an ellipsis, a paraphrase) can never be found or
      // tripped.
      const document = normalize(item.input_document);
      for (const { quote } of [...item.violations, ...item.traps]) {
        if (!document.includes(normalize(quote))) {
          throw new Error(`${item.id} quote is not in input_document verbatim: "${quote.slice(0, 40)}"`);
        }
      }
    }
  }

  return { caseCount: data.cases.length, unsupported };
}
