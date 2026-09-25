import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runClaude } from '../lib/claude-cli.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const STUB = path.join(HERE, 'fixtures/stub-claude.sh');
const ECHO = path.join(HERE, 'fixtures/stub-claude-echo.mjs');

test('runClaude parses the envelope into output, cost, and token usage', async () => {
  process.env.EVAL_CLAUDE_CMD = STUB;
  const result = await runClaude({ args: ['-p'], prompt: 'p', cwd: HERE });
  delete process.env.EVAL_CLAUDE_CMD;
  assert.equal(result.output, 'ANSWER: A\nRULE: stub rule');
  assert.equal(result.cost, 0.01);
  assert.deepEqual(result.tokenUsage, { total: 120, prompt: 100, completion: 20 });
});

test('runClaude records the models that served the call, so a run can be attributed to one', async () => {
  process.env.EVAL_CLAUDE_CMD = STUB;
  const result = await runClaude({ args: ['-p'], prompt: 'p', cwd: HERE });
  delete process.env.EVAL_CLAUDE_CMD;
  assert.deepEqual(result.metadata, { models: ['claude-stub-1', 'claude-stub-2'] });
});

test('runClaude passes args through verbatim, empty strings included', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  const result = await runClaude({ args: ['-p', '--tools', ''], prompt: 'p', cwd: HERE });
  delete process.env.EVAL_CLAUDE_CMD;
  assert.deepEqual(JSON.parse(result.output).args, ['-p', '--tools', '']);
});

test('runClaude returns an error result on spawn failure instead of throwing', async () => {
  process.env.EVAL_CLAUDE_CMD = '/nonexistent/definitely-not-claude';
  const result = await runClaude({ args: [], prompt: 'p', cwd: HERE });
  delete process.env.EVAL_CLAUDE_CMD;
  assert.ok(result.error);
});

test('runClaude strips TMUX and TMUX_PANE from the child env so eval sessions do not ring the developer bell', async () => {
  process.env.EVAL_CLAUDE_CMD = ECHO;
  process.env.TMUX = '/tmp/tmux-test,1,0';
  process.env.TMUX_PANE = '%9';
  try {
    const result = await runClaude({ args: ['-p'], prompt: 'p', cwd: HERE });
    assert.deepEqual(JSON.parse(result.output).env, { TMUX: null, TMUX_PANE: null });
    assert.equal(process.env.TMUX, '/tmp/tmux-test,1,0');
  } finally {
    delete process.env.EVAL_CLAUDE_CMD;
    delete process.env.TMUX;
    delete process.env.TMUX_PANE;
  }
});
