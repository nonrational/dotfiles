import test, { beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import SubjectProvider from '../providers/subject.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(HERE, '../..');
const STUB = path.resolve(HERE, 'fixtures/stub-claude.sh');
const ECHO = path.join(HERE, 'fixtures/stub-claude-echo.mjs');
const SKILL = 'code-comment-register';

// Each test gets its own scratch root so the suite never writes into the path
// a real run uses on this machine, and leaves nothing behind.
let scratchRoot;
beforeEach(() => {
  process.env.EVAL_SKILL = SKILL;
  scratchRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-evals-test-'));
  process.env.EVAL_SCRATCH_DIR = scratchRoot;
});

afterEach(() => {
  delete process.env.EVAL_SKILL;
  delete process.env.EVAL_CLAUDE_CMD;
  delete process.env.EVAL_LOCAL;
  delete process.env.EVAL_SCRATCH_DIR;
  fs.rmSync(scratchRoot, { recursive: true, force: true });
});

test('scratch cwd sits under EVAL_SCRATCH_DIR when it is set', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const skill = new SubjectProvider({ label: 'skill', config: {} });
  const { cwd } = JSON.parse((await skill.callApi('p')).output);
  // macOS reports os.tmpdir() through its /private alias; compare resolved paths.
  assert.equal(fs.realpathSync(cwd), fs.realpathSync(path.join(scratchRoot, SKILL, 'skill')));
});

test('callApi returns the result field from the CLI JSON envelope', async () => {
  process.env.EVAL_CLAUDE_CMD = STUB;
  const provider = new SubjectProvider({ label: 'skill', config: {} });
  const result = await provider.callApi('any prompt');
  assert.equal(result.output, 'ANSWER: A\nRULE: stub rule');
  assert.equal(result.cost, 0.01);
  assert.deepEqual(result.tokenUsage, { total: 120, prompt: 100, completion: 20 });
});

test('provider ids distinguish skill and baseline conditions', () => {
  const skill = new SubjectProvider({ label: 'skill', config: {} });
  const baseline = new SubjectProvider({ label: 'baseline', config: { baseline: true } });
  assert.equal(skill.id(), 'claude-code:skill');
  assert.equal(baseline.id(), 'claude-code:baseline');
});

test('callApi surfaces a spawn failure as an error result, not a throw', async () => {
  process.env.EVAL_CLAUDE_CMD = '/nonexistent/definitely-not-claude';
  const provider = new SubjectProvider({ label: 'skill', config: {} });
  const result = await provider.callApi('any prompt');
  assert.ok(result.error, 'expected an error result');
});

test('callApi throws a clear error when EVAL_SKILL is unset', async () => {
  delete process.env.EVAL_SKILL;
  const provider = new SubjectProvider({ label: 'skill', config: {} });
  await assert.rejects(() => provider.callApi('any prompt'), /EVAL_SKILL/);
});

test('both conditions skip session persistence so a keyed run leaves no transcript per case', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const skill = new SubjectProvider({ label: 'skill', config: {} });
  const baseline = new SubjectProvider({ label: 'baseline', config: { baseline: true } });
  const skillArgs = JSON.parse((await skill.callApi('p')).output).args;
  const baselineArgs = JSON.parse((await baseline.callApi('p')).output).args;
  assert.ok(skillArgs.includes('--no-session-persistence'));
  assert.ok(baselineArgs.includes('--no-session-persistence'));
});

test('baseline disables slash commands while skill allows only the Skill tool', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const skill = new SubjectProvider({ label: 'skill', config: {} });
  const baseline = new SubjectProvider({ label: 'baseline', config: { baseline: true } });
  const skillArgs = JSON.parse((await skill.callApi('p')).output).args;
  const baselineArgs = JSON.parse((await baseline.callApi('p')).output).args;
  assert.ok(baselineArgs.includes('--disable-slash-commands'));
  assert.ok(!skillArgs.includes('--disable-slash-commands'));
  assert.equal(skillArgs[skillArgs.indexOf('--allowedTools') + 1], 'Skill');
});

