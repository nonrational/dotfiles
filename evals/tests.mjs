import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { findEvalFiles, loadEvals, validateData, SUPPORTED_TYPES } from './lib/load-evals.mjs';
import { buildSubjectPrompt, buildTransformationRubric } from './lib/prompts.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const JUDGE_PROVIDER = 'anthropic:messages:claude-sonnet-5';
const RUBRIC_THRESHOLD = 0.75;

function csvEnv(name) {
  const raw = process.env[name];
  return raw ? raw.split(',').map((s) => s.trim()).filter(Boolean) : null;
}

export default async function generateTests() {
  const skillName = process.env.EVAL_SKILL;
  if (!skillName) {
    throw new Error('EVAL_SKILL is required (e.g. EVAL_SKILL=code-comment-register)');
  }

  const evalsPath = findEvalFiles(REPO_ROOT).find(
    (file) => path.basename(path.dirname(file)) === skillName,
  );
  if (!evalsPath) {
    throw new Error(`no evals.json found for skill "${skillName}" under home/.agents/skills`);
  }

  const data = loadEvals(evalsPath);
  validateData(data);

  const onlyIds = csvEnv('EVAL_ONLY');
  const onlyTypes = csvEnv('EVAL_TYPES');

  const cases = data.cases.filter(
    (item) =>
      SUPPORTED_TYPES.has(item.type) &&
      (!onlyIds || onlyIds.includes(item.id)) &&
      (!onlyTypes || onlyTypes.includes(item.type)),
  );
  if (cases.length === 0) {
    throw new Error('no cases match the EVAL_ONLY / EVAL_TYPES filters');
  }

  return cases.map((item) => {
    const { prompt, letterToKey } = buildSubjectPrompt(data.skill, item);
    const base = {
      description: `${item.id} (${item.type})`,
      vars: { subject_prompt: prompt },
      metadata: { skill: data.skill, case_id: item.id, case_type: item.type },
    };

    if (item.type === 'discrimination') {
      base.vars.letter_to_key = letterToKey;
      base.vars.correct = item.correct;
      base.vars.expected_rule = item.expected_rule;
      base.assert = [{ type: 'javascript', value: 'file://asserts/discrimination.mjs' }];
    } else if (item.type === 'detection') {
      base.vars.violations = item.violations;
      base.vars.traps = item.traps;
      base.assert = [{ type: 'javascript', value: 'file://asserts/detection.mjs' }];
    } else {
      base.assert = [
        {
          type: 'llm-rubric',
          value: buildTransformationRubric(item),
          threshold: RUBRIC_THRESHOLD,
          provider: JUDGE_PROVIDER,
        },
      ];
    }

    return base;
  });
}
