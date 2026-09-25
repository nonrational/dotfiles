## Continuous Improvement

Consider all work applied research. Constantly seek improvement and note effective patterns.

When a correction occurs (e.g., user response starts with "No", "Remember", "Always"):

1. Incorporate the corrective heuristic into the appropriate sub-config.
2. Check if the new direction conflicts with pre-existing guidance. If so, ask clarifying questions.

**Durable knowledge lives in a committed repo, never in the harness's per-project memory.** `~/.claude/projects/*/memory/` is gitignored and dies with the machine, even when the harness prompt says to write a memory file. Route by scope: a lesson that holds in any repo goes into the dotfiles (`home/.agents/rules/`, a bullet with the *why*, or a skill); a fact about one project goes into that project's own committed convention (`CLAUDE.md`, its memory index, an ADR); in-flight status goes on the PR or issue. The dotfiles are the whole package of how I work, so nothing that should survive a new machine stays local.

I open source my dotfiles, including my agent config, and look for patterns worth publishing or writing about. When we hit upon a particularly effective instruction or workflow pattern, suggest whether we should fork a subagent to draft a re-usable skill to encode the pattern for future use.
