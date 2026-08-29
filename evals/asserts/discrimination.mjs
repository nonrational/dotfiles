import { keywordOverlap } from './heuristics.mjs';

export default function assertDiscrimination(output, context) {
  const { letter_to_key: letterToKey, correct, expected_rule: expectedRule } = context.vars;
  const answerMatch = output.match(/ANSWER:\s*([A-Za-z])/i);
  const ruleMatch = output.match(/RULE:\s*([^\n]+)/i);

  if (!answerMatch) {
    return { pass: false, score: 0, reason: 'No ANSWER line in output' };
  }

  const chosenKey = letterToKey[answerMatch[1].toUpperCase()];
  const ruleText = ruleMatch ? ruleMatch[1].trim() : '';
  const overlap = ruleText ? keywordOverlap(ruleText, expectedRule) : 0;
  const variantCorrect = chosenKey === correct;
  const pass = variantCorrect && overlap >= 0.2;

  if (pass) {
    return { pass, score: 1, reason: `chose ${chosenKey}; rule overlap ${overlap.toFixed(2)}` };
  }
  if (variantCorrect) {
    return {
      pass: false,
      score: 0.5,
      reason: `correct choice, weak rule match (${overlap.toFixed(2)}): "${ruleText}"`,
    };
  }
  return {
    pass: false,
    score: 0,
    reason: `chose ${chosenKey ?? answerMatch[1]}, expected ${correct}`,
  };
}
