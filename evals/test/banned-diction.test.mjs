import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const RULES_DIR = path.join(REPO_ROOT, 'home/.agents/rules');

// Deterministic backstop for the Diction to Avoid list in language.md. Model
// output is not covered; this keeps the rule files themselves from drifting
// back into the vocabulary they ban.
const BANNED = [{ word: 'gate', pattern: /\bgat(?:e|es|ed|ing)\b/i }];

// The ban bullet and its "Bad:" examples must quote the banned word.
const isBanDocumentation = (line) => /^\s*- Ban "gate"/.test(line) || /^\s*- Bad:/.test(line);

const ruleFiles = fs.readdirSync(RULES_DIR).filter((name) => name.endsWith('.md'));

test('rule files exist to scan', () => {
  assert.ok(ruleFiles.length > 0);
});

for (const { word, pattern } of BANNED) {
  test(`rule files do not use "${word}" in any form`, () => {
    const hits = [];
    for (const name of ruleFiles) {
      fs.readFileSync(path.join(RULES_DIR, name), 'utf8')
        .split('\n')
        .forEach((line, index) => {
          if (pattern.test(line) && !isBanDocumentation(line)) hits.push(`${name}:${index + 1}: ${line.trim()}`);
        });
    }
    assert.deepEqual(hits, []);
  });
}

test('language.md still bans "gate" in every form', () => {
  const language = fs.readFileSync(path.join(RULES_DIR, 'language.md'), 'utf8');
  assert.match(language, /- Ban "gate" in every form/);
});
