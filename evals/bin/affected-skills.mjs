#!/usr/bin/env node
// Reads changed paths on stdin, one per line; prints the evaluated skills
// they affect as a JSON array for the evals workflow's matrix.
import path from 'node:path';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { findEvalFiles } from '../lib/load-evals.mjs';
import { affectedSkills } from '../lib/affected.mjs';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

const changed = readFileSync(0, 'utf8').split('\n').map((line) => line.trim()).filter(Boolean);
const evaluated = findEvalFiles(REPO_ROOT).map((file) => path.basename(path.dirname(file)));
console.log(JSON.stringify(affectedSkills(changed, evaluated)));
