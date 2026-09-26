import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { findSuites, loadSuite, suiteSkill, validateData, SUPPORTED_TYPES } from './lib/load-evals.mjs';
import { buildSubjectPrompt, buildTransformationRubric, buildRuleRubric } from './lib/prompts.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const JUDGE_PROVIDER = 'file://providers/judge.mjs';
const RUBRIC_THRESHOLD = 0.75;

// promptfoo renders every var value and every llm-rubric value as nunjucks; case text
// (e.g. Hugo shortcodes in prose-register's documents) must pass through literally.
const literal = (text) => `{% raw %}${text}{% endraw %}`;

const judged = (value, metric) => ({
  type: 'llm-rubric',
  value: literal(value),
  metric,
  threshold: RUBRIC_THRESHOLD,
  provider: JUDGE_PROVIDER,
});

function csvEnv(name) {
  const raw = process.env[name];
  return raw ? raw.split(',').map((s) => s.trim()).filter(Boolean) : null;
}

export default async function generateTests() {
  const skillName = process.env.EVAL_SKILL;
  if (!skillName) {
    throw new Error('EVAL_SKILL is required (e.g. EVAL_SKILL=code-comment-register)');
  }

  const readme = findSuites(REPO_ROOT).find((file) => suiteSkill(file) === skillName);
  if (!readme) {
    throw new Error(`no evals/README.md found for skill "${skillName}" under home/.agents/skills`);
  }

  const data = loadSuite(readme);
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
      vars: { subject_prompt: literal(prompt) },
      metadata: { skill: data.skill, case_id: item.id, case_type: item.type, ...(item.arguable && { arguable: true }) },
    };

    if (item.type.startsWith('discrimination')) {
      base.vars.letter_to_key = letterToKey;
      // promptfoo expands array vars into one test per element; join to a string to keep one row per case.
      if (item.type === 'discrimination-rank') base.vars.correct_ranking = item.correct_ranking.join(',');
      else base.vars.correct = item.correct;
      base.assert = [
        { type: 'javascript', value: 'file://asserts/discrimination.mjs', metric: 'choice' },
        judged(buildRuleRubric(item), 'rule'),
      ];
    } else if (item.type === 'detection') {
      base.vars.violations = item.violations;
      base.vars.traps = item.traps;
      if (item.min_recall !== undefined) base.vars.min_recall = item.min_recall;
      base.assert = [{ type: 'javascript', value: 'file://asserts/detection.mjs' }];
    } else {
      base.assert = [judged(buildTransformationRubric(item), 'rubric')];
    }

    return base;
  });
}
