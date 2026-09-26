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

test('parseFrontmatter names the file when the YAML fails to parse', () => {
  const text = '---\nid: d1\nexpected_rule: A: B\n---\n\nP\n';
  assert.throws(() => parseFrontmatter(text, 'd1.md'), /d1\.md: frontmatter: /);
});

test('parseFrontmatter tolerates a leading BOM and trailing whitespace on delimiter lines', () => {
  const { data } = parseFrontmatter('﻿---\nid: x\n---  \n\nHello\n', 'x.md');
  assert.deepEqual(data, { id: 'x' });
  const { body } = parseFrontmatter('---\nid: x\n---\t\n\nHello\n', 'x.md');
  assert.equal(body, '\nHello\n');
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

test('parseCase names the file and section when a YAML section fails to parse', () => {
  const text = '---\nid: t1\ntype: transformation\nstatus: draft\n---\n\n## input\n\nI\n\n## task\n\nT\n\n## reference\n\nR\n\n## rubric\n\nkey: a: b\n';
  assert.throws(() => parseCase(text, 't1.md'), /t1\.md: section "rubric": /);
});

test('parseCase requires a reserved heading to be written exactly lowercase', () => {
  const capitalized = '---\nid: d1\ntype: discrimination\nstatus: draft\ncorrect: a\nexpected_rule: r\n---\n\nP\n\n## a\n\nA\n\n## b\n\nB\n\n## Note\n\nN\n';
  assert.throws(() => parseCase(capitalized, 'd1.md'), /d1\.md: section "Note" must be lowercase "note"/);
});

test('parseCase looks reserved headings up by own property so a heading matching Object.prototype is a variant', () => {
  const text = '---\nid: d1\ntype: discrimination\nstatus: draft\ncorrect: a\nexpected_rule: r\n---\n\nP\n\n## constructor\n\ntext\n\n## a\n\nA\n';
  const item = parseCase(text, 'd1.md');
  assert.equal(item.variants.constructor, 'text');
  assert.deepEqual(Object.keys(item.variants), ['constructor', 'a']);
});

test('parseCase rejects a second reserved heading of the same name as a duplicate', () => {
  const text = '---\nid: d1\ntype: discrimination\nstatus: draft\ncorrect: a\nexpected_rule: r\n---\n\nP\n\n## rule\n\nR1\n\n## rule\n\nR2\n\n## a\n\nA\n\n## b\n\nB\n';
  assert.throws(() => parseCase(text, 'd1.md'), /d1\.md: duplicate section "rule"/);
});

test('parseCase rejects an unclosed fence, naming the section it opened in', () => {
  const text = '---\nid: d1\ntype: discrimination\nstatus: draft\ncorrect: a\nexpected_rule: r\n---\n\nP\n\n## a\n\n```\nunclosed\n\n## b\n\nB\n';
  assert.throws(() => parseCase(text, 'd1.md'), /d1\.md: unclosed fence opened in section "a"/);
});

test('parseCase requires type before checking lead text, and reports missing type by name', () => {
  const text = '---\nid: d1\nstatus: draft\n---\n\nSome lead text\n\n## a\n\nA\n';
  assert.throws(() => parseCase(text, 'd1.md'), /d1\.md: frontmatter is missing type/);
});

test('parseCase rejects an id that disagrees with the filename', () => {
  const text = '---\nid: d1\ntype: discrimination\nstatus: draft\ncorrect: a\nexpected_rule: r\n---\n\nP\n\n## a\n\nA\n\n## b\n\nB\n';
  assert.throws(() => parseCase(text, '/x/evals/d2.md'), /d2\.md: frontmatter id "d1" does not match the filename/);
});

test('parseCase rejects lead text on a transformation, an unknown section, a duplicate section and an empty section', () => {
  const trans = '---\nid: t1\ntype: transformation\nstatus: draft\n---\n\nstray\n\n## input\n\nI\n';
  assert.throws(
    () => parseCase(trans, 't1.md'),
    /t1\.md: text before the first heading is only allowed as a prompt on discrimination, discrimination-structural, discrimination-rank and detection cases/,
  );
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
