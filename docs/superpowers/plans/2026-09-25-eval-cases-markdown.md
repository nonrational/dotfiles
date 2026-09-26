# Eval Cases as Markdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move every skill's eval suite from one `evals.json` to a directory of one-Markdown-file-per-case with YAML frontmatter, a per-suite `README.md`, and a required `status` that lets draft cases run without gating.

**Architecture:** A new parser module (`evals/lib/suite-md.mjs`) turns a suite directory into the exact `{ skill, min_pass_rate, cases }` object the harness already consumes; `evals/lib/load-evals.mjs` re-exports its finder and loader so every caller changes one import name. A one-off, uncommitted script migrates the three suites and proves round-trip equality before deleting the JSON. The gate then learns to treat `status: draft` rows as informational.

**Tech Stack:** Node 24+ ES modules, `node:test`, promptfoo (unchanged), the `yaml` npm package (^2.9.1) for frontmatter and YAML sections.

**Spec:** `docs/superpowers/specs/2026-09-25-eval-cases-markdown-design.md` (read it first; this plan argues from it). Background: `docs/superpowers/specs/2026-08-29-skill-eval-suite-design.md`.

## Global Constraints

- Work only in the worktree `/Users/norton/.dotfiles/.worktrees/eval-cases-markdown`, branch `eval-cases-markdown`, stacked on `code-review-register-evals`. Never `cd` to `/Users/norton/.dotfiles`. Never use `git stash`.
- Stage with explicit paths (`git add <paths>`), never `git add -A` or `git commit -a`. The worktree is shared with no one else, but the rule holds.
- Commit messages: plain descriptive subject, no Conventional Commit prefixes, a short body saying why, and the trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` as the last line.
- Node >= 24 and npm 11 (the lockfile's writer). Run `cd evals && npm install yaml@^2.9.1 --save-dev` once in Task 1 and commit both `package.json` and `package-lock.json`.
- Every Markdown file written ends with exactly one trailing newline (`.editorconfig`: `insert_final_newline = true`). Trailing whitespace inside `.md` files is allowed (structural).
- No em-dashes (U+2014) in any new prose, comment, or doc text. Use a full stop, a colon, or parentheses.
- Comments explain why, not what. Never restate the code.
- Do not run `make eval`, `make eval-local`, or `claude -p`. This plan spends zero model sessions. CI's `evals` job on the PR is the behavioral check.
- Case content is data. Never edit the wording, keys, order, or fields of any existing case beyond adding `status`. Round-trip equality against the old JSON is the proof.
- `test/fixtures/` paths are read by tests through a fake repo root, so fixture skills never appear under the real `home/.agents/skills`.

## Review Focus

Input classes the spec implies but did not spell out. Each has a pinning test in the task named.

1. **A case file with CRLF line endings** (an editor on another OS) must parse like an LF file; the frontmatter fence `---\r` would otherwise never match. Task 1 normalizes `\r\n` to `\n` before parsing and tests it.
2. **A section with no text** (a heading the author forgot to fill) must be an error, not an empty variant that the subject sees as a blank option. Task 1 throws on an empty section and tests it.
3. **A section whose opening fence is closed early** (an inner fence as long as the outer) must stay verbatim, never be half-unwrapped. Task 1 tests that `unwrapFence` leaves such text unchanged.
4. **Files in the suite directory that are not cases** (`.DS_Store`, `notes.txt`, a `README.md` in any other case) must be ignored or rejected clearly: only `*.md` other than `README.md` are cases, and a case whose `id` disagrees with its filename is an error. Task 1 tests both.
5. **Frontmatter that parses to a non-object** (a bare string, or empty) must be an error with the filename, not a crash on `data.id`. Task 1 tests it.

---

## File Structure

| Path | Responsibility |
|---|---|
| `evals/lib/suite-md.mjs` (create) | Parse one case file, parse one README, find suites, load a suite directory into the harness's data shape. Pure functions over strings plus two filesystem entry points. |
| `evals/lib/load-evals.mjs` (modify) | Keep `SUPPORTED_TYPES` and `validateData`; re-export `findSuites`, `loadSuite`, `suiteSkill` from `suite-md.mjs`; drop the JSON finder and loader. |
| `evals/tests.mjs`, `evals/bin/validate.mjs`, `evals/bin/check-gate.mjs`, `evals/bin/affected-skills.mjs` (modify) | Call the new finder and loader; tag rows with `status`; treat drafts as informational. |
| `evals/test/fixtures/suite/home/.agents/skills/fixture-skill/evals/*.md` (create) | A tiny suite exercising every section kind and both fence cases. |
| `evals/test/suite-md.test.mjs` (create) | Parser and loader tests, including the error paths. |
| `evals/test/load-evals.test.mjs`, `generator.test.mjs`, `check-gate.test.mjs` (modify) | Point at the new layout; cover draft rows. |
| `home/.agents/skills/{code-comment-register,prose-register,code-review-register}/evals/` (create) | The migrated suites. `evals.json` deleted in each. |
| `CLAUDE.md`, `evals/promptfooconfig.yaml`, `docs/superpowers/specs/2026-08-29-skill-eval-suite-design.md` (modify) | Point at the new format and the new spec. |

---

### Task 1: The Markdown suite parser and loader

**Files:**
- Create: `evals/lib/suite-md.mjs`
- Create: `evals/test/suite-md.test.mjs`
- Create: `evals/test/fixtures/suite/home/.agents/skills/fixture-skill/evals/README.md`
- Create: `evals/test/fixtures/suite/home/.agents/skills/fixture-skill/evals/disc-01.md`
- Create: `evals/test/fixtures/suite/home/.agents/skills/fixture-skill/evals/rank-01.md`
- Create: `evals/test/fixtures/suite/home/.agents/skills/fixture-skill/evals/trans-01.md`
- Create: `evals/test/fixtures/suite/home/.agents/skills/fixture-skill/evals/det-01.md`
- Modify: `evals/package.json`, `evals/package-lock.json` (add `yaml`)

**Interfaces:**
- Produces (all exported from `evals/lib/suite-md.mjs`):
  - `parseFrontmatter(text: string, label: string): { data: object, body: string }`
  - `splitSections(body: string): { lead: string, sections: Array<{ heading: string, text: string }> }`
  - `trimBlankLines(text: string): string`
  - `unwrapFence(text: string): string`
  - `parseCase(text: string, filename: string): object` (a case in the same shape `validateData` expects)
  - `suiteSkill(readmePath: string): string` (the skill name, two directories up from the README)
  - `findSuites(repoRoot: string): string[]` (absolute paths of every `home/.agents/skills/<skill>/evals/README.md`, sorted, skipping symlinked skill dirs)
  - `loadSuite(readmePath: string): { skill: string, min_pass_rate?: number, cases: object[] }`
- Consumes: nothing from other tasks.

- [ ] **Step 1: Install the YAML dependency**

Run:
```bash
cd evals && npm install yaml@^2.9.1 --save-dev && node -e "import('yaml').then(m => console.log(m.default.parse('a: 1').a))"
```
Expected: prints `1`. `package.json` gains `"yaml": "^2.9.1"` under `devDependencies`; `package-lock.json` changes.

- [ ] **Step 2: Write the fixture suite**

`evals/test/fixtures/suite/home/.agents/skills/fixture-skill/evals/README.md`:
```markdown
---
skill: fixture-skill
min_pass_rate: 0.5
---

# fixture-skill evals

A throwaway suite for the loader tests. The harness reads only the frontmatter above.
```

`evals/test/fixtures/suite/home/.agents/skills/fixture-skill/evals/disc-01.md` (note the fenced variant whose `#` lines would otherwise be headings, and the raw variant with an inner suggestion fence):
````markdown
---
id: disc-01
type: discrimination
status: approved
correct: with_reason
expected_rule: Explain why, not what.
accepted_rules:
  - Put the reason beside the decision.
arguable: false
source_commit: abc1234
---

Which version follows the register?

## rule

Explain why, not what.

## evidence

The author deleted the generic comment.

## with_reason

```
# Retry once: the upstream drops the first connection after idle.
retry(1)
```

## bare

Fix the flaky call.

```suggestion
retry(1)
```

## note

Only the reason differs.
````

`evals/test/fixtures/suite/home/.agents/skills/fixture-skill/evals/rank-01.md`:
```markdown
---
id: rank-01
type: discrimination-rank
status: draft
correct_ranking:
  - restored
  - original
  - over_tight
expected_rule_for_worst: A hard line needs a breath.
---

Rank these versions.

## original

One. Two. Three.

## over_tight

One two three.

## restored

One. Two, and then three.
```

`evals/test/fixtures/suite/home/.agents/skills/fixture-skill/evals/trans-01.md`:
```markdown
---
id: trans-01
type: transformation
status: approved
---

## rule

No comment is a valid result.

## input

# Bigger is faster.
SIZE = 10

## task

Edit the comment. No evidence is available.

## reference

SIZE = 10

## rubric

violation_fixed: Is the unsupported comment deleted?
no_new_violation: Is the code unchanged?

## note

A rewrite that invents a reason fails.
```

`evals/test/fixtures/suite/home/.agents/skills/fixture-skill/evals/det-01.md` (four-backtick outer fence because the document holds a three-backtick fence):
`````markdown
---
id: det-01
type: detection
status: approved
min_recall: 0.5
---

Find every failing comment.

## document

````
[a.ts:1] Why is this 50?

[a.ts:9] The filename drops the extension.
```suggestion
const name = `${base}.csv`;
```
````

## violations

- quote: Why is this 50?
  rule: Bare question.
  reason: No reason attached.
  anchor: this 50

## traps

- quote: The filename drops the extension.
  why_valid: A fix offered as a suggestion block.
`````

- [ ] **Step 3: Write the failing tests**

`evals/test/suite-md.test.mjs`:
```js
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  parseFrontmatter, splitSections, trimBlankLines, unwrapFence, parseCase, suiteSkill, findSuites, loadSuite,
} from '../lib/suite-md.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const FIXTURE_ROOT = path.join(HERE, 'fixtures/suite');
const README = path.join(FIXTURE_ROOT, 'home/.agents/skills/fixture-skill/evals/README.md');

test('parseFrontmatter splits the YAML block from the body and normalizes CRLF', () => {
  const { data, body } = parseFrontmatter('---\r\nid: x\r\nstatus: draft\r\n---\r\n\r\nHello\r\n', 'x.md');
  assert.deepEqual(data, { id: 'x', status: 'draft' });
  assert.equal(body, '\nHello\n');
});

test('parseFrontmatter rejects a file with no opening fence, no closing fence, or a non-object block', () => {
  assert.throws(() => parseFrontmatter('id: x\n', 'x.md'), /x\.md: file must start with a --- frontmatter line/);
  assert.throws(() => parseFrontmatter('---\nid: x\n', 'x.md'), /x\.md: frontmatter is not closed/);
  assert.throws(() => parseFrontmatter('---\njust a string\n---\n', 'x.md'), /x\.md: frontmatter must be a YAML mapping/);
  assert.throws(() => parseFrontmatter('---\n---\n', 'x.md'), /x\.md: frontmatter must be a YAML mapping/);
});

test('splitSections separates the lead from H2 sections and ignores H2 lines inside fences', () => {
  const body = '\nLead text\n\n## one\n\nfirst\n\n## two\n\n```\n## not a heading\n```\n';
  const { lead, sections } = splitSections(body);
  assert.equal(lead, 'Lead text');
  assert.deepEqual(sections.map((s) => s.heading), ['one', 'two']);
  assert.equal(sections[0].text, 'first');
  assert.equal(sections[1].text, '```\n## not a heading\n```');
});

test('splitSections trims trailing spaces off a heading and keeps interior blank lines', () => {
  const { sections } = splitSections('## a   \n\nline one\n\nline three\n');
  assert.equal(sections[0].heading, 'a');
  assert.equal(sections[0].text, 'line one\n\nline three');
});

test('trimBlankLines removes only leading and trailing blank lines', () => {
  assert.equal(trimBlankLines('\n\n  x  \n\n\ny\n\n'), '  x  \n\n\ny');
});

test('unwrapFence unwraps a section that is exactly one fenced block', () => {
  assert.equal(unwrapFence('```\n# not a heading\ncode\n```'), '# not a heading\ncode');
  assert.equal(unwrapFence('````\ntext\n```suggestion\nx\n```\n````'), 'text\n```suggestion\nx\n```');
  assert.equal(unwrapFence('~~~elixir\ncode\n~~~'), 'code');
});

test('unwrapFence leaves text alone when the fence is not the whole section or closes early', () => {
  assert.equal(unwrapFence('intro\n```\ncode\n```'), 'intro\n```\ncode\n```');
  assert.equal(unwrapFence('```\ncode\n```\ntail'), '```\ncode\n```\ntail');
  // An inner fence as long as the outer closes it early; the text stays verbatim.
  assert.equal(unwrapFence('```\na\n```\nb\n```'), '```\na\n```\nb\n```');
  assert.equal(unwrapFence('plain'), 'plain');
});

test('parseCase builds a discrimination case with variants in file order and reserved sections mapped', () => {
  const text = [
    '---', 'id: d1', 'type: discrimination', 'status: approved', 'correct: b', 'expected_rule: r', '---', '',
    'Which one?', '', '## rule', '', 'Quote.', '', '## b', '', 'B text', '', '## a', '', 'A text', '', '## note', '', 'N.', '',
  ].join('\n');
  const item = parseCase(text, '/x/evals/d1.md');
  assert.deepEqual(item, {
    id: 'd1', type: 'discrimination', status: 'approved', correct: 'b', expected_rule: 'r',
    prompt: 'Which one?', rule_quote: 'Quote.', variants: { b: 'B text', a: 'A text' }, grading_note: 'N.',
  });
  assert.deepEqual(Object.keys(item.variants), ['b', 'a']);
});

test('parseCase passes unknown frontmatter fields through untouched', () => {
  const text = '---\nid: d1\ntype: discrimination\nstatus: draft\ncorrect: a\nexpected_rule: r\nsource_commits:\n  - abc (original)\n---\n\nP\n\n## a\n\nA\n\n## b\n\nB\n';
  assert.deepEqual(parseCase(text, 'd1.md').source_commits, ['abc (original)']);
});

test('parseCase unwraps a fenced variant so its # lines are content, not headings', () => {
  const text = '---\nid: d1\ntype: discrimination\nstatus: draft\ncorrect: a\nexpected_rule: r\n---\n\nP\n\n## a\n\n```\n# comment\ncode()\n```\n\n## b\n\nB\n';
  assert.equal(parseCase(text, 'd1.md').variants.a, '# comment\ncode()');
});

test('parseCase parses rubric, violations and traps sections as YAML', () => {
  const text = '---\nid: t1\ntype: transformation\nstatus: approved\n---\n\n## input\n\nI\n\n## task\n\nT\n\n## reference\n\nR\n\n## rubric\n\nviolation_fixed: V?\nno_new_violation: N?\n';
  const item = parseCase(text, 't1.md');
  assert.deepEqual(item, {
    id: 't1', type: 'transformation', status: 'approved', input: 'I', task: 'T', reference_after: 'R',
    rubric: { violation_fixed: 'V?', no_new_violation: 'N?' },
  });
  const det = '---\nid: x1\ntype: detection\nstatus: approved\n---\n\nP\n\n## document\n\nthe quoted line\n\n## violations\n\n- quote: quoted line\n  rule: r\n  fixed_in: abc\n\n## traps\n\n- quote: the quoted\n  why_not_a_violation: w\n';
  const d = parseCase(det, 'x1.md');
  assert.deepEqual(d.violations, [{ quote: 'quoted line', rule: 'r', fixed_in: 'abc' }]);
  assert.deepEqual(d.traps, [{ quote: 'the quoted', why_not_a_violation: 'w' }]);
  assert.equal(d.input_document, 'the quoted line');
});

test('parseCase rejects an id that disagrees with the filename', () => {
  const text = '---\nid: d1\ntype: discrimination\nstatus: draft\ncorrect: a\nexpected_rule: r\n---\n\nP\n\n## a\n\nA\n\n## b\n\nB\n';
  assert.throws(() => parseCase(text, '/x/evals/d2.md'), /d2\.md: frontmatter id "d1" does not match the filename/);
});

test('parseCase rejects lead text on a transformation, an unknown section, a duplicate section and an empty section', () => {
  const trans = '---\nid: t1\ntype: transformation\nstatus: draft\n---\n\nstray\n\n## input\n\nI\n';
  assert.throws(() => parseCase(trans, 't1.md'), /t1\.md: text before the first heading/);
  const unknown = '---\nid: t1\ntype: transformation\nstatus: draft\n---\n\n## input\n\nI\n\n## banana\n\nB\n';
  assert.throws(() => parseCase(unknown, 't1.md'), /t1\.md: unknown section "banana" for a transformation case/);
  const dup = '---\nid: d1\ntype: discrimination\nstatus: draft\ncorrect: a\nexpected_rule: r\n---\n\nP\n\n## a\n\nA\n\n## a\n\nA2\n';
  assert.throws(() => parseCase(dup, 'd1.md'), /d1\.md: duplicate section "a"/);
  const empty = '---\nid: d1\ntype: discrimination\nstatus: draft\ncorrect: a\nexpected_rule: r\n---\n\nP\n\n## a\n\n## b\n\nB\n';
  assert.throws(() => parseCase(empty, 'd1.md'), /d1\.md: section "a" is empty/);
});

test('suiteSkill names the skill two directories above the README', () => {
  assert.equal(suiteSkill('/repo/home/.agents/skills/prose-register/evals/README.md'), 'prose-register');
});

test('findSuites lists every evals/README.md under a repo root, sorted', () => {
  assert.deepEqual(findSuites(FIXTURE_ROOT), [README]);
});

test('loadSuite returns the harness data shape with cases sorted by filename', () => {
  const suite = loadSuite(README);
  assert.equal(suite.skill, 'fixture-skill');
  assert.equal(suite.min_pass_rate, 0.5);
  assert.deepEqual(suite.cases.map((c) => c.id), ['det-01', 'disc-01', 'rank-01', 'trans-01']);
  const disc = suite.cases.find((c) => c.id === 'disc-01');
  assert.equal(disc.variants.with_reason, '# Retry once: the upstream drops the first connection after idle.\nretry(1)');
  assert.equal(disc.variants.bare, 'Fix the flaky call.\n\n```suggestion\nretry(1)\n```');
  assert.deepEqual(disc.accepted_rules, ['Put the reason beside the decision.']);
  assert.equal(disc.evidence, 'The author deleted the generic comment.');
  const rank = suite.cases.find((c) => c.id === 'rank-01');
  assert.deepEqual(Object.keys(rank.stages), ['original', 'over_tight', 'restored']);
  assert.deepEqual(rank.correct_ranking, ['restored', 'original', 'over_tight']);
  const det = suite.cases.find((c) => c.id === 'det-01');
  assert.equal(det.input_document, '[a.ts:1] Why is this 50?\n\n[a.ts:9] The filename drops the extension.\n```suggestion\nconst name = `${base}.csv`;\n```');
  assert.deepEqual(det.violations[0], { quote: 'Why is this 50?', rule: 'Bare question.', reason: 'No reason attached.', anchor: 'this 50' });
  assert.equal(det.min_recall, 0.5);
  const trans = suite.cases.find((c) => c.id === 'trans-01');
  assert.equal(trans.input, '# Bigger is faster.\nSIZE = 10');
  assert.equal(trans.prompt, undefined);
});

test('loadSuite ignores non-case files and rejects a README whose skill disagrees with the directory', async () => {
  const { mkdtempSync, mkdirSync, writeFileSync } = await import('node:fs');
  const os = await import('node:os');
  const root = mkdtempSync(path.join(os.tmpdir(), 'suite-md-'));
  const dir = path.join(root, 'home/.agents/skills/alpha/evals');
  mkdirSync(dir, { recursive: true });
  writeFileSync(path.join(dir, 'README.md'), '---\nskill: alpha\n---\n');
  writeFileSync(path.join(dir, '.DS_Store'), 'junk');
  writeFileSync(path.join(dir, 'notes.txt'), 'not a case');
  assert.deepEqual(loadSuite(path.join(dir, 'README.md')), { skill: 'alpha', cases: [] });
  writeFileSync(path.join(dir, 'README.md'), '---\nskill: beta\n---\n');
  assert.throws(() => loadSuite(path.join(dir, 'README.md')), /README\.md: skill "beta" does not match the directory "alpha"/);
});
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `cd evals && node --test test/suite-md.test.mjs`
Expected: every test fails with `Cannot find module '../lib/suite-md.mjs'`.

- [ ] **Step 5: Write the parser and loader**

`evals/lib/suite-md.mjs`:
```js
import { readFileSync, readdirSync, existsSync, lstatSync } from 'node:fs';
import path from 'node:path';
import YAML from 'yaml';

const FENCE_OPEN = /^(`{3,}|~{3,})(.*)$/;
const H2 = /^## (.+?)\s*$/;

// Headings whose text is a named case field rather than a variant. The YAML
// ones hold structured lists or mappings the graders read by key.
const RESERVED = {
  rule: 'rule_quote',
  note: 'grading_note',
  evidence: 'evidence',
  input: 'input',
  task: 'task',
  reference: 'reference_after',
  rubric: 'rubric',
  document: 'input_document',
  violations: 'violations',
  traps: 'traps',
};
const YAML_SECTIONS = new Set(['rubric', 'violations', 'traps']);
// Which field a non-reserved heading feeds, by case type. Types absent here
// take no free headings at all.
const CHOICE_FIELD = {
  discrimination: 'variants',
  'discrimination-structural': 'variants',
  'discrimination-rank': 'stages',
};
// Only these types carry a prompt; for the rest, text before the first
// heading is a mistake the author should see.
const PROMPT_TYPES = new Set([...Object.keys(CHOICE_FIELD), 'detection']);

export function parseFrontmatter(text, label) {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  if (lines[0] !== '---') throw new Error(`${label}: file must start with a --- frontmatter line`);
  const end = lines.indexOf('---', 1);
  if (end === -1) throw new Error(`${label}: frontmatter is not closed by a --- line`);
  const data = YAML.parse(lines.slice(1, end).join('\n'));
  if (data === null || typeof data !== 'object' || Array.isArray(data)) {
    throw new Error(`${label}: frontmatter must be a YAML mapping`);
  }
  return { data, body: lines.slice(end + 1).join('\n') };
}

function isClosingFence(line, open) {
  const match = line.match(/^(`{3,}|~{3,})\s*$/);
  return Boolean(match) && match[1][0] === open[0] && match[1].length >= open.length;
}

export function trimBlankLines(text) {
  const lines = text.split('\n');
  while (lines.length && lines[0].trim() === '') lines.shift();
  while (lines.length && lines.at(-1).trim() === '') lines.pop();
  return lines.join('\n');
}

// Splits on H2 lines, but never on one inside a fenced block: a code variant
// or a detection document may legitimately contain "## ".
export function splitSections(body) {
  const lead = [];
  const sections = [];
  let current = lead;
  let fence = null;
  for (const line of body.split('\n')) {
    if (fence) {
      if (isClosingFence(line, fence)) fence = null;
      current.push(line);
      continue;
    }
    const open = line.match(FENCE_OPEN);
    if (open) {
      fence = open[1];
      current.push(line);
      continue;
    }
    const heading = line.match(H2);
    if (heading) {
      current = [];
      sections.push({ heading: heading[1], lines: current });
      continue;
    }
    current.push(line);
  }
  const text = (lines) => trimBlankLines(lines.join('\n'));
  return { lead: text(lead), sections: sections.map((s) => ({ heading: s.heading, text: text(s.lines) })) };
}

// A section that is exactly one fenced block means "take this literally":
// the fence protects lines Markdown would otherwise read as headings or code.
export function unwrapFence(text) {
  const lines = text.split('\n');
  const open = lines[0]?.match(FENCE_OPEN);
  if (!open || lines.length < 2 || !isClosingFence(lines.at(-1), open[1])) return text;
  // An interior line that would close the fence means the block ended early
  // and the rest is not part of it; leave the whole section as written.
  if (lines.slice(1, -1).some((line) => isClosingFence(line, open[1]))) return text;
  return lines.slice(1, -1).join('\n');
}

export function parseCase(text, filename) {
  const label = path.basename(filename);
  const stem = path.basename(filename, '.md');
  const { data, body } = parseFrontmatter(text, label);
  if (data.id !== stem) {
    throw new Error(`${label}: frontmatter id "${data.id}" does not match the filename`);
  }
  const item = { ...data };
  const { lead, sections } = splitSections(body);
  if (lead) {
    if (!PROMPT_TYPES.has(item.type)) {
      throw new Error(`${label}: text before the first heading is only allowed as a prompt on discrimination and detection cases`);
    }
    item.prompt = lead;
  }
  const choiceField = CHOICE_FIELD[item.type];
  for (const { heading, text: raw } of sections) {
    if (raw === '') throw new Error(`${label}: section "${heading}" is empty`);
    const content = unwrapFence(raw);
    if (RESERVED[heading]) {
      item[RESERVED[heading]] = YAML_SECTIONS.has(heading) ? YAML.parse(content) : content;
    } else if (choiceField) {
      item[choiceField] ??= {};
      if (Object.hasOwn(item[choiceField], heading)) throw new Error(`${label}: duplicate section "${heading}"`);
      item[choiceField][heading] = content;
    } else {
      throw new Error(`${label}: unknown section "${heading}" for a ${item.type} case`);
    }
  }
  return item;
}

export function suiteSkill(readmePath) {
  return path.basename(path.dirname(path.dirname(readmePath)));
}

export function findSuites(repoRoot) {
  const skillsDir = path.join(repoRoot, 'home/.agents/skills');
  const suites = [];
  for (const entry of readdirSync(skillsDir)) {
    const dir = path.join(skillsDir, entry);
    // Vendored skills are symlinks into the submodule; only real directories
    // in this repo can carry evals we maintain.
    if (lstatSync(dir).isSymbolicLink() || !lstatSync(dir).isDirectory()) continue;
    const readme = path.join(dir, 'evals', 'README.md');
    if (existsSync(readme)) suites.push(readme);
  }
  return suites.sort();
}

export function loadSuite(readmePath) {
  const dir = path.dirname(readmePath);
  const { data } = parseFrontmatter(readFileSync(readmePath, 'utf8'), path.basename(readmePath));
  const skill = suiteSkill(readmePath);
  if (data.skill !== skill) {
    throw new Error(`README.md: skill "${data.skill}" does not match the directory "${skill}"`);
  }
  const cases = readdirSync(dir)
    .filter((name) => name.endsWith('.md') && name !== 'README.md')
    .sort()
    .map((name) => parseCase(readFileSync(path.join(dir, name), 'utf8'), path.join(dir, name)));
  const suite = { skill, cases };
  if (data.min_pass_rate !== undefined) suite.min_pass_rate = data.min_pass_rate;
  return suite;
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd evals && node --test test/suite-md.test.mjs`
Expected: all tests pass. Then run the whole suite: `cd evals && npm test`. Expected: every existing test still passes (nothing else changed yet).

- [ ] **Step 7: Commit**

```bash
git add evals/package.json evals/package-lock.json evals/lib/suite-md.mjs evals/test/suite-md.test.mjs evals/test/fixtures/suite
git commit -F - <<'EOF'
Add a Markdown suite loader for eval cases

One file per case, YAML frontmatter for the keys the graders compare and H2 sections for everything a human reads. A section that is exactly one fenced block is unwrapped so code variants and detection documents survive Markdown. Not wired to the harness yet; the next commit migrates the suites and switches the callers.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 2: Migrate the three suites and switch the harness to the new loader

**Files:**
- Modify: `evals/lib/load-evals.mjs` (drop `findEvalFiles`/`loadEvals`; re-export `findSuites`, `loadSuite`, `suiteSkill`)
- Modify: `evals/tests.mjs:3,33-38`
- Modify: `evals/bin/validate.mjs:7,11-13`
- Modify: `evals/bin/check-gate.mjs:9,73`
- Modify: `evals/bin/affected-skills.mjs:7,13`
- Modify: `evals/test/load-evals.test.mjs:5,9-30`
- Modify: `evals/test/generator.test.mjs:6,132,190-191`
- Modify: `evals/test/check-gate.test.mjs:97-107,110`
- Create: `home/.agents/skills/code-comment-register/evals/README.md` plus 16 case files
- Create: `home/.agents/skills/prose-register/evals/README.md` plus 24 case files
- Create: `home/.agents/skills/code-review-register/evals/README.md` plus 18 case files
- Delete: the three `home/.agents/skills/*/evals.json`
- Temporary, never committed: `evals/scratch-migrate.mjs`

**Interfaces:**
- Consumes from Task 1: `findSuites`, `loadSuite`, `suiteSkill`, `parseCase`.
- Produces: `evals/lib/load-evals.mjs` exports `SUPPORTED_TYPES`, `validateData`, `findSuites`, `loadSuite`, `suiteSkill`. Every caller uses `findSuites(REPO_ROOT)` (README paths) and `suiteSkill(readme)` to name a skill.

- [ ] **Step 1: Update the tests that name the file layout**

In `evals/test/load-evals.test.mjs`, change the import and the first three tests:
```js
import { SUPPORTED_TYPES, findSuites, loadSuite, suiteSkill, validateData } from '../lib/load-evals.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

