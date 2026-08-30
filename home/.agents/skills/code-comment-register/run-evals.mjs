#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '../../../..');
const EVALS_PATH = path.join(__dirname, 'evals.json');
const CONCURRENCY = 4;
const CASE_TYPES = new Set(['discrimination', 'transformation', 'detection']);

function parseArgs(argv) {
  const opts = {
    model: 'sonnet',
    judge: false,
    judgeModel: null,
    only: null,
    out: null,
    baseline: false,
    compare: false,
    validate: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];

    if (arg === '--model') opts.model = argv[++i];
    else if (arg === '--judge') opts.judge = true;
    else if (arg === '--judge-model') opts.judgeModel = argv[++i];
    else if (arg === '--only') opts.only = argv[++i].split(',').map((id) => id.trim());
    else if (arg === '--out') opts.out = argv[++i];
    else if (arg === '--baseline') opts.baseline = true;
    else if (arg === '--compare') opts.compare = true;
    else if (arg === '--validate') opts.validate = true;
    else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      console.error(`Unknown argument: ${arg}`);
      printHelp();
      process.exit(1);
    }
  }

  if (!opts.judgeModel) opts.judgeModel = opts.model;

  if (opts.baseline && opts.compare) {
    console.error('--baseline and --compare are mutually exclusive.');
    process.exit(1);
  }

  return opts;
}

function printHelp() {
  console.log(`Usage: node run-evals.mjs [options]

  --model <alias>        Model under test (default: sonnet)
  --judge                Grade transformation cases with a second model call
  --judge-model <alias>  Judge model (default: subject model)
  --only <id,id,...>     Run only selected case ids
  --out <path>           Write full transcripts and grades to this path
  --baseline             Disable skills for the subject calls
  --compare              Run each case with and without skills
  --validate             Validate evals.json without model calls
  --help                 Show this help

Model runs use real API capacity. Use --validate first and --only while
iterating.`);
}

function requireField(value, label) {
  if (value === undefined || value === null || value === '') {
    throw new Error(`Missing ${label}`);
  }
}

function validateData(data) {
  if (data.skill !== 'code-comment-register') {
    throw new Error(`Expected skill "code-comment-register", got ${JSON.stringify(data.skill)}`);
  }

  if (!Array.isArray(data.cases) || data.cases.length === 0) {
    throw new Error('cases must be a non-empty array');
  }

  const ids = new Set();

  for (const item of data.cases) {
    requireField(item.id, 'case.id');
    requireField(item.type, `${item.id}.type`);

    if (ids.has(item.id)) throw new Error(`Duplicate case id: ${item.id}`);
    ids.add(item.id);

    if (!CASE_TYPES.has(item.type)) {
      throw new Error(`${item.id} has unknown type ${JSON.stringify(item.type)}`);
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

      for (const key of ['violation_fixed', 'placement', 'no_new_violation']) {
        requireField(item.rubric?.[key], `${item.id}.rubric.${key}`);
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
        requireField(trap.why_valid, `${item.id}.traps[].why_valid`);
      }
    }
  }

  return { caseCount: data.cases.length, ids };
}

function callClaude(prompt, { model, disableSkills }) {
  return new Promise((resolve, reject) => {
    const args = disableSkills
      ? ['-p', '--output-format', 'json', '--model', model, '--disable-slash-commands']
      : ['-p', '--output-format', 'json', '--model', model, '--allowedTools', 'Skill'];
    const proc = spawn('claude', args, { cwd: REPO_ROOT });
    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (chunk) => {
      stdout += chunk;
    });

    proc.stderr.on('data', (chunk) => {
      stderr += chunk;
    });

    proc.on('error', reject);

    proc.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`claude exited ${code}: ${stderr.slice(0, 2000)}`));
        return;
      }

      try {
        const parsed = JSON.parse(stdout);

        if (parsed.is_error) {
          reject(new Error(`claude reported an error: ${parsed.result}`));
          return;
        }

        resolve(parsed);
      } catch (error) {
        reject(new Error(`Failed to parse claude output: ${error.message}\n${stdout.slice(0, 500)}`));
      }
    });

    proc.stdin.write(prompt);
    proc.stdin.end();
  });
}

