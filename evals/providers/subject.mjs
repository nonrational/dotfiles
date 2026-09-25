import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runClaude } from '../lib/claude-cli.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

// Points <cwd>/.claude/skills/<skill> at this repo's copy so the skill under
// test resolves at project scope. Replaces a stale link (e.g. left over from
// a renamed or moved skill) rather than leaving it dangling.
function linkSkill(cwd, skill) {
  const linkDir = path.join(cwd, '.claude', 'skills');
  fs.mkdirSync(linkDir, { recursive: true });
  const link = path.join(linkDir, skill);
  const target = path.join(REPO_ROOT, 'home/.agents/skills', skill);

  let stat;
  try {
    stat = fs.lstatSync(link);
  } catch {
    stat = null;
  }
  if (stat && stat.isSymbolicLink() && fs.readlinkSync(link) === target) return;
  if (stat) fs.rmSync(link, { force: true });
  fs.symlinkSync(target, link);
}

export default class SubjectProvider {
  constructor(options = {}) {
    this.baseline = options.config?.baseline === true;
    this.label = options.label || (this.baseline ? 'baseline' : 'skill');
  }

  id() {
    return `claude-code:${this.baseline ? 'baseline' : 'skill'}`;
  }

  async callApi(prompt) {
    const skill = process.env.EVAL_SKILL;
    if (!skill) {
      throw new Error('EVAL_SKILL is required (e.g. EVAL_SKILL=code-comment-register)');
    }

    // EVAL_SCRATCH_DIR lets the unit tests point the provider at a throwaway root
    // instead of the path a real run uses on the same machine.
    const scratchRoot = process.env.EVAL_SCRATCH_DIR || path.join(os.tmpdir(), 'skill-evals');
    const cwd = path.join(scratchRoot, skill, this.baseline ? 'baseline' : 'skill');
    fs.mkdirSync(cwd, { recursive: true });

    const model = process.env.EVAL_MODEL || 'sonnet';

    // User hooks and plugins (e.g. a SessionStart preamble) inject text into
    // the first turn that the subject answers instead of the eval prompt.
    // --setting-sources project drops that user config, but it also drops
    // user-scope skill discovery, so the skill condition links the skill
    // under test at project scope to stay visible. This is also what makes
    // a local run match CI's bare $HOME.
    const args = this.baseline
      ? ['-p', '--output-format', 'json', '--no-session-persistence', '--model', model, '--disable-slash-commands', '--setting-sources', 'project']
      : ['-p', '--output-format', 'json', '--no-session-persistence', '--model', model, '--allowedTools', 'Skill', '--setting-sources', 'project'];

    // Safe under promptfoo's concurrency only because nothing above this line
    // awaits: each callApi finishes its synchronous mkdir/rm/symlink before the
    // next one starts. An await inserted before this call would open a race.
    if (!this.baseline) linkSkill(cwd, skill);

    return runClaude({ args, prompt, cwd });
  }
}
