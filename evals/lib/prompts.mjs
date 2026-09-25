export const SKILL_FRAMING = {
  'code-comment-register': {
    review: 'Review these inline source comments.',
    edit: 'Edit inline source comments.',
    detect: 'Review inline source comments.',
  },
};

function framing(skillName) {
  const entry = SKILL_FRAMING[skillName];
  if (!entry) throw new Error(`No prompt framing registered for skill "${skillName}"`);
  return entry;
}

export function buildSubjectPrompt(skillName, item) {
  const frame = framing(skillName);
  const useSkill = `Use the ${skillName} skill if it is available.`;

  if (item.type === 'discrimination') {
    const keys = Object.keys(item.variants);
    const letters = keys.map((_, index) => String.fromCharCode(65 + index));
    const letterToKey = Object.fromEntries(letters.map((letter, index) => [letter, keys[index]]));
    const listing = keys.map((key, index) => `${letters[index]}.\n${item.variants[key]}`).join('\n\n');

    const prompt = `${frame.review} ${useSkill}

${item.prompt}

${listing}

Pick one version. Name the specific rule that decides it.

End with exactly these two lines and nothing after:
ANSWER: <letter>
RULE: <one sentence>`;

    return { prompt, letterToKey };
  }

  if (item.type === 'transformation') {
    return {
      prompt: `${frame.edit} ${useSkill}

${item.task}

Code:
${item.input}

Reply with only the revised code, nothing else.`,
    };
  }

  if (item.type === 'detection') {
    return {
      prompt: `${frame.detect} ${useSkill}

${item.prompt}

Code:
${item.input_document}

List each violation on one line:
- QUOTE: "<exact offending comment text>" | RULE: <rule in your own words>

Reply only with violation lines in that format. Do not explain or mention
comments that pass the register.`,
    };
  }

  throw new Error(`No subject prompt builder for case type "${item.type}"`);
}

export function buildTransformationRubric(item) {
  return `Grade a source-comment rewrite against the rubric. Similar wording to the reference is not required.

Rule:
${item.rule_quote || ''}

Task given to the writer:
${item.task}

Original:
${item.input}

Reference-quality answer:
${item.reference_after}

The output passes ONLY if ALL THREE criteria hold:
1. violation_fixed: ${item.rubric.violation_fixed}
2. placement: ${item.rubric.placement}
3. no_new_violation: ${item.rubric.no_new_violation}

Notes:
${item.grading_note || 'None.'}`;
}
