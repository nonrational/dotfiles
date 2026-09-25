export const SKILL_FRAMING = {
  'code-comment-register': {
    review: 'Review these inline source comments.',
    edit: 'Edit inline source comments.',
    detect: 'Review inline source comments.',
    material: 'Code',
    unit: 'comment',
    reply: 'Reply with only the revised code, nothing else.',
  },
  'code-review-register': {
    review: 'Review these draft code review comments.',
    edit: 'Edit this draft code review comment.',
    detect: 'Review this draft code review.',
    material: 'Draft',
    unit: 'comment',
    reply: 'Reply with only the revised comment, nothing else.',
  },
  'prose-register': {
    review: 'Review these versions of a prose passage.',
    edit: 'Edit this prose passage.',
    detect: 'Review this prose draft.',
    material: 'Text',
    unit: 'passage',
    reply: 'Reply with only the rewritten passage, nothing else.',
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

  if (item.type.startsWith('discrimination')) {
    const isRank = item.type === 'discrimination-rank';
    const pool = isRank ? item.stages : item.variants;
    const keys = Object.keys(pool);
    const letters = keys.map((_, index) => String.fromCharCode(65 + index));
    const letterToKey = Object.fromEntries(letters.map((letter, index) => [letter, keys[index]]));
    const listing = keys.map((key, index) => `${letters[index]}.\n${pool[key]}`).join('\n\n');
    const instruction = isRank
      ? 'Rank the versions from most to least on-register. Name the specific rule the worst version breaks.'
      : 'Pick one version. Name the specific rule that decides it.';
    const answer = isRank ? 'ANSWER: <letters, best first, comma-separated>' : 'ANSWER: <letter>';

    const prompt = `${frame.review} ${useSkill}

${item.prompt}

${listing}

${instruction}

Compare the versions in a few sentences first.

End with exactly these two lines and nothing after:
${answer}
RULE: <one sentence>`;

    return { prompt, letterToKey };
  }

  if (item.type === 'transformation') {
    return {
      prompt: `${frame.edit} ${useSkill}

${item.task}

${frame.material}:
${item.input}

${frame.reply}`,
    };
  }

  if (item.type === 'detection') {
    return {
      prompt: `${frame.detect} ${useSkill}

${item.prompt}

${frame.material}:
${item.input_document}

List each violation on one line:
- QUOTE: "<exact offending ${frame.unit} text>" | RULE: <rule in your own words>

Reply only with violation lines in that format. Do not explain or mention
${frame.unit}s that pass the register.`,
    };
  }

  throw new Error(`No subject prompt builder for case type "${item.type}"`);
}

export function buildTransformationRubric(item) {
  const criteria = Object.entries(item.rubric);
  return `Grade a rewrite against the rubric. Similar wording to the reference is not required.

Rule:
${item.rule_quote || ''}

Task given to the writer:
${item.task}

Original:
${item.input}

Reference-quality answer:
${item.reference_after}

The output passes ONLY if ALL ${criteria.length} criteria hold:
${criteria.map(([key, text], index) => `${index + 1}. ${key}: ${text}`).join('\n')}

Notes:
${item.grading_note || 'None.'}`;
}

// The judge sees only the reference rule and the alternatives the case lists;
// grading_note stays human-facing. Passed as free text, a note that asked for
// a precise two-rule answer was read as a requirement and failed the answers
// that met it.
export function buildRuleRubric(item) {
  const accepted = item.accepted_rules?.length
    ? item.accepted_rules.map((rule) => `- ${rule}`).join('\n')
    : 'None.';
  return `Grade only the line in the output that begins with "RULE:". Ignore which option was chosen and anything else in the output.

The RULE line passes if it names the same principle as the reference rule in any wording, names the part of a compound reference rule that decides this case, or names one of the accepted alternative rules. It fails if it names a different principle, is missing, or is too vague to tell this rule apart from the skill's other rules.

Reference rule:
${item.expected_rule ?? item.expected_rule_for_worst}

Rule text from the skill:
${item.rule_quote || 'None.'}

Accepted alternative rules (any one of these also passes):
${accepted}`;
}
