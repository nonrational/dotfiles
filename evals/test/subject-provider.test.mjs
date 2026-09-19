import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import SubjectProvider from '../providers/subject.mjs';

const STUB = path.resolve(path.dirname(fileURLToPath(import.meta.url)), 'fixtures/stub-claude.sh');

test('callApi returns the result field from the CLI JSON envelope', async () => {
  process.env.EVAL_CLAUDE_CMD = STUB;
  const provider = new SubjectProvider({ label: 'skill', config: {} });
  const result = await provider.callApi('any prompt');
  assert.equal(result.output, 'ANSWER: A\nRULE: stub rule');
  assert.equal(result.cost, 0.01);
  assert.deepEqual(result.tokenUsage, { total: 120, prompt: 100, completion: 20 });
  delete process.env.EVAL_CLAUDE_CMD;
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
  delete process.env.EVAL_CLAUDE_CMD;
});
