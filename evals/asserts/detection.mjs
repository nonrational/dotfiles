import { normalize } from './heuristics.mjs';

// A subject quote shorter than this would sit inside several key quotes at
// once ("just", "the code"), so it never counts on its own.
const MIN_OVERLAP = 20;

// Both strings are verbatim runs of the same document, so they refer to the
// same passage when one contains the other or the end of one is the start of
// the other. Returns the length of the shared run (0 when none counts) and
// whether the subject quote holds the whole key. A prefix-only match called
// det-03 a miss when the subject began its quote one word into the key and
// ran past the key's end.
export function overlap(keyQuote, subjectQuote) {
  const key = normalize(keyQuote);
  const quote = normalize(subjectQuote);
  const min = Math.min(MIN_OVERLAP, key.length);
  if (quote.length < min) return { length: 0, whole: false };
  if (quote.includes(key)) return { length: key.length, whole: true };
  if (key.includes(quote)) return { length: quote.length, whole: false };
  for (let len = Math.min(key.length, quote.length); len >= min; len--) {
    if (key.endsWith(quote.slice(0, len)) || quote.endsWith(key.slice(0, len))) {
      return { length: len, whole: false };
    }
  }
  return { length: 0, whole: false };
}

export const quotesOverlap = (keyQuote, subjectQuote) => overlap(keyQuote, subjectQuote).length > 0;

// A violation one character wide (det-03's em-dash) can be quoted from either
// side, and a quote that stops at the dash shares too little with the key for
// overlap to count. A target may name an anchor inside its quote that settles
// the match on its own.
function matches(target, quote) {
  if (target.anchor && quote.includes(normalize(target.anchor))) {
    return { length: normalize(target.quote).length, whole: true };
  }
  return overlap(target.quote, quote);
}

// One subject quote is one finding. It is credited to every target it holds
// whole and, when it holds none, to the single target it overlaps most; a
// quote that runs from one violation into the opening of the next is not a
// find of both.
function credited(targets, quote) {
  const scored = targets.map((target) => ({ target, ...matches(target, quote) }));
  const whole = scored.filter((s) => s.whole).map((s) => s.target);
  if (whole.length) return whole;
  const best = scored.filter((s) => s.length > 0).sort((a, b) => b.length - a.length)[0];
  return best ? [best.target] : [];
}

function subjectQuotes(output) {
  const quotes = [];
  for (const line of output.split('\n')) {
    const match = line.match(/^-\s*QUOTE:\s*(.*)$/i);
    if (!match) continue;
    const [text] = match[1].split(/\|\s*RULE:/i);
    const quote = normalize(text).replace(/^"|"$/g, '').trim();
    if (quote) quotes.push(quote);
  }
  return quotes;
}

export default function assertDetection(output, context) {
  const { violations, traps, min_recall: minRecall = 1 } = context.vars;
  const hit = new Set();
  for (const quote of subjectQuotes(output)) {
    for (const target of credited([...violations, ...traps], quote)) hit.add(target);
  }

  const missed = violations.filter((violation) => !hit.has(violation));
  const trapHits = traps.filter((trap) => hit.has(trap));

  const found = violations.length - missed.length;
  const recall = found / violations.length;
  // A case whose violation list is not exhaustive sets min_recall below 1 and
  // records recall as its score; a flagged trap fails at any floor.
  const pass = recall >= minRecall && trapHits.length === 0;
  const score = Math.max(0, (found - trapHits.length) / violations.length);
  const floor = minRecall < 1 ? `, floor ${minRecall}` : '';
  const reason =
    `${found}/${violations.length} violations, ${trapHits.length} trap(s) flagged${floor}` +
    (missed.length ? `; missed: ${missed.map((m) => m.quote.slice(0, 40)).join(' | ')}` : '') +
    (trapHits.length ? `; traps: ${trapHits.map((t) => t.quote.slice(0, 40)).join(' | ')}` : '');

  return { pass, score, reason };
}
