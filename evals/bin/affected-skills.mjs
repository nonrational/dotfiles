#!/usr/bin/env node
// Reads changed paths on stdin, one per line; prints the evaluated skills
// they affect as a JSON array for the evals workflow's matrix.
import path from 'node:path';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { findSuites, suiteSkill } from '../lib/load-evals.mjs';
import { affectedSkills } from '../lib/affected.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

const changed = readFileSync(0, 'utf8').split('\n').map((line) => line.trim()).filter(Boolean);
const evaluated = findSuites(REPO_ROOT).map(suiteSkill);
console.log(JSON.stringify(affectedSkills(changed, evaluated)));