test('findSuites locates every existing suite', () => {
  const skills = findSuites(REPO_ROOT).map(suiteSkill);
  assert.ok(skills.includes('code-comment-register'));
  assert.ok(skills.includes('prose-register'));
  assert.ok(skills.includes('code-review-register'));
});

test('code-comment-register evals validate with zero unsupported cases', () => {
  const data = loadSuite(path.join(REPO_ROOT, 'home/.agents/skills/code-comment-register/evals/README.md'));
  const { caseCount, unsupported } = validateData(data);
  assert.equal(caseCount, 16);
  assert.equal(unsupported.length, 0);
});

test('prose-register evals validate with zero unsupported cases', () => {
  const data = loadSuite(path.join(REPO_ROOT, 'home/.agents/skills/prose-register/evals/README.md'));
  const { caseCount, unsupported } = validateData(data);
  assert.equal(caseCount, 24);
  assert.equal(unsupported.length, 0);
});
```
Leave every other test in that file as it is (they build data objects by hand).

In `evals/test/generator.test.mjs`: change the import on line 6 to `import { findSuites, loadSuite, suiteSkill } from '../lib/load-evals.mjs';`; change the regex on line 132 from `/no evals\.json/` to `/no evals\/README\.md/`; and in the leak test replace the two lines that locate and load the suite with:
```js
    const readme = findSuites(REPO_ROOT).find((f) => suiteSkill(f) === skill);
    const data = loadSuite(readme);
