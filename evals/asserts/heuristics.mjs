export function normalize(value) {
  return value
    .toLowerCase()
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201C\u201D]/g, "\"")
    .replace(/\s+/g, " ")
    .trim();
}

const STOP_WORDS = new Set([
  "about", "after", "against", "also", "because", "before", "comment", "does",
  "every", "from", "have", "into", "only", "rather", "that", "their", "there",
  "these", "they", "this", "when", "where", "which", "with",
]);

export function keywordOverlap(candidate, reference) {
  const words = (text) =>
    new Set(
      text
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, " ")
        .split(/\s+/)
        .filter((word) => word.length > 3 && !STOP_WORDS.has(word)),
    );

  const candidateWords = words(candidate);
  const referenceWords = words(reference);
  if (referenceWords.size === 0) return 0;

  let shared = 0;
  for (const word of referenceWords) {
    if (candidateWords.has(word)) shared++;
  }

  return shared / referenceWords.size;
}
