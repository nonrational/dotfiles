// Grades only the choice: one letter, or for rank cases the full best-first
// ordering. The stated rule is judged by a separate llm-rubric assert:
// keyword overlap failed correct paraphrases at random.
export default function assertDiscrimination(output, context) {
  const { letter_to_key: letterToKey, correct, correct_ranking: correctRankingCsv } = context.vars;
  // promptfoo expands an array-of-primitives var into one test per element, so
  // tests.mjs sends this as a comma-joined string instead of an array.
  const correctRanking = correctRankingCsv ? correctRankingCsv.split(',') : null;
  // The prompt asks for the ANSWER line at the end; take the last match so a
  // model that echoes the format template earlier isn't graded on that instead.
  const answerLines = [...output.matchAll(/ANSWER:\s*([^\n]+)/gi)];
  const answerLine = answerLines.at(-1);

  if (!answerLine) {
    return { pass: false, score: 0, reason: 'No ANSWER line in output' };
  }

  // Standalone letters only, so "Version B" reads as B rather than V.
  const letters = answerLine[1].toUpperCase().match(/\b[A-Z]\b/g) ?? [];
  const chosen = letters.map((letter) => letterToKey[letter] ?? letter);

  if (correctRanking) {
    const pass = chosen.join(',') === correctRanking.join(',');
    const ranked = chosen.join(' > ');
    return pass
      ? { pass, score: 1, reason: `ranked ${ranked}` }
      : { pass, score: 0, reason: `ranked ${ranked}, expected ${correctRanking.join(' > ')}` };
  }

  if (chosen[0] === correct) {
    return { pass: true, score: 1, reason: `chose ${chosen[0]}` };
  }
  return { pass: false, score: 0, reason: `chose ${chosen[0] ?? answerLine[1]}, expected ${correct}` };
}