```

In `evals/test/check-gate.test.mjs`, the throwaway skills tree becomes the new layout. Replace `runGateWithSkills` and `evalsJson`:
```js
// EVAL_REPO_ROOT points the gate at a throwaway skills tree, so the floor
// tests don't depend on the real suites' values.
function runGateWithSkills(skills, rows, ...args) {
  const root = mkdtempSync(path.join(os.tmpdir(), 'gate-root-'));
  for (const [name, content] of Object.entries(skills)) {
    const dir = path.join(root, 'home/.agents/skills', name, 'evals');
    mkdirSync(dir, { recursive: true });
    writeFileSync(path.join(dir, 'README.md'), content);
  }
  const file = path.join(mkdtempSync(path.join(os.tmpdir(), 'gate-')), 'results.json');
  writeFileSync(file, JSON.stringify({ results: { results: rows } }));
  return spawnSync(process.execPath, [GATE, file, ...args], {
    encoding: 'utf8',
    env: { ...process.env, EVAL_REPO_ROOT: root },
  });
}

// A README with only frontmatter is a valid, empty suite.
const readme = (extra = {}) =>
  `---\n${Object.entries({ skill: 'alpha', ...extra }).map(([k, v]) => `${k}: ${v}`).join('\n')}\n---\n`;
const MALFORMED_README = '---\nskill: [unclosed\n---\n';
```
Then replace every `evalsJson(` with `readme(` and every `'{ truncated'` with `MALFORMED_README` in that file, and rename the two test titles that say `evals.json` to say `README` (`"a skill's README can set its own floor"`, `"a sibling skill's malformed README does not touch this skill's gate"`, `"the skill's own unreadable README warns and falls back to the default floor"`). The `beta` sibling in the sibling test uses `MALFORMED_README`; note that with the skill named `beta` the README's `skill: alpha` line does not matter because parsing fails before the name check.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd evals && npm test 2>&1 | grep -E '^ℹ (pass|fail)'`
Expected: several failures (`findSuites`/`loadSuite`/`suiteSkill` are not exported from `load-evals.mjs`, and the real suites do not exist yet).

- [ ] **Step 3: Rewire `load-evals.mjs` and the four callers**

`evals/lib/load-evals.mjs`: delete the `readFileSync, readdirSync, existsSync, lstatSync` import, the `findEvalFiles` function and the `loadEvals` function. Add at the top:
```js
export { findSuites, loadSuite, suiteSkill } from './suite-md.mjs';
```
Keep `import path from 'node:path'` only if still used (it is not after the deletions; remove it), keep the `normalize` import, `SUPPORTED_TYPES`, `requireField`, and `validateData` unchanged.

`evals/tests.mjs`: line 3 becomes `import { findSuites, loadSuite, suiteSkill, validateData, SUPPORTED_TYPES } from './lib/load-evals.mjs';`. Replace lines 33 to 40 with:
```js
  const readme = findSuites(REPO_ROOT).find((file) => suiteSkill(file) === skillName);
  if (!readme) {
    throw new Error(`no evals/README.md found for skill "${skillName}" under home/.agents/skills`);
  }

  const data = loadSuite(readme);
```

`evals/bin/validate.mjs`: import `findSuites, loadSuite, suiteSkill, validateData`; the header comment becomes `// Offline structural validation of every eval suite: zero model calls.`; `const files = findSuites(REPO_ROOT);`; the empty message becomes `'no evals/README.md files found under home/.agents/skills'`; inside the loop `const skill = suiteSkill(file);` and `validateData(loadSuite(file))`.

`evals/bin/check-gate.mjs`: import `findSuites, loadSuite, suiteSkill`; in `skillMinRate`, `const file = findSuites(REPO_ROOT).find((candidate) => suiteSkill(candidate) === skill); return file ? loadSuite(file).min_pass_rate : undefined;`. Update the two comments that say `evals.json` to say `evals/README.md`.

`evals/bin/affected-skills.mjs`: import `findSuites, suiteSkill`; `const evaluated = findSuites(REPO_ROOT).map(suiteSkill);`.

- [ ] **Step 4: Write the migration script (temporary)**

Save as `evals/scratch-migrate.mjs`. It writes the new layout, loads it back through the real loader, asserts round-trip equality, and only then deletes the JSON. Do not stage this file.
```js
// One-off: evals.json -> evals/README.md + one Markdown file per case.
// Proves round-trip equality through the real loader before deleting the JSON.
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import YAML from 'yaml';
import { loadSuite } from './lib/suite-md.mjs';

const REPO_ROOT = path.resolve(import.meta.dirname, '..');
const STATUS = { 'code-comment-register': 'approved', 'prose-register': 'approved', 'code-review-register': 'draft' };
const yaml = (value) => YAML.stringify(value, { lineWidth: 0 });

// Section order inside a case file. Variants and stages come after `rule` and
// `evidence`, before the transformation and detection sections; `note` closes.
const SECTIONS = [
  ['rule_quote', 'rule'], ['evidence', 'evidence'], ['input', 'input'], ['task', 'task'],
  ['reference_after', 'reference'], ['rubric', 'rubric'], ['input_document', 'document'],
  ['violations', 'violations'], ['traps', 'traps'],
];
const PROSE_FIELDS = new Set(['prompt', 'grading_note', 'variants', 'stages', ...SECTIONS.map(([field]) => field)]);
const YAML_FIELDS = new Set(['rubric', 'violations', 'traps']);

// Markdown would read a leading "#" as a heading and leading whitespace as
// code, and a fence inside a section needs a longer fence around it.
function fenced(text) {
  const needs = /^#/m.test(text) || /^[ \t]+\S/m.test(text) || /```|~~~/.test(text);
  if (!needs) return text;
  const longest = Math.max(2, ...[...text.matchAll(/`+/g)].map((m) => m[0].length));
  const fence = '`'.repeat(longest + 1);
  return `${fence}\n${text}\n${fence}`;
}

function renderCase(item, status) {
  const front = { id: item.id, type: item.type, status };
  for (const [key, value] of Object.entries(item)) {
    if (key === 'id' || key === 'type' || PROSE_FIELDS.has(key)) continue;
    front[key] = value;
  }
  const parts = [`---\n${yaml(front)}---`];
  if (item.prompt) parts.push(item.prompt);
  const section = (heading, text) => parts.push(`## ${heading}\n\n${text}`);
  const choices = item.variants ?? item.stages;
  for (const [field, heading] of SECTIONS) {
    if (item[field] === undefined) continue;
    if (field === 'input' && choices) throw new Error(`${item.id}: unexpected variants on a transformation`);
    if (field === 'evidence' || field === 'rule_quote') section(heading, fenced(item[field]));
    else if (YAML_FIELDS.has(field)) section(heading, yaml(item[field]).trimEnd());
    else section(heading, fenced(item[field]));
    // Choices sit right after rule and evidence so a reader meets them before the mechanics.
    if (field === 'evidence' && choices) for (const [key, text] of Object.entries(choices)) section(key, fenced(text));
  }
  if (choices && item.evidence === undefined) for (const [key, text] of Object.entries(choices)) section(key, fenced(text));
  if (item.grading_note) section('note', fenced(item.grading_note));
  return `${parts.join('\n\n')}\n`;
}

// The README body is prose for humans; the harness reads only its frontmatter.
function renderValue(value, depth = 0) {
  const pad = '  '.repeat(depth);
  if (typeof value === 'string') return `${pad}${value}`;
  if (Array.isArray(value)) return value.map((v) => (typeof v === 'string' ? `${pad}- ${v}` : renderValue(v, depth))).join('\n');
  return Object.entries(value)
    .map(([k, v]) => (typeof v === 'string' ? `${pad}- **${k}:** ${v}` : `${pad}- **${k}:**\n${renderValue(v, depth + 1)}`))
    .join('\n');
}

function renderReadme(data) {
  const front = { skill: data.skill };
  if (data.min_pass_rate !== undefined) front.min_pass_rate = data.min_pass_rate;
  const body = [`# ${data.skill} evals`];
  if (data.description) body.push(`## Description\n\n${data.description}`);
  if (data.provenance) body.push(`## Provenance\n\n${renderValue(data.provenance)}`);
  if (data.case_types) body.push(`## Case types\n\n${renderValue(data.case_types)}`);
  if (data.coverage_gaps) body.push(`## Coverage gaps\n\n${data.coverage_gaps.map((g) => `- **${g.rule}** ${g.gap}`).join('\n')}`);
  if (data.notes) body.push(`## Notes\n\n${data.notes}`);
  return `---\n${yaml(front)}---\n\n${body.join('\n\n')}\n`;
}

const byId = (cases) => [...cases].sort((a, b) => a.id.localeCompare(b.id));

for (const [skill, status] of Object.entries(STATUS)) {
  const skillDir = path.join(REPO_ROOT, 'home/.agents/skills', skill);
  const jsonPath = path.join(skillDir, 'evals.json');
  const data = JSON.parse(readFileSync(jsonPath, 'utf8'));
  const dir = path.join(skillDir, 'evals');
  mkdirSync(dir, { recursive: true });
  writeFileSync(path.join(dir, 'README.md'), renderReadme(data));
  for (const item of data.cases) writeFileSync(path.join(dir, `${item.id}.md`), renderCase(item, status));

  // Round trip: the loaded suite equals the JSON once status is stripped and
  // the top-level prose fields (now README body) are dropped.
  const loaded = loadSuite(path.join(dir, 'README.md'));
  const stripped = loaded.cases.map(({ status: s, ...rest }) => (assert.equal(s, status), rest));
  assert.deepEqual(byId(stripped), byId(data.cases), `${skill}: cases differ after round trip`);
  assert.equal(loaded.skill, data.skill);
  assert.equal(loaded.min_pass_rate, data.min_pass_rate);
  rmSync(jsonPath);
  console.log(`${skill}: ${data.cases.length} cases migrated as ${status}, round trip equal`);
}
```

- [ ] **Step 5: Run the migration and verify the round trip**

Run:
```bash
cd evals && node scratch-migrate.mjs && rm scratch-migrate.mjs && cd .. && git status --short | head -5 && ls home/.agents/skills/*/evals | head -12
```
Expected: three lines ending `round trip equal`; `git status` shows the three `evals.json` deleted (`D`) and three new `evals/` directories untracked; no `scratch-migrate.mjs` remains. If an assertion fails, fix the renderer or the parser (never the case data), re-run `git checkout -- home/.agents/skills/*/evals.json && rm -rf home/.agents/skills/*/evals` first so the script starts clean.

Open one migrated file of each kind and read it as a reviewer would: `home/.agents/skills/code-comment-register/evals/disc-04.md` (fenced Elixir variants), `home/.agents/skills/code-review-register/evals/det-02.md` (four-backtick document with an inner suggestion fence), `home/.agents/skills/prose-register/evals/disc-03.md` (rank case with `source_commits` in frontmatter). Each must end with a single newline (`tail -c1 <file> | xxd` prints `0a`).

- [ ] **Step 6: Run the tests and the validator**

Run: `cd evals && npm test 2>&1 | grep -E '^ℹ (pass|fail)' && node bin/validate.mjs`
Expected: `fail 0`; validate prints `code-comment-register: 16 cases ok`, `code-review-register: 18 cases ok`, `prose-register: 24 cases ok`. Also `EVAL_SKILL=code-review-register node -e "import('./tests.mjs').then(m => m.default()).then(t => console.log(t.length))"` prints `18`.

- [ ] **Step 7: Commit**

```bash
git add evals/lib/load-evals.mjs evals/tests.mjs evals/bin/validate.mjs evals/bin/check-gate.mjs evals/bin/affected-skills.mjs evals/test/load-evals.test.mjs evals/test/generator.test.mjs evals/test/check-gate.test.mjs home/.agents/skills/code-comment-register/evals home/.agents/skills/prose-register/evals home/.agents/skills/code-review-register/evals
git rm -q home/.agents/skills/code-comment-register/evals.json home/.agents/skills/prose-register/evals.json home/.agents/skills/code-review-register/evals.json
git status --short | grep -v '^[AMDR] ' ; git commit -F - <<'EOF'
Migrate the eval suites to one Markdown file per case

Every case is now a file a reviewer can read as prose and diff by the sentence; the keys the graders compare sit in its frontmatter. The harness reads the directory through the new loader; a one-off script wrote the files and proved that loading them back equals the old JSON, case for case, before deleting it. Existing suites migrate as approved; the new review-register cases as draft, to be approved one at a time.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```
The `git status` line before the commit must print nothing (no untracked or unstaged files).

---

### Task 3: Draft status in validation, the generator and the gate

**Files:**
- Modify: `evals/lib/load-evals.mjs` (`validateData`: status check, `draftCount`)
- Modify: `evals/tests.mjs:56` (row metadata gains `status`)
- Modify: `evals/bin/validate.mjs` (report drafts)
- Modify: `evals/bin/check-gate.mjs` (drafts never gate, excluded from the floor)
- Modify: `evals/test/load-evals.test.mjs`, `evals/test/generator.test.mjs`, `evals/test/check-gate.test.mjs`

**Interfaces:**
- Consumes: `validateData(data)` from Task 2's `load-evals.mjs`.
- Produces: `validateData` returns `{ caseCount, unsupported, draftCount }`; every generated promptfoo test carries `metadata.status`; `check-gate.mjs` prints `; N draft rows, M passed` when drafts exist.

- [ ] **Step 1: Write the failing tests**

Append to `evals/test/load-evals.test.mjs`:
```js
test('validateData requires status to be draft or approved and counts drafts', () => {
  const ok = arguableCase({ status: 'draft' });
  assert.equal(validateData(ok).draftCount, 1);
  assert.equal(validateData(arguableCase({ status: 'approved' })).draftCount, 0);
  assert.throws(() => validateData(arguableCase({})), /d1\.status must be "draft" or "approved"/);
  assert.throws(() => validateData(arguableCase({ status: 'reviewed' })), /d1\.status must be "draft" or "approved"/);
});
```
Every hand-built data object elsewhere in that file lacks `status`; add `status: 'approved'` to the case in `arguableCase`, `detectionCase`, and each inline `cases: [{ ... }]` literal in the file so those tests keep passing (the throws they assert on come from earlier checks and stay the same).

Append to `evals/test/generator.test.mjs`:
```js
test('every generated row carries the case status so the gate can tell drafts apart', async () => {
  const tests = await withEnv(
    { EVAL_SKILL: 'code-review-register', EVAL_ONLY: undefined, EVAL_TYPES: undefined },
    generateTests,
  );
  assert.ok(tests.every((t) => t.metadata.status === 'draft'), 'review-register cases migrated as draft');
  const approved = await withEnv(
    { EVAL_SKILL: 'code-comment-register', EVAL_ONLY: undefined, EVAL_TYPES: undefined },
    generateTests,
  );
  assert.ok(approved.every((t) => t.metadata.status === 'approved'));
});
```

Append to `evals/test/check-gate.test.mjs` (the file already defines `row`, `choice`, `rule`, `detect`, `passing`, `runGate`; a row's third argument merges into its metadata):
```js
test('a draft row with a wrong choice never hard-gates and stays out of the floor', () => {
  const rows = [...passing(9), row('draft-1', [choice(false), rule(true)], { status: 'draft' })];
  const result = runGate(rows);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /9\/9 passed/);
  assert.match(result.stdout, /1 draft rows, 0 passed/);
});

test('draft rows do not lift the pass rate either', () => {
  // 8 of 9 gated rows pass (88.9%), under the 90% default; 5 passing drafts must not rescue it.
  const rows = [
    ...passing(8),
    row('det-0', [detect(false)]),
    ...Array.from({ length: 5 }, (_, i) => row(`draft-${i}`, [choice(true), rule(true)], { status: 'draft' })),
  ];
  const result = runGate(rows);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /8\/9 passed/);
  assert.match(result.stdout, /5 draft rows, 5 passed/);
});

test('a run of only draft rows passes and says so', () => {
  const rows = Array.from({ length: 3 }, (_, i) => row(`draft-${i}`, [choice(false), rule(false)], { status: 'draft' }));
  const result = runGate(rows);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /0\/0 passed/);
  assert.match(result.stdout, /3 draft rows, 0 passed/);
});
```
Check how `row(...)` merges its third argument in this file's helpers (near the top). If it takes `{ skill }` only, extend the helper so extra keys land in `testCase.metadata`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd evals && npm test 2>&1 | grep -E '^ℹ (pass|fail)|^not ok' | head`
Expected: the new tests fail (`draftCount` undefined, `status` missing from metadata, no draft line in the gate output).

- [ ] **Step 3: Implement**

`evals/lib/load-evals.mjs`, inside the `for (const item of data.cases)` loop right after the duplicate-id check, add:
```js
    if (item.status !== 'draft' && item.status !== 'approved') {
      throw new Error(`${item.id}.status must be "draft" or "approved"`);
    }
```
Before the loop add `let draftCount = 0;`, inside it after the status check `if (item.status === 'draft') draftCount++;`, and return `{ caseCount: data.cases.length, unsupported, draftCount }`.

`evals/tests.mjs`, in the `base` object: `metadata: { skill: data.skill, case_id: item.id, case_type: item.type, status: item.status, ...(item.arguable && { arguable: true }) },`.

`evals/bin/validate.mjs`: destructure `draftCount` and print `${skill}: ${caseCount} cases ok${draftCount ? ` (${draftCount} draft)` : ''}${warning}`.

`evals/bin/check-gate.mjs`: after the `meta` and `components` helpers add
```js
// A draft case has not been approved by its author, so it runs for
// information only: it can neither hard-gate nor move the floor.
const isDraft = (row) => meta(row).status === 'draft';
```
Then: `const gated = rows.filter((row) => !isDraft(row)); const drafts = rows.filter(isDraft);`. Compute `hardFailures` over `gated`, `passed` over `gated`, and `passRate = gated.length ? passed / gated.length : 1`. Change the summary line to use `gated.length` in place of `rows.length` and append, when `drafts.length > 0`, the text `; ${drafts.length} draft rows, ${drafts.filter(countsAsPassed).length} passed`. Keep the `skills` set computed over all rows.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd evals && npm test 2>&1 | grep -E '^ℹ (pass|fail)' && node bin/validate.mjs`
Expected: `fail 0`; validate prints `code-review-register: 18 cases ok (18 draft)` and the other two without a draft note.

- [ ] **Step 5: Commit**

```bash
git add evals/lib/load-evals.mjs evals/tests.mjs evals/bin/validate.mjs evals/bin/check-gate.mjs evals/test/load-evals.test.mjs evals/test/generator.test.mjs evals/test/check-gate.test.mjs
git commit -F - <<'EOF'
Let draft eval cases run without gating

A case's status records whether its author has read it and stands behind the key. Drafts still run and are reported, but a draft can neither hard-gate nor count toward the pass-rate floor, so a freshly authored suite can sit in the tree while it is reviewed one case at a time.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 4: Point the docs at the new format

**Files:**
- Modify: `CLAUDE.md:17` (the `make eval` bullet)
- Modify: `evals/promptfooconfig.yaml:1-2`
- Modify: `docs/superpowers/specs/2026-08-29-skill-eval-suite-design.md:25` (decision 2)

- [ ] **Step 1: Edit the three references**

`CLAUDE.md`, the `make eval` bullet: replace ``one skill's `evals.json` `` with ``one skill's `evals/` suite (one Markdown case per file, `evals/README.md` for the suite; see `docs/superpowers/specs/2026-09-25-eval-cases-markdown-design.md`)``. Leave the rest of the bullet as it is.

`evals/promptfooconfig.yaml`, lines 1 and 2:
```yaml
# Runner entry point only. Test cases live in home/.agents/skills/*/evals/ (one
# Markdown file per case) and are generated by tests.mjs. Requires EVAL_SKILL; see Makefile `eval`.
```

`docs/superpowers/specs/2026-08-29-skill-eval-suite-design.md`, decision 2: keep the existing sentence and append: `**Superseded 2026-09-25:** the canonical format is now one Markdown file per case under `evals/`, with a README per suite and a required `status`; see `2026-09-25-eval-cases-markdown-design.md`. The loader returns the same data shape, so the rest of this document stands.`

- [ ] **Step 2: Verify nothing else names the old file**

Run: `grep -rn "evals\.json" CLAUDE.md evals --include='*.mjs' --include='*.yaml' | grep -v node_modules`
Expected: no output. (The historical plans under `docs/superpowers/plans/` and the prose-register handoff notes keep their references on purpose.)

Run: `cd evals && npm test 2>&1 | grep -E '^ℹ (pass|fail)' && node bin/validate.mjs`
Expected: `fail 0`, three suites ok.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md evals/promptfooconfig.yaml docs/superpowers/specs/2026-08-29-skill-eval-suite-design.md
git commit -F - <<'EOF'
Point the eval docs at the Markdown case format

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

## Final verification (after Task 4)

Run from the worktree root:
```bash
make eval-validate eval-test
git log --oneline origin/code-review-register-evals..HEAD
git diff --stat origin/code-review-register-evals..HEAD | tail -1
for f in $(git ls-files 'home/.agents/skills/*/evals/*.md'); do tail -c1 "$f" | xxd -p | grep -q 0a || echo "missing final newline: $f"; done
grep -rn $'\xe2\x80\x94' evals/lib evals/bin evals/test/suite-md.test.mjs docs/superpowers/specs/2026-09-25-eval-cases-markdown-design.md docs/superpowers/plans/2026-09-25-eval-cases-markdown.md || echo "no em-dashes"
```
Expected: validate and tests green; five commits after the spec commit (spec, Task 1, Task 2, Task 3, Task 4); every case file ends in a newline; no em-dashes in new code or docs. The whole-branch review then runs on the top-tier model before the PR opens.