async function mapPool(items, limit, fn) {
  const results = new Array(items.length);
  let nextIndex = 0;

  async function worker() {
    while (nextIndex < items.length) {
      const index = nextIndex++;

      try {
        results[index] = await fn(items[index]);
      } catch (error) {
        results[index] = {
          id: items[index].item.id,
          type: items[index].item.type,
          condition: items[index].condition,
          status: 'ERROR',
          error: String(error.message || error),
        };
      }
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

function normalize(value) {
  return value
    .toLowerCase()
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/\s+/g, ' ')
    .trim();
}

function keywordOverlap(candidate, reference) {
  const stopWords = new Set([
    'about',
    'after',
    'against',
    'also',
    'because',
    'before',
    'comment',
    'does',
    'every',
    'from',
    'have',
    'into',
    'only',
    'rather',
    'that',
    'their',
    'there',
    'these',
    'they',
    'this',
    'when',
    'where',
    'which',
    'with',
  ]);

  const words = (text) =>
    new Set(
      text
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, ' ')
        .split(/\s+/)
        .filter((word) => word.length > 3 && !stopWords.has(word)),
    );

  const candidateWords = words(candidate);
  const referenceWords = words(reference);
  if (referenceWords.size === 0) return 0;

  let shared = 0;
  for (const word of referenceWords) {
    if (candidateWords.has(word)) shared++;
  }

  return shared / referenceWords.size;
}

function buildDiscriminationPrompt(item) {
  const keys = Object.keys(item.variants);
  const letters = keys.map((_, index) => String.fromCharCode(65 + index));
  const letterToKey = Object.fromEntries(letters.map((letter, index) => [letter, keys[index]]));
  const listing = keys
    .map((key, index) => `${letters[index]}.\n${item.variants[key]}`)
    .join('\n\n');

  const prompt = `Review these inline source comments. Use the code-comment-register skill if it is available.

${item.prompt}

${listing}

Pick one version. Name the specific rule that decides it.

End with exactly these two lines and nothing after:
ANSWER: <letter>
RULE: <one sentence>`;

  return { prompt, letterToKey };
}

function buildTransformationPrompt(item) {
  return `Edit inline source comments. Use the code-comment-register skill if it is available.

${item.task}

Code:
${item.input}

Reply with only the revised code, nothing else.`;
}

function buildDetectionPrompt(item) {
  return `Review inline source comments. Use the code-comment-register skill if it is available.

${item.prompt}

Code:
${item.input_document}

List each violation on one line:
- QUOTE: "<exact offending comment text>" | RULE: <rule in your own words>

Reply only with violation lines in that format. Do not explain or mention
comments that pass the register.`;
}

function buildJudgePrompt(item, rewrite) {
  return `Grade a source-comment rewrite against the rubric. Similar wording is not required.

Rule:
${item.rule_quote || ''}

Task:
${item.task}

Original:
${item.input}

Reference:
${item.reference_after}

Rubric:
- violation_fixed: ${item.rubric.violation_fixed}
- placement: ${item.rubric.placement}
- no_new_violation: ${item.rubric.no_new_violation}

Notes:
${item.grading_note || 'None.'}

Candidate:
${rewrite}

End with exactly these four lines and nothing after:
VIOLATION_FIXED: yes|no
PLACEMENT: yes|no
NO_NEW_VIOLATION: yes|no
JUSTIFICATION: <one sentence>`;
}

function gradeDiscrimination(item, letterToKey, response) {
  const answerMatch = response.match(/ANSWER:\s*([A-Za-z])/i);
  const ruleMatch = response.match(/RULE:\s*([^\n]+)/i);
  const chosenKey = answerMatch ? letterToKey[answerMatch[1].toUpperCase()] : null;
  const ruleText = ruleMatch ? ruleMatch[1].trim() : '';
  const ruleOverlapScore = ruleText ? keywordOverlap(ruleText, item.expected_rule) : 0;
  const variantCorrect = chosenKey === item.correct;

  let status = 'FAIL';
  if (!answerMatch) status = 'REVIEW (unparsed answer)';
  else if (variantCorrect && ruleOverlapScore >= 0.2) status = 'PASS';
  else if (variantCorrect) status = 'REVIEW (correct choice, weak rule match)';

  return {
    status,
    grade: {
      chosenKey,
      correctKey: item.correct,
      variantCorrect,
      ruleText,
      expectedRule: item.expected_rule,
      ruleOverlapScore,
    },
  };
}

function gradeDetection(item, response) {
  const violationLines = response
    .split('\n')
    .filter((line) => /^-\s*QUOTE:/i.test(line))
    .join('\n');
  const normalized = normalize(violationLines);
  const hits = item.violations.map((violation) => ({
    ...violation,
    found: normalized.includes(normalize(violation.quote).slice(0, 60)),
  }));
  const trapHits = item.traps
    .filter((trap) => normalized.includes(normalize(trap.quote).slice(0, 40)))
    .map((trap) => trap.quote);
  const found = hits.filter((hit) => hit.found).length;
  const status =
    found === hits.length && trapHits.length === 0
      ? 'PASS'
      : `REVIEW (${found}/${hits.length} violations, ${trapHits.length} traps)`;

  return { status, grade: { found, total: hits.length, hits, trapHits } };
}

function parseJudge(response) {
  const yesNo = (pattern) => {
    const match = response.match(pattern);
    return match ? match[1].toLowerCase() === 'yes' : null;
  };
  const justification = response.match(/JUSTIFICATION:\s*(.+)/i);

  return {
    violationFixed: yesNo(/VIOLATION_FIXED:\s*(yes|no)/i),
    placement: yesNo(/PLACEMENT:\s*(yes|no)/i),
    noNewViolation: yesNo(/NO_NEW_VIOLATION:\s*(yes|no)/i),
    justification: justification ? justification[1].trim() : '',
    raw: response,
  };
}

async function runCase(item, opts, condition) {
  const disableSkills = condition === 'baseline';
  const tag = { id: item.id, type: item.type, condition };

  if (item.type === 'discrimination') {
    const { prompt, letterToKey } = buildDiscriminationPrompt(item);
    const result = await callClaude(prompt, { model: opts.model, disableSkills });
    const response = result.result || '';
    const graded = gradeDiscrimination(item, letterToKey, response);

    return {
      ...tag,
      ...graded,
      cost: result.total_cost_usd || 0,
      subjectPrompt: prompt,
      subjectResponse: response,
    };
  }

  if (item.type === 'transformation') {
    const prompt = buildTransformationPrompt(item);
    const result = await callClaude(prompt, { model: opts.model, disableSkills });
    const rewrite = (result.result || '').trim();
    let cost = result.total_cost_usd || 0;
    let judge = null;
    let status = 'REVIEW (manual grading; pass --judge to auto-grade)';

    if (opts.judge) {
      const judgePrompt = buildJudgePrompt(item, rewrite);
      const judged = await callClaude(judgePrompt, {
        model: opts.judgeModel,
        disableSkills: true,
      });
      judge = parseJudge(judged.result || '');
      cost += judged.total_cost_usd || 0;
      status =
        judge.violationFixed && judge.placement && judge.noNewViolation ? 'PASS' : 'FAIL';
    }

    return {
      ...tag,
      status,
      cost,
      subjectPrompt: prompt,
      rewrite,
      referenceAfter: item.reference_after,
      judge,
    };
  }

  if (item.type === 'detection') {
    const prompt = buildDetectionPrompt(item);
    const result = await callClaude(prompt, { model: opts.model, disableSkills });
    const response = result.result || '';
    const graded = gradeDetection(item, response);

    return {
      ...tag,
      ...graded,
      cost: result.total_cost_usd || 0,
      subjectPrompt: prompt,
      subjectResponse: response,
    };
  }

  return { ...tag, status: 'SKIPPED' };
}

function printSummary(results, totalCost, compare) {
  console.log('\n=== Summary ===');

  if (!compare) {
    for (const result of results) {
      console.log(`${result.id.padEnd(10)} ${result.type.padEnd(16)} ${result.status}`);
    }

    const pass = results.filter((result) => result.status === 'PASS').length;
    const fail = results.filter((result) => result.status === 'FAIL').length;
    const review = results.length - pass - fail;
    console.log(`\n${pass} pass, ${fail} fail, ${review} review, ${results.length} total.`);
  } else {
    const byId = new Map();

    for (const result of results) {
      if (!byId.has(result.id)) byId.set(result.id, {});
      byId.get(result.id)[result.condition] = result;
    }

    let changed = 0;

    for (const [id, conditions] of byId) {
      const skill = conditions.skill?.status || '(missing)';
      const baseline = conditions.baseline?.status || '(missing)';
      const same = skill === baseline;
      if (!same) changed++;
      console.log(
        `${id.padEnd(10)} skill=${skill.padEnd(34)} baseline=${baseline.padEnd(34)} ${
          same ? '(no change)' : '(changed)'
        }`,
      );
    }

    console.log(`\n${changed}/${byId.size} case statuses changed when the skill was available.`);
  }

  console.log(`Total cost: $${totalCost.toFixed(4)}`);
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const data = JSON.parse(readFileSync(EVALS_PATH, 'utf8'));
  const validation = validateData(data);

  if (opts.validate) {
    console.log(`Validated ${validation.caseCount} code-comment-register eval cases.`);
    return;
  }

  let cases = data.cases;

  if (opts.only) {
    cases = cases.filter((item) => opts.only.includes(item.id));
    const missing = opts.only.filter((id) => !cases.some((item) => item.id === id));
    if (missing.length > 0) console.error(`Warning: unknown case ids: ${missing.join(', ')}`);
  }

  if (cases.length === 0) {
    console.error('No matching cases to run.');
    process.exit(1);
  }

  const conditions = opts.compare
    ? ['skill', 'baseline']
    : [opts.baseline ? 'baseline' : 'skill'];
  const work = cases.flatMap((item) =>
    conditions.map((condition) => ({ item, condition })),
  );

  console.log(
    `Running ${cases.length} case(s) x ${conditions.length} condition(s) with model=${opts.model}.`,
  );

  let totalCost = 0;
  const results = await mapPool(work, CONCURRENCY, async ({ item, condition }) => {
    const result = await runCase(item, opts, condition);
    totalCost += result.cost || 0;
    console.log(`[${condition}] [${result.status}] ${item.id}`);
    return result;
  });

  printSummary(results, totalCost, opts.compare);

  const outPath =
    opts.out ||
    path.join(
      __dirname,
      'results',
      `${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
    );

  mkdirSync(path.dirname(outPath), { recursive: true });
  writeFileSync(
    outPath,
    JSON.stringify(
      {
        model: opts.model,
        judgeModel: opts.judge ? opts.judgeModel : null,
        compare: opts.compare,
        baseline: opts.baseline,
        totalCostUsd: totalCost,
        results,
      },
      null,
      2,
    ),
  );

  console.log(`\nFull transcript: ${outPath}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
