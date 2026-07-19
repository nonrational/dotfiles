#!/usr/bin/env node
// Runner for the prose-register eval cases in evals.json.
//
// Spawns `claude -p` once per case (the model under test never sees the
// case's rule_quote/expected_rule/reference_after/rubric fields -- those are
// the answer key, used only for grading). Discrimination and detection cases
// are graded automatically with light heuristics; transformation cases are
// left for manual review unless --judge is passed, since that grading is
// inherently subjective (per evals-handoff.md's own suggestion of "a second
// LLM-judge pass, or a human skim").
//
// Usage:
//   node run-evals.mjs [--model sonnet] [--judge] [--judge-model sonnet]
//                       [--only id[,id...]] [--out path.json]
//                       [--baseline] [--compare]
//
// --baseline runs the subject with `--disable-slash-commands`, which hides
// all skills (including prose-register) from the model -- this is the RED
// condition: does the model land on-register with no skill guidance at all?
// --compare runs every selected case under BOTH conditions (skill and
// baseline) and reports the delta, which is the actual question "should the
// skill be modified" depends on: a case that scores the same in both
// conditions means the skill isn't the lever for that case.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '../../../..');
const EVALS_PATH = path.join(__dirname, 'evals.json');
const CONCURRENCY = 4;

function parseArgs(argv) {
  const opts = { model: 'sonnet', judge: false, judgeModel: null, only: null, out: null, baseline: false, compare: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--model') opts.model = argv[++i];
    else if (a === '--judge') opts.judge = true;
    else if (a === '--judge-model') opts.judgeModel = argv[++i];
    else if (a === '--only') opts.only = argv[++i].split(',').map((s) => s.trim());
    else if (a === '--out') opts.out = argv[++i];
    else if (a === '--baseline') opts.baseline = true;
    else if (a === '--compare') opts.compare = true;
    else if (a === '--help' || a === '-h') { printHelp(); process.exit(0); }
    else { console.error(`Unknown arg: ${a}`); printHelp(); process.exit(1); }
  }
  if (!opts.judgeModel) opts.judgeModel = opts.model;
  if (opts.baseline && opts.compare) { console.error('--baseline and --compare are mutually exclusive (--compare already runs both conditions).'); process.exit(1); }
  return opts;
}

function printHelp() {
  console.log(`Usage: node run-evals.mjs [options]

  --model <alias>        Model under test (default: sonnet)
  --judge                Auto-grade transformation cases with an LLM judge
                          (one extra claude -p call per transformation case;
                          off by default -- without it, rewrites are saved
                          for manual review instead of scored)
  --judge-model <alias>  Model for judging (default: same as --model)
  --only <id,id,...>     Run only these case ids, e.g. disc-06,det-03
  --out <path>           Write the full transcript+grades here
                          (default: results/<timestamp>.json next to this script)
  --baseline              Run the subject with skills disabled (RED condition:
                          no prose-register guidance at all). Mutually
                          exclusive with --compare.
  --compare               Run every selected case under both the normal
                          (skill available) and --baseline conditions, and
                          print the delta. Roughly 2x the subject-call cost
                          of a normal run (judge calls, if --judge is set,
                          also roughly double).

Each claude -p call costs real API usage; --only is the cheap way to
iterate on the runner itself before spending on a full pass.`);
}

function callClaude(prompt, { model, cwd, disableSkills }) {
  return new Promise((resolve, reject) => {
    const args = disableSkills
      ? ['-p', '--output-format', 'json', '--model', model, '--disable-slash-commands']
      : ['-p', '--output-format', 'json', '--model', model, '--allowedTools', 'Skill'];
    const proc = spawn('claude', args, { cwd });
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d) => { stdout += d; });
    proc.stderr.on('data', (d) => { stderr += d; });
    proc.on('error', reject);
    proc.on('close', (code) => {
      if (code !== 0) return reject(new Error(`claude -p exited ${code}: ${stderr.slice(0, 2000)}`));
      try {
        const parsed = JSON.parse(stdout);
        if (parsed.is_error) return reject(new Error(`claude -p reported an error: ${parsed.result}`));
        resolve(parsed);
      } catch (e) {
        reject(new Error(`Failed to parse claude output: ${e.message}\n${stdout.slice(0, 500)}`));
      }
    });
    proc.stdin.write(prompt);
    proc.stdin.end();
  });
}

