// Grades only the choice. The stated rule is judged by a separate llm-rubric
// assert: keyword overlap failed correct paraphrases at random.
export default function assertDiscrimination(output, context) {
  const { letter_to_key: letterToKey, correct } = context.vars;
  const answerMatch = output.match(/ANSWER:\s*([A-Za-z])/i);

  if (!answerMatch) {
    return { pass: false, score: 0, reason: 'No ANSWER line in output' };
  }

  const chosenKey = letterToKey[answerMatch[1].toUpperCase()];
  if (chosenKey === correct) {
    return { pass: true, score: 1, reason: `chose ${chosenKey}` };
  }
  return { pass: false, score: 0, reason: `chose ${chosenKey ?? answerMatch[1]}, expected ${correct}` };
}