test('both conditions run with --setting-sources project to keep the developer user config out', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const skill = new SubjectProvider({ label: 'skill', config: {} });
  const baseline = new SubjectProvider({ label: 'baseline', config: { baseline: true } });
  const skillArgs = JSON.parse((await skill.callApi('p')).output).args;
  const baselineArgs = JSON.parse((await baseline.callApi('p')).output).args;
  const skillIdx = skillArgs.indexOf('--setting-sources');
  const baselineIdx = baselineArgs.indexOf('--setting-sources');
  assert.deepEqual(skillArgs.slice(skillIdx, skillIdx + 2), ['--setting-sources', 'project']);
  assert.deepEqual(baselineArgs.slice(baselineIdx, baselineIdx + 2), ['--setting-sources', 'project']);
});

test('skill condition runs outside the repo and links .claude/skills/<skill> to the repo copy', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const skill = new SubjectProvider({ label: 'skill', config: {} });
  const { cwd } = JSON.parse((await skill.callApi('p')).output);
  assert.ok(!cwd.startsWith(REPO_ROOT), `cwd ${cwd} is inside the repo`);
  const link = path.join(cwd, '.claude', 'skills', SKILL);
  assert.equal(fs.realpathSync(link), fs.realpathSync(path.join(REPO_ROOT, 'home/.agents/skills', SKILL)));
});

test('baseline condition links nothing under .claude/skills', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const baseline = new SubjectProvider({ label: 'baseline', config: { baseline: true } });
  const { cwd } = JSON.parse((await baseline.callApi('p')).output);
  assert.ok(!fs.existsSync(path.join(cwd, '.claude', 'skills', SKILL)));
});

test('a stale skill symlink pointing elsewhere is replaced', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const scratchCwd = path.join(scratchRoot, SKILL, 'skill');
  const linkDir = path.join(scratchCwd, '.claude', 'skills');
  fs.mkdirSync(linkDir, { recursive: true });
  const link = path.join(linkDir, SKILL);
  fs.rmSync(link, { force: true });
  fs.symlinkSync('/nonexistent/stale-target', link);

  const skill = new SubjectProvider({ label: 'skill', config: {} });
  await skill.callApi('p');

  assert.equal(fs.realpathSync(link), fs.realpathSync(path.join(REPO_ROOT, 'home/.agents/skills', SKILL)));
});

test('EVAL_LOCAL mode runs bare with the skill in the system prompt, not the Skill tool', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  process.env.EVAL_LOCAL = '1';
  const skill = new SubjectProvider({ label: 'skill', config: {} });
  const model = process.env.EVAL_MODEL || 'sonnet';
  const skillFile = path.join(REPO_ROOT, 'home/.agents/skills', SKILL, 'SKILL.md');

  const skillArgs = JSON.parse((await skill.callApi('p')).output).args;

  assert.deepEqual(skillArgs, [
    '-p', '--output-format', 'json', '--no-session-persistence', '--model', model,
    '--bare', '--tools', '', '--append-system-prompt-file', skillFile,
  ]);
});

test('EVAL_LOCAL mode baseline is the same call without the skill system prompt', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  process.env.EVAL_LOCAL = '1';
  const baseline = new SubjectProvider({ label: 'baseline', config: { baseline: true } });
  const model = process.env.EVAL_MODEL || 'sonnet';

  const baselineArgs = JSON.parse((await baseline.callApi('p')).output).args;

  assert.deepEqual(baselineArgs, [
    '-p', '--output-format', 'json', '--no-session-persistence', '--model', model,
    '--bare', '--tools', '',
  ]);
  assert.ok(!baselineArgs.includes('--append-system-prompt-file'));
});

test('EVAL_LOCAL mode drops --setting-sources, --allowedTools, and --disable-slash-commands', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  process.env.EVAL_LOCAL = '1';
  const skill = new SubjectProvider({ label: 'skill', config: {} });
  const baseline = new SubjectProvider({ label: 'baseline', config: { baseline: true } });

  const skillArgs = JSON.parse((await skill.callApi('p')).output).args;
  const baselineArgs = JSON.parse((await baseline.callApi('p')).output).args;

  for (const args of [skillArgs, baselineArgs]) {
    assert.ok(!args.includes('--setting-sources'));
    assert.ok(!args.includes('--allowedTools'));
    assert.ok(!args.includes('--disable-slash-commands'));
  }
});
