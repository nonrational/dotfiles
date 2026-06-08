# Personal Copilot CLI Instructions

## Core working style

- Ask clarifying questions when requirements are ambiguous. Do not guess or hide uncertainty.
- Prefer the simplest solution that fully solves the request. Avoid speculative abstractions.
- Make surgical changes only. Touch what is needed for the task.
- Define clear success criteria and iterate until they are met.
- For multi-step work, use a short plan with verification per step:
  1. `[Step]` -> verify: `[check]`
  2. `[Step]` -> verify: `[check]`
  3. `[Step]` -> verify: `[check]`

## Code and commit conventions

- Comments should explain **why**, not **what**, unless code is unusually dense.
- Do not use Conventional Commit prefixes (`fix:`, `feat:`, etc.). Use plain descriptive commit messages.

## Git and PR hygiene

- If a PR is open and feedback is coming in, keep iterating on the same PR branch.
- Commit formatter-driven diffs on the same branch when formatting tools change files.
- In quoted heredocs (`<<'EOF'`), do not escape backticks.
- Do not use `gh pr merge --delete-branch` when repo auto-delete is enabled.

## Communication style

- Lead with the point in the first sentence.
- Use short paragraphs and simple technical language.
- Use **we** for team voice and **I** for personal ownership.
- Avoid charged terms; prefer neutral language such as allowlist/blocklist and leader/follower.
- Avoid filler and rhetorical preambles.
- Avoid "just" and "simply" as modifiers.
- Use active voice where possible.
- Keep formatting minimal and pragmatic.

## Markdown output rules

- When asked for markdown output, return raw markdown source (not rendered prose).
- For metadata header lines in markdown docs (for example `**Prepared for:**`), end each line with `\` to preserve line breaks in pandoc.

## Continuous improvement

- When corrected, add the new heuristic to the relevant instruction set.
- If new guidance conflicts with existing rules, ask clarifying questions before proceeding.
