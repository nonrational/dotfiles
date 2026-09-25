#!/usr/bin/env node
// Stands in for `claude -p` and echoes its argv, cwd, and stdin back as the
// result, so tests can assert how a provider invokes the CLI without a model call.
let stdin = '';
process.stdin.on('data', (chunk) => (stdin += chunk));
process.stdin.on('end', () => {
  const result = JSON.stringify({
    args: process.argv.slice(2),
    cwd: process.cwd(),
    stdin,
    env: { TMUX: process.env.TMUX ?? null, TMUX_PANE: process.env.TMUX_PANE ?? null },
  });
  process.stdout.write(JSON.stringify({ result, is_error: false, total_cost_usd: 0, usage: {} }));
});
