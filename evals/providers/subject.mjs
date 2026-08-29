import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

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
    const cmd = process.env.EVAL_CLAUDE_CMD || 'claude';
    const model = process.env.EVAL_MODEL || 'sonnet';
    const args = this.baseline
      ? ['-p', '--output-format', 'json', '--model', model, '--disable-slash-commands']
      : ['-p', '--output-format', 'json', '--model', model, '--allowedTools', 'Skill'];

    let stdout = '';
    let stderr = '';

    try {
      await new Promise((resolve, reject) => {
        const proc = spawn(cmd, args, { cwd: REPO_ROOT });
        proc.stdout.on('data', (chunk) => (stdout += chunk));
        proc.stderr.on('data', (chunk) => (stderr += chunk));
        proc.on('error', reject);
        proc.on('close', (code) => {
          if (code !== 0) reject(new Error(`${cmd} exited ${code}: ${stderr.slice(0, 2000)}`));
          else resolve();
        });
        proc.stdin.write(prompt);
        proc.stdin.end();
      });

      const parsed = JSON.parse(stdout);
      if (parsed.is_error) {
        return { error: `claude reported an error: ${parsed.result}` };
      }

      const usage = parsed.usage || {};
      const promptTokens = usage.input_tokens || 0;
      const completionTokens = usage.output_tokens || 0;
      return {
        output: parsed.result ?? '',
        cost: parsed.total_cost_usd ?? 0,
        tokenUsage: {
          total: promptTokens + completionTokens,
          prompt: promptTokens,
          completion: completionTokens,
        },
      };
    } catch (error) {
      return { error: String(error.message || error) };
    }
  }
}
