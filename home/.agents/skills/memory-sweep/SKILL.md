---
name: memory-sweep
description: Use when the per-project agent memory directories have accumulated facts that should outlive this machine — on a cadence, before a machine is retired, or when a memory file records something every future session should know. Routes each memory to the durable store it belongs to (shared rules, the harness layer, the project repo, the tracker), proves it landed, and retires the local copy.
argument-hint: "[project dir, or 'all']"
disable-model-invocation: true
---

# Memory Sweep

Agent memory under `~/.claude/projects/<cwd-slug>/memory/` is per machine, uncommitted, and dies with the machine. Facts pile up there because writing one is cheap in the moment and nothing ever moves them out. This skill is the move-out: read everything, decide where each fact belongs, write it there, prove it landed, delete the local copy.

The output is a few small PRs and a shorter memory directory, not a report about what could be done.

## The tiers

Every fact has exactly one durable home. The concrete paths for this machine live in the dotfiles repo's `CLAUDE.md`; the tiers are:

1. **Shared rules and skills** (the upstream dotfiles, public). Knowledge that holds in any repo on any machine: git, GitHub, the harness, tools, writing.
2. **This harness's own layer** (in the dotfiles, public). Knowledge about this machine, this harness, or the dotfiles repo itself: the host-specific rc file for box facts, `home/.claude` for harness config, the repo's `CLAUDE.md` for working on the repo.
3. **The project repo** (often private). Domain rulings, codebase conventions the code does not state, the project's environment on this box. Follow the repo's own convention (`.claude/memory/` with an index, `CLAUDE.md`, an ADR) and its file naming.
4. **The tracker.** In-flight status. A PR or issue is the durable record of what is open, what was deferred, and what must not be re-litigated.

Anything already encoded at its destination has a fifth home: the bin.

## The rubric

Ask in order. The first yes wins.

1. Would this hold in any repo on any machine? Tier 1.
2. Is it about this machine, this harness, or the dotfiles repo itself? Tier 2.
3. Is it project domain, a codebase convention, or the project's environment here? Tier 3.
4. Is it status: which PR is where, what a sweep did, what awaits review? Tier 4. Verify the tracker holds it, then delete.

A file often holds two facts, a generic lesson and the project instance that taught it. Split it: the lesson goes up a tier, the instance stays with the project, and neither copy names the other tier's nouns.

## Process

### 1. Inventory

List every memory directory, including the ones for worktrees, and read every file. The directory name encodes the working directory it belongs to; a note filed under the wrong project (about repo B, written while in repo A) relocates, it does not route.

### 2. Verify status before routing

For every PR, issue, branch, or workflow run a memory names, check the world: `gh pr view --json state,mergedAt`, `gh issue view`, `git branch -r`. A note about a merged PR is a deletion candidate whose durable lessons, if any, route on their own. Do this before classifying; most of the inventory usually lands here. A warning a memory made about two open PRs may have come true since it was written; check.

### 3. Classify and get approval

Produce the routing table (file, tier, destination file, action: move, split, delete, keep-local) and put it in front of the human before writing anything. Recommend, don't survey: which tier, which file, what gets deleted. Keep-local is legitimate only for in-flight notes whose PR is still open.

### 4. Write, per destination

- **Rules:** one bullet per lesson, bold lead, imperative, the *why* in a clause, no incident narrative. If the lesson only makes sense with the incident attached, it is a skill note or a project memory, not a rule.
- **Skills:** a bullet in the section that governs the behaviour, plus a red-flag line when the failure is silent.
- **Project memory:** the repo's file convention and index. Keep the incident, the dates, and the file paths; a private repo may name people and systems.
- **Tracker:** file the follow-ups the memory says were never filed, after searching for an existing issue (`gh issue list --state all --search`). One issue per concern.
- **Harness layer:** box facts in the host-specific rc file, harness config under `home/.claude`, repo mechanics in the repo `CLAUDE.md`. A tool bug gets an issue on the dotfiles repo, not a paragraph telling future sessions to work around it.

Public tiers get one PR per repo, reviewed by the human. Each PR is a series of commits, one per surface, so a reviewer can drop one bullet without losing the rest.

### 5. Scrub

Before pushing to a public tier, grep the whole diff and every commit message for the private projects' repo names, product names, domain nouns, issue numbers, hostnames, and people. The shared "Never name a private repo in a public one" rule is the policy; this is the gate:

```bash
git diff origin/main..HEAD | grep -niE '<repo>|<product>|<domain-noun>|<vendor>|<person>'
git log origin/main..HEAD --format=%B | grep -niE '<the same pattern>'
```

Fill the pattern from the projects the memories came from. Clean means both commands printed nothing.

### 6. Run each destination's gate

The dotfiles repo has its own (`make preflight`). A project repo's markdown may be format-checked in CI, so run its formatter check on the new files at their real path, and diff a `--write` pass before committing it.

### 7. Retire

Only after the destination is pushed: delete the migrated files, rewrite each `MEMORY.md` so it lists only what remains, and relocate mis-filed notes to their project's directory. What survives locally is in-flight status and nothing else.

### 8. Report

Lead with the table: file, tier, destination, PR link. Then what was deleted and why, what was kept local, and any finding the sweep surfaced (a stale warning that came true, a follow-up nobody filed).

## Red flags — stop

- Writing to a destination before the human saw the routing table.
- A rule bullet that names the project or retells the incident.
- Deleting a local file before its destination PR is pushed.
- A public PR body or commit message that mentions a private repo, even indirectly enough that a reader could identify it.
- A status note migrated instead of verified against the tracker and deleted.
- "Keep local" applied to anything but an open PR's in-flight note.

## Rationalizations

| Excuse | Reality |
|---|---|
| "It's project-specific, so it stays in memory" | The project has a committed memory convention. Local memory is where facts go to die. |
| "The PR body already says it" | PR bodies are not rules. If future sessions need it, it goes where they read. |
| "I'll file the issues later" | The memory said that too. File them now, cross-checked. |
| "This lesson needs the story to make sense" | Then it is a project memory, not a rule. Rules are imperative. |
| "One big PR is simpler" | One commit per surface lets the reviewer drop a bullet without blocking the rest. |
