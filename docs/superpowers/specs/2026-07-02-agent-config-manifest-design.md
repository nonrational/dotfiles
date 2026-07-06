# Agent config manifest — design

## Problem

`~/.claude` and `~/.copilot` are each a single whole-directory symlink into this
repo (`~/.claude` → `~/.dotfiles/.claude`, `~/.copilot` → `~/.dotfiles/.copilot`).
Whole-directory symlinking means the repo directory *is* the global config
directory — there is no way for anything inside `.dotfiles/.claude/` to be
"just for this repo," because it's the same physical directory Claude Code
reads as global user config everywhere else on the machine.

Concretely, this causes two distinct problems:

- **Claude Code:** project-scoped config (`<cwd>/CLAUDE.md`,
  `<cwd>/.claude/{rules,commands,agents,skills}/...`) is discovered purely by
  path, independent of `~/.claude`, with no special-casing for the home
  directory. So `~/.dotfiles` *could* have its own project-scoped
  `CLAUDE.md` and `.claude/commands/*.md` that only apply when working in
  this repo — except the whole-dir symlink means anything dropped there is
  simultaneously global, defeating the point.
- **Copilot CLI:** project scope comes from a completely different
  mechanism — `<repo>/AGENTS.md` and `<repo>/.github/instructions/**/*.instructions.md`
  — never `.copilot/`. So the whole-dir symlink doesn't block project
  scoping for Copilot the way it does for Claude. What it does do is put all
  of Copilot's gitignored runtime state (`session-store.db`, `logs/`,
  `session-state/`, `command-history-state.json`) physically inside the git
  working tree, just untracked. That's a smaller but real problem: repo
  bloat and one less layer of defense against ever committing something
  sensitive from that directory.

## Goals

1. Give this repo its own project-scoped Claude Code directives
   (`CLAUDE.md`, and later `.claude/commands|agents|skills/*` if wanted),
   distinct from what's deployed globally to `~/.claude`.
