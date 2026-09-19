import test from 'node:test';
import assert from 'node:assert/strict';
import { affectedSkills } from '../lib/affected.mjs';

const SKILLS = ['code-comment-register', 'prose-register'];

test('a change inside one evaluated skill selects only that skill', () => {
  assert.deepEqual(affectedSkills(['home/.agents/skills/prose-register/SKILL.md'], SKILLS), ['prose-register']);
});

test('a change to the suite selects every evaluated skill', () => {
  assert.deepEqual(affectedSkills(['evals/tests.mjs'], SKILLS), SKILLS);
  assert.deepEqual(affectedSkills(['.github/workflows/evals.yml'], SKILLS), SKILLS);
});

test('unrelated changes and unevaluated skills select nothing', () => {
  assert.deepEqual(affectedSkills(['README.md', 'home/.agents/skills/ux-review/SKILL.md'], SKILLS), []);
});

test('a skill name that prefixes another does not match it', () => {
  assert.deepEqual(affectedSkills(['home/.agents/skills/prose-register-extra/SKILL.md'], SKILLS), []);
});
