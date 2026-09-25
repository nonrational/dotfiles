import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runClaude } from '../lib/claude-cli.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

export default class SubjectProvider {
  constructor(options = {}) {
    this.baseline = options.config?.baseline === true;
    this.label = options.label || (this.baseline ? 'baseline' : 'skill');
  }

  id() {
    return `claude-code:${this.baseline ? 'baseline' : 'skill'}`;
  }

  async callApi(prompt) {
    const model = process.env.EVAL_MODEL || 'sonnet';
    const args = this.baseline
      ? ['-p', '--output-format', 'json', '--no-session-persistence', '--model', model, '--disable-slash-commands']
      : ['-p', '--output-format', 'json', '--no-session-persistence', '--model', model, '--allowedTools', 'Skill'];
    return runClaude({ args, prompt, cwd: REPO_ROOT });
  }
}
