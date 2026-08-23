# Pi as a supported harness

**Date:** 2026-08-21\
**Status:** proposed — awaiting review\
**Verified against:** pi 0.79.1 (the build installed at `~/.local/pi`, read directly rather than trusted from docs) and the current upstream README at `earendil-works/pi@main` (0.84.2)

## Problem

Pi (`pi.dev`, Earendil Inc., MIT) is a minimal terminal coding harness, and it is **already installed on the exe.dev VM** — `~/.local/bin/pi`, provisioned by the host along with an `exe-dev` extension. This repo doesn't know it exists. `manifest` deploys config for Claude Code, Copilot, and Gemini/Antigravity; pi gets nothing.

That matters because pi is the fourth consumer of the same agent config, and `home/.agents` was made the source of truth precisely so a new harness costs a shim, not a fork.

## What pi actually loads

Read out of the installed binary (`collectSkillEntries`, `loadProjectContextFiles`, `getAgentDir`), not paraphrased from marketing:

| Resource | Pi's discovery path |
| --- | --- |
| Global context file | `~/.pi/agent/AGENTS.md`, else `AGENTS.MD` / `CLAUDE.md` / `CLAUDE.MD` — **exactly one file**, first match wins |
| Ancestor context files | `AGENTS.md`/`CLAUDE.md` in every directory from `cwd` up to `/` |
| Skills (global) | `~/.pi/agent/skills/` **and `~/.agents/skills/`** |
| Skills (project, trust-gated) | `.pi/skills/`, and `.agents/skills/` in `cwd` and ancestors up to the git root |
| Prompt templates | `~/.pi/agent/prompts/*.md` (the `/name` slash-command analogue) |
| Settings | `~/.pi/agent/settings.json`, overridden by `.pi/settings.json` |
| System prompt | `~/.pi/agent/SYSTEM.md` replaces it; `APPEND_SYSTEM.md` appends to it |
| Runtime state | `~/.pi/agent/` — `sessions/`, `trust.json`, `auth.json`, `npm/`, `git/`, `bin/`, `extensions/` |

The agent dir is `~/.pi/agent` (`$PI_CODING_AGENT_DIR` overrides), and it is *not* XDG-aware.

## Skills already work, for free

`~/.agents/skills/` is a first-class pi discovery path, scanned in "agents" mode: directories containing `SKILL.md` are found recursively, root-level `.md` files are ignored, and **symlinked directories are followed** (pi `statSync`s any entry that is a symlink rather than skipping it). So the ~29 entries in `home/.agents/skills/` — most of them symlinks into the `mattpocock-skills` submodule — are visible to pi today, with no shim, no settings entry, and no trust prompt.

This is the `.agents`-as-source-of-truth bet paying off unprompted: pi's author chose `~/.agents/skills` as a cross-harness convention independently, and the 2026-07-16 rename landed us on it by accident. Worth recording as evidence the decision was right.

Verified live, not just read: a `gpt-5-nano` run against a sandboxed agent dir listed 13 skills by name from `~/.agents/skills`. The other 14 entries there carry `disable-model-invocation: true` and are correctly withheld from the system prompt — same as in Claude Code — and stay reachable as `/skill:name`.

Three caveats that are ours to remember, not to fix:

- `--no-tools` suppresses the skills block entirely (skills are useless without `read`). Expect no skills in a `--no-tools` run; that is not a discovery failure.
- Pi applies `.gitignore`-style ignore rules found inside a skills tree. `home/.agents/skills/.gitignore` currently excludes `*/results/`, which is only eval transcripts — harmless. A broader pattern added there in future would silently hide skills from pi.
- Name collisions across skill locations warn and keep the first found. Nothing collides today.

## The gap: rules

`home/.agents/rules/*.md` reach Claude through `@rules/…` imports in `~/.claude/CLAUDE.md` and Copilot through eight per-file symlinks in `home/.copilot/instructions/`. Neither mechanism exists in pi: it reads **one** global context file and supports no imports and no rules directory. So today a pi session on this machine runs with the skills but none of the working style, communication register, git hygiene, or model-selection guidance.

### Design

Concatenate the rules into a generated `home/.pi/agent/AGENTS.md`, symlinked to `~/.pi/agent/AGENTS.md`, and guard the generation the same way the Copilot mirror is guarded.

- `scripts/build-pi-agents.sh` renders a short header plus every `home/.agents/rules/*.md` verbatim, each preceded by an HTML comment naming its source file. Deterministic order (`LC_ALL=C sort`), idempotent output.
- `make check-pi-agents` rewrites the file locally and prints "please commit"; under `CI` it fails instead. Identical contract to `check-copilot-instructions`, chosen deliberately: the failure mode is identical too (rename a rule, and guidance stops reaching a harness with no visible symptom).
- One manifest entry, conditioned `tool=pi` so machines without pi skip it:
  `home/.pi/agent/AGENTS.md ~/.pi/agent/AGENTS.md tool=pi`
