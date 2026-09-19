import { spawn } from 'node:child_process';

// Subject and judge both run a headless Claude Code session, so every model
// call rides the same subscription auth and no API key is needed.
export async function runClaude({ args, prompt, cwd }) {
  const cmd = process.env.EVAL_CLAUDE_CMD || 'claude';
  let stdout = '';
  let stderr = '';

  try {
    await new Promise((resolve, reject) => {
      // Strip TMUX/TMUX_PANE so a keyed run of dozens of sessions doesn't ring
      // the developer's tmux bell through their Stop hook, which keys off them.
      const { TMUX, TMUX_PANE, ...env } = process.env;
      const proc = spawn(cmd, args, { cwd, env });
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
      // A model alias such as "sonnet" can resolve differently by account or
      // release; recording what actually answered lets a CI run be compared
      // with a local one instead of guessed at.
      metadata: { models: Object.keys(parsed.modelUsage || {}) },
    };
  } catch (error) {
    return { error: String(error.message || error) };
  }
}
