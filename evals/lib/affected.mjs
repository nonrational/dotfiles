// A change to the suite can move any score, so it selects every evaluated
// skill; otherwise a skill runs only when its own directory changed.
const SUITE_PATHS = ['evals/', '.github/workflows/evals.yml'];

export function affectedSkills(changedPaths, evaluatedSkills) {
  if (changedPaths.some((file) => SUITE_PATHS.some((prefix) => file.startsWith(prefix)))) {
    return [...evaluatedSkills];
  }
  return evaluatedSkills.filter((skill) =>
    changedPaths.some((file) => file.startsWith(`home/.agents/skills/${skill}/`)),
  );
}