- `home/.pi/.gitignore` is a default-deny allowlist, matching `home/.claude/.gitignore`.

`test_manifest_covers_link_dotfiles` had to learn about `.pi`: it asserts every top-level entry under `home/` appears as a manifest source, and `home/.pi` deliberately isn't one. It now requires at least one entry *underneath* `home/.pi/` instead, so the guard still catches an un-deployed addition there.

Verified end-to-end: a `gpt-5-nano` run with this file at `~/.pi/agent/AGENTS.md` quoted the first sentence under `## Continuous Improvement` verbatim and named `home/.agents/rules/improvement.md` as its source — so both the load path and the per-file provenance comments do what they claim.

Cost: ~18KB of derived Markdown committed to the repo. Accepted because CI makes drift impossible and the alternative (below) breaks `deploy.sh` for anyone who doesn't run `make` first.

## Rejected

**Symlink `home/.pi` → `~/.pi` wholesale**, the way `.claude`/`.copilot`/`.gemini` are deployed. `deploy.sh` would move the host's live `~/.pi` to `~/.pi.bak` and replace it with a repo symlink, destroying the exe.dev-provisioned `extensions/exe-dev` and `bin/fd`. It would also pull pi's runtime state inside a public repo: `sessions/` holds full transcripts, `trust.json` accumulates private workspace paths (exactly the Antigravity `trustedWorkspaces` problem that needed skip-worktree), and `auth.json` holds provider credentials. Per-file linking is the only safe shape here. This is why `.pi` is the first partially-linked root in the manifest.

**Generate `AGENTS.md` at deploy time and gitignore it.** Avoids committing a derived artifact, but `./deploy.sh apply` on a fresh clone would hard-fail on a missing source, and deploy.sh staying symlink-only is a parked decision from 2026-07-06. Not worth reopening for 18KB.

**A pointer file** — an `AGENTS.md` that instructs the agent to go read `~/.agents/rules/*.md`. Cheapest and zero duplication, but it makes always-on rules conditional on the model choosing to read them. Rules that load only sometimes are worse than rules that cost 4k tokens.

**`APPEND_SYSTEM.md` instead of `AGENTS.md`.** Higher precedence (system prompt rather than context), but `AGENTS.md` is the portable, inspectable convention and can be disabled per-run with `-nc`. `APPEND_SYSTEM.md` is reserved for the machine-private layer below.

**Mirror `home/.claude/commands/` → `~/.pi/agent/prompts/`.** The formats look compatible (frontmatter `description` + `argument-hint`), but Claude commands use `$ARGUMENTS` substitution and `allowed-tools` naming Claude-only tools; pi appends arguments as a trailing `User: <args>` line and has no such tools. `then.md` would silently misbehave. Revisit only if a command is written portably.

**Ship a `home/.pi/agent/settings.json`.** Every setting worth putting there today — theme, default model, thinking level, telemetry — is a preference, not a fix. Nothing speculative.

**A `~/AGENTS.md` at the home directory root.** Pi walks ancestors from `cwd` to `/`, so this would reach pi *and* any other ancestor-walking harness. Too broad and too surprising: it applies to every repo on the machine, including ones with their own `AGENTS.md`.

## Machine-private context

`AGENTS.md` here is public, so `identity.md` and `exe.md` — which live untracked beside the Claude config — must not be folded into it. Pi's `~/.pi/agent/APPEND_SYSTEM.md` is the right home for them: appended to the system prompt, per-machine, never tracked by this repo. Setting it up is a manual per-machine step, deliberately not automated by the manifest.

## Not ours to fix: the host's misplaced context file

exe.dev provisions `~/.pi/AGENTS.md` — a root-owned symlink to the host's own VM/proxy briefing. Pi's agent dir is `~/.pi/agent`, so that path is never read — the host's own guidance has not been reaching pi sessions. Reported here for the record; the file belongs to the host image, and our `~/.pi/agent/AGENTS.md` does not collide with it.

## Follow-ups

- Installed pi is 0.79.1 (Jun 9); current is 0.84.2. `pi update` self-updates. Newer builds add `AGENTS.override.md`, which doesn't change anything above.
- Pi ships no subagent or todo tool. The Superpowers `references/pi-tools.md` mapping already covers this (`pi-subagents` package if wanted); no repo change needed.
- If prompt templates become worth sharing, the portable move is a neutral `home/.agents/prompts/` with harness-specific shims — not a symlink from one vendor's directory to another's.