2. Stop Copilot's runtime state from living inside the git working tree.
3. Borrow [obra/dotfiles](https://github.com/obra/dotfiles)'s manifest
   pattern (used with the `homedir-manager` engine) to do this: an explicit,
   allowlisted, per-file manifest instead of whole-directory symlinks.
4. Make the mechanism generalize to additional agent tools (e.g. `.gemini`,
   antigravity) later without a redesign — but don't build support for tools
   that aren't installed on this machine yet.

## Non-goals

- Replacing `link-dotfiles.sh` for anything other than `.claude` and
  `.copilot`. The rest of what it manages (`.vimrc`, `.tmux.conf`,
  `bin.Darwin`/`bin.Linux`, etc.) doesn't have the whole-directory-symlink
  problem this design solves, so there's no forcing function to migrate it.
- Replacing `.bashrc.Darwin`/`.bashrc.Linux` or `bin.Darwin`/`bin.Linux`.
  Those solve a different problem — runtime conditional sourcing and
  deploy-time OS directory selection — than the manifest's per-file
  allowlist. obra's `macos`/`linux` manifest tags are a similar-looking but
  distinct mechanism (skip a whole file on the wrong OS); nothing here
  requires collapsing the two.
- Pre-populating manifest entries for tools not present on this machine
  (`.gemini`, antigravity). Add their entries when adopted.

## Design

### Manifest format

One repo-root file, `manifest`, syntax matching obra's:

```
# comments and blank lines ignored
<repo-relative-path>              [macos|linux]
merge-children <repo-relative-dir>
```

- A bare path deploys that one file or directory as a single symlink.
- An optional trailing `macos`/`linux` tag skips the line when `uname`
  doesn't match.
- `merge-children <dir>` deploys every immediate child of `<dir>` as its own
  symlink (so `$HOME/<dir>` becomes a real directory containing individually
  linked children, not one symlink for the whole thing). Available in the
  parser; unused in this pass — see "Explicit over merge-children" below.

The manifest holds entries for `.claude/...` and `.copilot/...`. Both tool
sections live in the same file — this is what obra's own manifest does
(mixing `.claude/...` and `.codex/...` entries together) and is what makes
adding a third tool later just an append, not a new file or a new script.

### Explicit entries, not `merge-children`, for anything that could hold repo-local content

`.claude/rules/`, `.claude/commands/`, `.claude/agents/`, `.claude/skills/`,
and `.copilot/instructions/` each get every *current* file/directory listed
individually in the manifest, rather than one `merge-children` line. This
mirrors obra's own choice for `.claude/skills` — his comment: doing it this
way means content that shouldn't be global is "left untouched." Concretely:
a new file dropped into `.dotfiles/.claude/commands/` stays project-local
(picked up only when Claude Code's cwd is inside `~/.dotfiles`) until someone
deliberately adds a manifest line for it. That deliberate step is the whole
point — default-local, opt-in-to-global.

Full manifest content:

```
# Claude
.claude/CLAUDE.md
.claude/settings.json
.claude/rules/language.md
.claude/rules/workflow.md
.claude/rules/markdown.md
.claude/rules/macos_interactions.md
.claude/rules/improvement.md
.claude/rules/code-review-register.md
.claude/commands/par.md
.claude/ext/mattpocock-skills
.claude/sync-plugins.sh
.claude/skills/beautiful-prose
.claude/skills/caveman
.claude/skills/diagnose
.claude/skills/grill-me
.claude/skills/grill-with-docs
.claude/skills/handoff
.claude/skills/improve-codebase-architecture
.claude/skills/prototype
.claude/skills/scaffold-exercises
.claude/skills/setup-matt-pocock-skills
.claude/skills/setup-pre-commit
.claude/skills/tdd
.claude/skills/teach
.claude/skills/to-issues
.claude/skills/to-prd
.claude/skills/triage
.claude/skills/write-a-skill
.claude/skills/zoom-out

# Copilot
.copilot/settings.json
.copilot/instructions/improvement.instructions.md
.copilot/instructions/language.instructions.md
.copilot/instructions/macos_interactions.instructions.md
.copilot/instructions/markdown.instructions.md
.copilot/instructions/workflow.instructions.md
```

`.keep`-only directories (`.claude/agents`, `.claude/commands` itself,
`.claude/hooks`, `.claude/output-styles`, `.claude/plugins`,
`.claude/plugins/marketplaces`, `.claude/skills` itself) are git bookkeeping,
not deploy targets — they stay out of the manifest. `mkdir -p` on the
destination side creates any needed parent directory as entries are linked.

### Deploy script: `scripts/deploy-manifest.sh`

Bash, matching `link-dotfiles.sh`'s existing style (`set -euf -o pipefail`).
Behavior per manifest line:

- Parse the optional platform tag; skip the line if it doesn't match
  `uname`.
- `merge-children <dir>`: iterate `<dir>`'s immediate children, treat each as
  its own entry (recurse into the same per-entry logic below).
- Per entry: symlink `$HOME/<rel>` → `$DOTS/<rel>`.
  - If the target is already the correct symlink, skip (idempotent re-run).
  - If the target exists as something else (real file/dir), back it up to
    `~/.dotfiles-backup/<timestamp>/<rel>`, then create the symlink.
  - `--dry-run` reports what would happen without changing anything.

**One-time transition, handled automatically inside the script:** before
deploying any entry under a top-level root (`.claude`, `.copilot`), check
whether `$HOME/<root>` is still the *old* whole-directory symlink pointing
into this repo. If so, remove it and create a real directory in its place.
A symlink holds no content of its own — the real content is safely the repo
— so this needs no backup, just removal. This is the same hazard obra's
`deploy.sh` guards against for `merge-children` targets, generalized here to
the top-level tool roots. After the first run, `$HOME/<root>` is already a
real directory and the check is a no-op.

### `link-dotfiles.sh`

Add `.claude` and `.copilot` to the existing `! -name` exclusion list in the
top-level dotfile glob, so they're no longer whole-dir-symlinked by the old
path. They become exclusively manifest-owned.

### New project-scoped root files (never in the manifest)

- **`~/.dotfiles/CLAUDE.md`** — real project memory for Claude Code,
  loaded automatically when cwd is inside this repo (Claude Code walks the
  directory tree from cwd upward looking for `CLAUDE.md`, independent of and
  additional to the global `~/.claude/CLAUDE.md`). Content: what this repo
  is, manifest vs. `link-dotfiles.sh` (which owns what), how to add a new
  dotfile, how to add a new manifest entry.
- **`~/.dotfiles/AGENTS.md`** — Copilot CLI's project-instructions file,
  and also the cross-tool standard (`AGENTS.md`) other agents are
  converging on. `~/.dotfiles/CLAUDE.md` will just be `@AGENTS.md` (Claude
  Code supports file imports), so there's one source of truth instead of
  two documents to keep in sync.

Because neither file is manifest-listed, neither is symlinked anywhere —
they exist solely at the repo root and are picked up only by virtue of
someone's cwd being inside `~/.dotfiles`. This is the concrete mechanism
that satisfies goal 1.

### `Makefile` / `README.md`

- New `link-manifest` target: `./scripts/deploy-manifest.sh`.
- `README.md` installation steps gain `make link-manifest` alongside the
  existing `make link-dotfiles`.

## Testing / verification

1. `./scripts/deploy-manifest.sh --dry-run` before any real run — confirm
   the planned actions match the manifest (in particular the "replace stale
   whole-dir symlink" step for `.claude` and `.copilot`).
2. Run for real. Confirm:
   - `~/.claude` and `~/.copilot` are now real directories, not symlinks.
   - Every manifest-listed path resolves through a symlink to the
     corresponding repo file.
   - Nothing not in the manifest exists under `~/.claude`/`~/.copilot`
     that wasn't already there from another source (e.g. this doesn't
     delete unrelated host-local content — only manages what it created).
3. Re-run the script — confirm it's a no-op (idempotent) with no spurious
   backups.
4. Start Claude Code with cwd outside `~/.dotfiles` — confirm the new root
   `CLAUDE.md`/`AGENTS.md` content is *not* loaded (global-only content
   still is).
5. Start Claude Code with cwd inside `~/.dotfiles` — confirm the new project
   memory *is* loaded, in addition to global content.
6. `git status` in the dotfiles repo after normal Copilot CLI use — confirm
   no new untracked runtime files appear inside `.dotfiles/.copilot/`
   (because `~/.copilot` is no longer the same directory).
