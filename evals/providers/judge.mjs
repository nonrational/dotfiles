import os from 'node:os';
import { runClaude } from '../lib/claude-cli.mjs';

export const JUDGE_MODEL = 'claude-sonnet-5';

// Grades llm-rubric asserts. Tools and skills are off, and cwd sits outside
// the repo, so this repo's skills and its CLAUDE.md don't reach the judge.
// --setting-sources project also drops the developer's user config (rules,
// hooks, plugins), which otherwise loads locally regardless of cwd.
// Not --bare: bare mode ignores the OAuth token CI authenticates with.
export default class JudgeProvider {
  id() {
    return 'claude-code:judge';
  }

  async callApi(prompt) {
    const model = process.env.EVAL_JUDGE_MODEL || JUDGE_MODEL;
    const args = [
      '-p', '--output-format', 'json', '--model', model,
      '--tools', '', '--disable-slash-commands', '--no-session-persistence',
      '--setting-sources', 'project',
    ];
    // claude -p sometimes wraps the grader's JSON in prose, which promptfoo
    // cannot parse; the suffix is the cheapest nudge back to bare JSON.
    return runClaude({ args, prompt: `${prompt}\n\nReply with only the JSON object.`, cwd: os.tmpdir() });
  }
}