async function mapPool(items, limit, fn) {
  const results = new Array(items.length);
  let idx = 0;
  async function worker() {
    while (idx < items.length) {
      const i = idx++;
      try {
        results[i] = await fn(items[i], i);
      } catch (err) {
        results[i] = { id: items[i].id, type: items[i].type, status: 'ERROR', error: String(err.message || err) };
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

function normalize(s) {
  return s
    .toLowerCase()
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[—]/g, '—')
    .replace(/\s+/g, ' ')
    .trim();
}

function keywordOverlap(candidate, reference) {
  const stop = new Set(['the', 'a', 'an', 'and', 'or', 'but', 'is', 'are', 'to', 'of', 'in', 'on', 'not', 'it', 'its', 'that', 'this', 'with', 'as']);
  const words = (s) => new Set(s.replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter((w) => w.length > 3 && !stop.has(w)));
  const wc = words(candidate.toLowerCase());
  const wr = words(reference.toLowerCase());
  if (!wr.size) return 0;
  let shared = 0;
  for (const w of wr) if (wc.has(w)) shared++;
  return shared / wr.size;
}

// --- Prompt builders (only case.prompt/task/input content is sent -- never the answer key) ---

function buildDiscriminationPrompt(c) {
  const pool = c.variants || c.stages;
  const keys = Object.keys(pool);
  const letters = keys.map((_, i) => String.fromCharCode(65 + i));
  const letterToKey = Object.fromEntries(letters.map((l, i) => [l, keys[i]]));
  const listing = keys.map((k, i) => `${letters[i]}.\n${pool[k]}`).join('\n\n');
  const isRank = c.type === 'discrimination-rank';
  const instruction = isRank
    ? 'Rank these from most on-register to least on-register (e.g. "A,C,B").'
    : 'Pick the one on-register version.';
  const prompt = `${c.prompt}\n\n${listing}\n\n${instruction} Then name, in one sentence and your own words, the specific rule that decides it.\n\nEnd your reply with exactly these two lines and nothing after:\nANSWER: <letter or comma-separated letters>\nRULE: <one sentence>`;
  return { prompt, letterToKey };
}

function buildTransformationPrompt(c) {
  return `${c.task}\n\nText:\n${c.input}\n\nReply with only the rewritten passage, nothing else.`;
}

function buildJudgePrompt(c, rewrite) {
  return `You are grading a prose rewrite against a rubric. Do not reward superficial similarity to the reference; judge against the rubric criteria themselves.

Rule being applied: ${c.rule_quote || ''}
Task given to the writer: ${c.task}

Original text:
${c.input}

Reference (one acceptable good rewrite -- not the only correct answer):
${c.reference_after}

Rubric:
- violation_fixed: ${c.rubric.violation_fixed}
- no_new_violation: ${c.rubric.no_new_violation}
- voice_match: ${c.rubric.voice_match}

Notes from the eval author (may describe a known wrinkle in the reference itself -- weigh accordingly): ${c.grading_note || 'none'}

Candidate rewrite to grade:
${rewrite}

Score each rubric item, then justify briefly. End your reply with exactly these lines and nothing after:
VIOLATION_FIXED: yes|no
NO_NEW_VIOLATION: yes|no
VOICE_MATCH: yes|no
JUSTIFICATION: <one sentence>`;
}

function buildDetectionPrompt(c) {
  return `${c.prompt}\n\nDocument:\n${c.input_document}\n\nList each violation as one line:\n- QUOTE: "<exact offending text>" | RULE: <rule, in your own words>\nDon't pad the list if you find nothing else.`;
}

// --- Grading ---

function gradeDiscrimination(c, letterToKey, letters, ruleText) {
  const chosenKeys = letters.map((l) => letterToKey[l.toUpperCase()]).filter(Boolean);
  const variantCorrect = c.type === 'discrimination-rank'
    ? JSON.stringify(chosenKeys) === JSON.stringify(c.correct_ranking)
    : chosenKeys[0] === c.correct;
  const expectedRule = c.expected_rule || c.expected_rule_for_worst || c.rule_quote || '';
  const ruleOverlapScore = ruleText ? keywordOverlap(ruleText, expectedRule) : 0;
  return { chosenKeys, variantCorrect, ruleText, expectedRule, ruleOverlapScore };
}

function gradeDetection(c, responseText) {
  const norm = normalize(responseText);
  const hits = c.violations.map((v) => ({
    quote: v.quote,
    rule: v.rule,
    found: norm.includes(normalize(v.quote).slice(0, 60)),
  }));
  const trapHits = c.traps.filter((t) => norm.includes(normalize(t.quote).slice(0, 40))).map((t) => t.quote);
  return { found: hits.filter((h) => h.found).length, total: hits.length, hits, trapHits };
}

function parseJudge(text) {
  const get = (re) => { const m = text.match(re); return m ? m[1].trim().toLowerCase() === 'yes' : null; };
  const justMatch = text.match(/JUSTIFICATION:\s*(.+)/i);
  return {
    violationFixed: get(/VIOLATION_FIXED:\s*(yes|no)/i),
    noNewViolation: get(/NO_NEW_VIOLATION:\s*(yes|no)/i),
    voiceMatch: get(/VOICE_MATCH:\s*(yes|no)/i),
    justification: justMatch ? justMatch[1].trim() : '',
    raw: text,
  };
}

// --- Case runner ---

async function runCase(c, opts, condition) {
  const cwd = REPO_ROOT;
  const disableSkills = condition === 'baseline';
  const tag = { id: c.id, type: c.type, condition };

  if (c.type.startsWith('discrimination')) {
    const { prompt, letterToKey } = buildDiscriminationPrompt(c);
    const res = await callClaude(prompt, { model: opts.model, cwd, disableSkills });
    const text = res.result || '';
    const answerMatch = text.match(/ANSWER:\s*([^\n]+)/i);
    const ruleMatch = text.match(/RULE:\s*([^\n]+)/i);
    const letters = answerMatch ? answerMatch[1].match(/[A-Za-z]/g) || [] : [];
    const ruleText = ruleMatch ? ruleMatch[1].trim() : '';
    const grade = gradeDiscrimination(c, letterToKey, letters, ruleText);
    const status = !answerMatch ? 'REVIEW (unparsed response)' : grade.variantCorrect ? 'PASS' : 'FAIL';
    return { ...tag, status, cost: res.total_cost_usd, subjectPrompt: prompt, subjectResponse: text, grade };
  }

  if (c.type === 'transformation') {
    const prompt = buildTransformationPrompt(c);
    const res = await callClaude(prompt, { model: opts.model, cwd, disableSkills });
    const rewrite = (res.result || '').trim();
    let cost = res.total_cost_usd;
    let judge = null;
    let status = 'REVIEW (manual grading -- pass --judge to auto-grade)';
    if (opts.judge) {
      const judgePrompt = buildJudgePrompt(c, rewrite);
      const jres = await callClaude(judgePrompt, { model: opts.judgeModel, cwd, disableSkills: false });
      cost += jres.total_cost_usd;
      judge = parseJudge(jres.result || '');
      status = judge.violationFixed && judge.noNewViolation ? 'PASS' : 'FAIL';
    }
    return { ...tag, status, cost, subjectPrompt: prompt, rewrite, referenceAfter: c.reference_after, judge };
  }

  if (c.type === 'detection') {
    const prompt = buildDetectionPrompt(c);
    const res = await callClaude(prompt, { model: opts.model, cwd, disableSkills });
    const text = res.result || '';
    const grade = gradeDetection(c, text);
    const status = `REVIEW (${grade.found}/${grade.total} violations found${grade.trapHits.length ? `, ${grade.trapHits.length} possible over-flag` : ''})`;
    return { ...tag, status, cost: res.total_cost_usd, subjectPrompt: prompt, subjectResponse: text, grade };
  }

  return { ...tag, status: 'SKIPPED (unknown case type)' };
}

function printSummary(results, totalCost, compare) {
  console.log('\n=== Summary ===');
  if (!compare) {
    for (const r of results) console.log(`${r.id.padEnd(10)} ${r.type.padEnd(24)} ${r.status}`);
    const pass = results.filter((r) => r.status === 'PASS').length;
    const fail = results.filter((r) => r.status === 'FAIL').length;
    console.log(`\n${pass} pass, ${fail} fail, ${results.length - pass - fail} need manual review, of ${results.length} case(s).`);
  } else {
    const byId = new Map();
    for (const r of results) {
      if (!byId.has(r.id)) byId.set(r.id, {});
      byId.get(r.id)[r.condition] = r;
    }
    let changed = 0;
    for (const [id, { skill, baseline }] of byId) {
      const s = skill?.status ?? '(missing)';
      const b = baseline?.status ?? '(missing)';
      const same = s === b;
      if (!same) changed++;
      console.log(`${id.padEnd(10)} skill=${s.padEnd(28)} baseline=${b.padEnd(28)} ${same ? '(no change)' : '*** SKILL CHANGED THE ANSWER ***'}`);
    }
    console.log(`\n${changed}/${byId.size} case(s) where skill-available and baseline status differ.`);
    console.log(`A case with no change is your strongest signal the skill isn't the lever there -- check the raw transcript before concluding the skill is fine, since the automated status strings (e.g. detection's found/total) can match while the actual violations found differ.`);
  }
  console.log(`Total cost: $${totalCost.toFixed(4)}`);
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const data = JSON.parse(readFileSync(EVALS_PATH, 'utf8'));
  let cases = data.cases;
  if (opts.only) {
    cases = cases.filter((c) => opts.only.includes(c.id));
    const missing = opts.only.filter((id) => !cases.some((c) => c.id === id));
    if (missing.length) console.error(`Warning: no case(s) found for: ${missing.join(', ')}`);
  }
  if (!cases.length) { console.error('No matching cases to run.'); process.exit(1); }

  const conditions = opts.compare ? ['skill', 'baseline'] : [opts.baseline ? 'baseline' : 'skill'];
  const work = cases.flatMap((c) => conditions.map((condition) => ({ c, condition })));

  console.log(`Running ${cases.length} case(s) x ${conditions.length} condition(s) [${conditions.join(', ')}] against model=${opts.model}${opts.judge ? `, judge=${opts.judgeModel}` : ' (transformation cases saved for manual review; pass --judge to auto-grade)'}...`);

  let totalCost = 0;
  const results = await mapPool(work, CONCURRENCY, async ({ c, condition }) => {
    const r = await runCase(c, opts, condition);
    totalCost += r.cost || 0;
    console.log(`  [${condition}] [${r.status}] ${c.id}`);
    return r;
  });

  printSummary(results, totalCost, opts.compare);

  const outPath = opts.out || path.join(__dirname, 'results', `${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
  mkdirSync(path.dirname(outPath), { recursive: true });
  writeFileSync(outPath, JSON.stringify({ model: opts.model, judgeModel: opts.judge ? opts.judgeModel : null, compare: opts.compare, baseline: opts.baseline, totalCostUsd: totalCost, results }, null, 2));
  console.log(`\nFull transcript: ${outPath}`);
}

main().catch((err) => { console.error(err); process.exit(1); });
