import { normalize } from './heuristics.mjs';

export default function assertDetection(output, context) {
  const { violations, traps } = context.vars;
  const violationLines = output
    .split('\n')
    .filter((line) => /^-\s*QUOTE:/i.test(line))
    .join('\n');
  const normalized = normalize(violationLines);

  const missed = violations.filter(
    (violation) => !normalized.includes(normalize(violation.quote).slice(0, 60)),
  );
  const trapHits = traps.filter(
    (trap) => normalized.includes(normalize(trap.quote).slice(0, 40)),
  );

  const found = violations.length - missed.length;
  const pass = missed.length === 0 && trapHits.length === 0;
  const score = Math.max(0, (found - trapHits.length) / violations.length);
  const reason = pass
    ? `${found}/${violations.length} violations, 0 traps`
    : `${found}/${violations.length} violations, ${trapHits.length} trap(s) flagged` +
      (missed.length ? `; missed: ${missed.map((m) => m.quote.slice(0, 40)).join(' | ')}` : '') +
      (trapHits.length ? `; traps: ${trapHits.map((t) => t.quote.slice(0, 40)).join(' | ')}` : '');

  return { pass, score, reason };
}
