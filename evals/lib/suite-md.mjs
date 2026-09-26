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
  // A BOM survives a save from some editors; trailing whitespace on a
  // delimiter line is easy to leave behind and costs nothing to tolerate.
  const lines = text.replace(/^﻿/, '').replace(/\r\n/g, '\n').split('\n');
  if (lines[0]?.trimEnd() !== '---') throw new Error(`${label}: file must start with a --- frontmatter line`);
  const end = lines.findIndex((line, i) => i > 0 && line.trimEnd() === '---');
  if (end === -1) throw new Error(`${label}: frontmatter is not closed by a --- line`);
  let data;
  try {
    data = YAML.parse(lines.slice(1, end).join('\n'));
  } catch (error) {
    throw new Error(`${label}: frontmatter: ${error.message}`);
  }
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
  let currentHeading = null;
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
      currentHeading = heading[1];
      sections.push({ heading: heading[1], lines: current });
      continue;
    }
    current.push(line);
  }
  // An unclosed fence swallows everything after it, including any later
  // heading line, so the file silently loses sections rather than erroring
  // where the author could see it. Catch that here instead.
  if (fence) throw new Error(`unclosed fence opened in section "${currentHeading ?? 'the lead'}"`);
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
  if (!data.type) {
    throw new Error(`${label}: frontmatter is missing type`);
  }
  const item = { ...data };
  let lead, sections;
  try {
    ({ lead, sections } = splitSections(body));
  } catch (error) {
    throw new Error(`${label}: ${error.message}`);
  }
  if (lead) {
    if (!PROMPT_TYPES.has(item.type)) {
      throw new Error(`${label}: text before the first heading is only allowed as a prompt on discrimination, discrimination-structural, discrimination-rank and detection cases`);
    }
    item.prompt = lead;
  }
  const choiceField = CHOICE_FIELD[item.type];
  for (const { heading, text: raw } of sections) {
    if (raw === '') throw new Error(`${label}: section "${heading}" is empty`);
    const content = unwrapFence(raw);
    const lower = heading.toLowerCase();
    // A reserved heading written with the wrong case would otherwise fall
    // through to the variant branch and grade as an extra, unlettered choice.
    if (Object.hasOwn(RESERVED, lower) && heading !== lower) {
      throw new Error(`${label}: section "${heading}" must be lowercase "${lower}"`);
    }
    if (Object.hasOwn(RESERVED, heading)) {
      const field = RESERVED[heading];
      if (Object.hasOwn(item, field)) throw new Error(`${label}: duplicate section "${heading}"`);
      if (YAML_SECTIONS.has(heading)) {
        try {
          item[field] = YAML.parse(content);
        } catch (error) {
          throw new Error(`${label}: section "${heading}": ${error.message}`);
        }
      } else {
        item[field] = content;
      }
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
    const stat = lstatSync(dir);
    if (stat.isSymbolicLink() || !stat.isDirectory()) continue;
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
