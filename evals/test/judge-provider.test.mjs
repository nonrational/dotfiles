import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import JudgeProvider, { JUDGE_MODEL } from '../providers/judge.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(HERE, '../..');
const ECHO = path.join(HERE, 'fixtures/stub-claude-echo.mjs');

test('judge disables tools and skills, pins its model, and runs outside the repo', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const { output } = await new JudgeProvider().callApi('grade this');
  delete process.env.EVAL_CLAUDE_CMD;
  const { args, cwd } = JSON.parse(output);
  const tools = args.indexOf('--tools');
  assert.deepEqual(args.slice(tools, tools + 2), ['--tools', '']);
  assert.ok(args.includes('--disable-slash-commands'));
  assert.ok(args.includes('--no-session-persistence'));
  assert.ok(!args.includes('--bare'), '--bare ignores OAuth tokens');
  assert.equal(args[args.indexOf('--model') + 1], JUDGE_MODEL);
  assert.equal(JUDGE_MODEL, 'claude-sonnet-5');
  assert.ok(!cwd.startsWith(REPO_ROOT), `judge cwd ${cwd} is inside the repo`);
});

test('judge id is stable for promptfoo result attribution', () => {
  assert.equal(new JudgeProvider().id(), 'claude-code:judge');
});

test('judge appends a JSON-only instruction so promptfoo can parse the reply', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const { output } = await new JudgeProvider().callApi('grade this');
  delete process.env.EVAL_CLAUDE_CMD;
  const { stdin } = JSON.parse(output);
  assert.ok(stdin.startsWith('grade this'));
  assert.ok(stdin.endsWith('Reply with only the JSON object.'));
});
