# `.agents` as the source of truth for agent config

**Date:** 2026-07-16\
**Status:** shape approved; revised after adversarial review — awaiting re-review\
**Supersedes:** the option 1 / option 2 framing in the prior session's handoff, and its
claim that this work needs no migration

## Problem

`home/.claude/` is the de-facto source of truth for agent config shared across three
vendors. Copilot and Gemini already symlink into it:

| link | target |
|---|---|
| `home/.copilot/instructions/*.instructions.md` (×7) | `../../.claude/rules/*.md` |
| `home/.gemini/antigravity-cli/rules` | `../../.claude/rules` |
| `home/.gemini/antigravity-cli/skills` | `../../.claude/skills` |

The pattern is already built; the root is just named after one vendor. Rename the root
to something neutral so no vendor is privileged by the layout.

## Scope

Three directories move to `home/.agents/`: `rules/`, `skills/`, `ext/`.

`ext/` is in scope for a mechanical reason, not a conceptual one. The 18 skill symlinks
resolve `skills/<name>` → `../ext/mattpocock-skills/skills/<cat>/<name>`. Moving `skills/`
and `ext/` together preserves that relative depth exactly, so all 18 need zero edits.
Leaving `ext/` behind would force them all to `../../.claude/ext/...`, which re-privileges
`.claude` and defeats the rename.

Out of scope: `agents/`, `commands/`, `hooks/`, `output-styles/`, `plugins/`,
`settings.json`, `CLAUDE.md`. These are Claude-specific formats with no other consumer
today. Moving them is speculative (YAGNI).

## Rejected: deploying subdirectories via the manifest

The handoff proposed a second option where `manifest` grows entries mapping
`.agents/rules` → `~/.claude/rules` directly, and called it "cleaner but more invasive."
It is not viable, and the reason was mis-costed.

`~/.claude` is a symlink into the repo, so roughly 840M of live runtime state
(`plugins/` 528M, `projects/` 299M, `history.jsonl`, `sessions/`) physically lives inside
`home/.claude/`, gitignored. For the manifest to deploy individual subdirectories into
`~/.claude`, that path would have to become a real directory, which means relocating all
840M of running state out of the repo first. That is exactly the stranded-runtime-state
problem that made the `home/` move hard and needed a 640-line migration script.

The handoff's stated reason for preferring the manifest option was that it would kill
`check-copilot-instructions`. That reason is also wrong; see below.

## Target layout

```
home/.agents/
  rules/            (7 .md files, moved)
  skills/           (18 symlinks + 5 real dirs + .keep, moved)
  ext/              (mattpocock-skills submodule, moved)

home/.claude/
  rules   -> ../.agents/rules      (new)
  skills  -> ../.agents/skills     (new)
  agents/ commands/ hooks/ output-styles/ plugins/
  settings.json  CLAUDE.md  .gitignore
```

Nothing deploys to `~/.agents`. `.agents/` is an in-repo canonical root; vendors reach it
through their own already-deployed directories. `manifest` and `deploy.sh` are untouched.

One consequence, which is not free: `test/test_deploy.sh:337` asserts the manifest covers
every `home/.*` that git does not consider *wholly* ignored. `home/.agents` is tracked, so
it gets no exemption and `make test` fails with
`manifest covers every link-dotfiles.sh-linked path (missing: .agents)`. "Manifest
untouched", "nothing deploys to `~/.agents`", and "`make test` passes" cannot all hold.

Resolution: add `.agents` to that test's exclude list. This is honest rather than a
workaround — the test mirrors the deploy script's find-and-exclude logic, and `.agents` is
genuinely not a deploy target. `manifest` and `deploy.sh` still go untouched; the edit
lands in `test/test_deploy.sh`, and the exclusion needs a comment saying why.

## Link accounting

27 agent-related symlinks today (the repo tracks 29 in total; the other 2 are
`home/bin.Darwin/{code,subl}` app links, untouched by this work). The distribution is the
design:

- **18 skill links: no edits.** Relative depth preserved by moving `ext/` alongside `skills/`.
- **7 Copilot links:** retarget `../../.claude/rules/x.md` → `../../.agents/rules/x.md`.
- **2 Gemini links, split by the liveness finding below:** the `skills` link is retargeted
  `../../.claude/skills` → `../../.agents/skills`; the `rules` link is **deleted**, not
  retargeted, because Antigravity never reads it.
- **2 new:** the `.claude/rules` and `.claude/skills` shims.

Net: 29 tracked symlinks − 1 deleted (`gemini …/rules`) + 2 shims = **30** after the move.

## Antigravity liveness: skills live, rules dead (verified)

The handoff asserted "Gemini follows those dir symlinks, has all along." Half true, and the
false half was silently costing coverage. Verified empirically against the installed
`agy` v1.1.3 with behavioral-suffix probes (a rule that forces an observable output token,
which is a valid detector — recall probes are not, because Antigravity injects rules as
constraints, not recallable facts):

- **`~/.gemini/antigravity-cli/skills` → LIVE.** `agy` enumerated exactly the
  `home/.claude/skills` contents (`code-review`, `tdd`, `research`, …), and no competing
  `~/.gemini/config/skills` exists, so the symlink is the sole source. Retarget it.
- **`~/.gemini/antigravity-cli/rules` → DEAD.** A behavioral rule planted there was
  ignored; the same rule placed in `~/.gemini/GEMINI.md` fired. Antigravity reads global
  rules only from `~/.gemini/GEMINI.md` (a single file), not a `rules/` directory. The
  symlink points out from a location nothing reads, so the 7 rules never reach Antigravity.
  Delete the link.

**Scope note — global vs project.** These findings are about *global* config, which is
what the dotfiles deploy. Antigravity separately supports a *project-local* `.agents/`
convention (`.agents/rules`, `.agents/skills`, MCP) read from a repo/workspace root,
defaulting to `.agents` with `.agent` as legacy fallback. That is a different mechanism and
does not resurrect the dead global link. It is also not something these dotfiles deploy —
project-local config lives per-repo. Worth noting only because it validates the `.agents`
name choice, and because the global skills link being live while the global rules link is
dead is a global-scope fact, not a contradiction of project-scope support. Caveat: the
project-*skills* half is corroborated by our own testing (`agy` enumerated them); the
project-*rules* half is not — a behavioral `.agents/rules` rule did not fire under
`agy -p`, which may be a print-mode limitation. Verify interactively before relying on it.

Consequence worth recording separately: the user's rules do not currently reach
Antigravity at all. Making them reach it is a `GEMINI.md` task (single-file, so it needs
concatenation or an import mechanism) and is **out of scope** for this migration.

### Parked decisions (do not relitigate)

- **Getting rules into Antigravity is parked.** The migration deletes the dead link and
  stops. Accepted that rules do not reach Antigravity; skills still do.
- **No native `GEMINI.md` import exists.** Tested against `agy` v1.1.3: both `@./file.md`
  and `@file.md` in `~/.gemini/GEMINI.md` were ignored (a behavioral-suffix rule in the
  imported file did not fire). So any future fix must materialize a single file.
- **Concat will not go into the manifest.** `deploy.sh` is symlink-only by design: a
  manifest line is `ln -s` and `audit` is `readlink target == source`. A concatenated
  `GEMINI.md` is a materialized copy that goes stale on any rule edit, forcing `audit` to
  re-concatenate-and-diff — a new verb that erodes the tool's simplicity and re-creates the
  mirror-policing problem this work reduces. If the fix is ever built, it belongs as a
  generated artifact plus a CI staleness check, mirroring `check-copilot-instructions`, not
  as a manifest directive.

## The checks must be retargeted, and both rot silently if they are not

Two Makefile targets keep passing after the move while no longer checking anything real.
Neither failure is loud. This is the most dangerous part of the change, because the
checks are also the evidence that the change worked.

### `check-skills` goes blind (severe)

`Makefile:43` iterates `git ls-files -z -- home/.claude/skills`. That returns 29 paths
today and exactly **1** once `skills/` is a shim symlink — the shim itself, which
resolves. Demonstrated by dangling a link post-move:

```
home/.agents/skills/tdd -> ../ext/.../THIS-DOES-NOT-EXIST   (dangling)
make check-skills   → all skill symlinks resolve            exit 0
make check-symlinks → [error] broken symlinks: .../tdd      exit 1
```

`check-symlinks` catches it but CI does not run it — `.github/workflows/ci.yml` runs
`make test`, `deploy.sh apply/audit`, `check-copilot-instructions`, and `check-skills`
only, and `Makefile:38-41` documents that exclusion as deliberate. So leaving this
unretargeted reintroduces exactly the regression commit `01b97bc` added the check to
prevent, and makes "`make check-skills` passes" vacuous as success evidence.

Action: retarget to `home/.agents/skills`.

### `check-copilot-instructions` survives, but self-heals in the wrong direction

The handoff assumed a neutral root would make this target structural and allow deleting
it. It does not. The target exists because the Copilot CLI requires per-file names with a
`.instructions.md` suffix, so 7 links must mirror 7 rule files under rewritten names. That
is a filename mismatch, not a rooting problem, and renaming the root does not touch it.

Worse, it passes unmodified post-move (realpath resolves through the shim), which makes it
easy to believe no edit is needed. But `Makefile:77` regenerates links as
`ln -s "../../$$rule"` with `$rule` sourced from `.claude/rules/*.md` (line 70), so it
silently rewrites a correctly-retargeted link back to `.claude`:

```
[fix] symlinking .copilot/instructions/workflow.instructions.md -> .claude/rules/workflow.md
readlink: ../../.claude/rules/workflow.md
```

Under CI (`$CI` set) that fails the build instead.

Action: retarget lines 70, 74, and 83 as well as the `ln -s` on 77, and correct the
comment. Do not delete it.

## `.gitignore`

`home/.claude/.gitignore` uses an allowlist (`*` then `!...` re-includes). Git treats a
symlink as a file, not a directory, so a trailing-slash rule will not re-include one.
Verified:

```
.gitignore:  *
             !rules/     # does NOT re-include a symlink named `rules`
             !skills     # does
```

Changes required in `home/.claude/.gitignore` (current line numbers):

- line 14: `!rules/` → `!rules`
- line 17: `!skills/` → `!skills` (a change, not an addition — the slashed form is already there)
- delete line 21 `!ext/`, line 43 `!ext/*`, line 47 `!skills/**` (dead once those paths move)

Ordering: this edit must precede `git add` of the shims. Without it, `git add` exits 1
with "paths are ignored by one of your .gitignore files". That failure is loud, so the
risk is low, but the sequence is fixed.

`home/.agents/` needs no `.gitignore`. The default-deny in `.claude/` exists only because
Claude Code writes runtime state there; nothing writes runtime state into `.agents/`.

## The submodule

`.gitmodules` keeps the name `.claude/ext/mattpocock-skills` while the path is
`home/.claude/ext/mattpocock-skills`. Git keys the object store by **name**
(`.git/modules/<name>`), not path, and the live checkout's `core.worktree` is a relative
`../../../../../home/.claude/ext/mattpocock-skills`.

Move it with `git mv home/.claude/ext/mattpocock-skills home/.agents/ext/mattpocock-skills`,
moving the submodule path itself rather than its parent `ext/` directory, so git 2.55
performs the `.gitmodules`, `.git`-file, and `core.worktree` fixups. Leave the submodule
*name* as-is: renaming it requires relocating `.git/modules/<name>` on every clone
(including `nyx`), and the name is already decoupled from the path by design.

Getting this wrong silently appears to work. The gitlink and `core.worktree` can agree
with each other while the submodule is broken, so `git rev-parse HEAD` passes. Only
`git submodule status` reveals the leading `-`.

### Every other clone breaks on pull. This is not free.

The handoff claimed `.agents` "needs no migration script" because it touches only tracked
files. That is false, and it is the single most important correction in this document.

`core.worktree` lives in `.git/modules/<name>/config`, which is **unversioned**. `git mv`
fixes it in the authoring repo and nowhere else. Simulating an existing clone pulling the
move:

```
warning: unable to rmdir 'home/.claude/ext/mattpocock-skills': Directory not empty
core.worktree AFTER checkout: ../../../../../home/.claude/ext/mattpocock-skills   ← not fixed
git submodule status:         -9603c1c... home/.agents/ext/mattpocock-skills      ← leading "-"
dangling skill links: 18
make check-skills: all skill symlinks resolve                                     ← won't catch it
```

Stale content also strands at `home/.claude/ext/`. Because `~/.claude ->
~/.dotfiles/home/.claude`, the live skills break on `git pull` until fixed by hand. This
hits every existing clone that pulls — on this machine (nyx) that is `~/.dotfiles` (the
deployed clone) and `~/src/wip-dotfiles` (the working copy). The spec's own submodule
warning was aimed at the authoring repo; the actual trap is the consuming clones, which
the handoff said needed nothing.

Fixup for each existing clone after pulling. Since `ext/` is only ~900K, discarding and
re-cloning the module beats `core.worktree` surgery:

```
rm -rf .git/modules/.claude/ext/mattpocock-skills home/.claude/ext
git submodule update --init --recursive
make check-skills          # must pass, and must be the retargeted version
```

The module *name* stays `.claude/ext/mattpocock-skills`, so that is the path under
`.git/modules` regardless of where the worktree moves. Note `~/src/wip-dotfiles` and
`~/.dotfiles` already differ today: the live checkout has `core.worktree` set, this one
has none at all.

**Verified during planning, not asserted.** A pre-move consumer clone (submodule
initialized, like `~/.dotfiles`) was made to pull the move: it reproduced the leading `-`,
the stale `core.worktree`, 18 dangling links, and stranded content — then the fixup above
recovered it to fully green (`git submodule status` clean, `core.worktree` repointed to
`.agents`, `make check-skills` and `check-symlinks` pass). It is a documented manual step,
not a script — but "no migration needed" is retired.

## Baseline hazard

`~/src/wip-dotfiles` had the submodule uninitialized, so all 18 skill symlinks dangled and
`make check-skills` failed before any edit. Resolved by `git submodule update --init
--recursive`; the check now reports `all skill symlinks resolve`. Re-establish this green
baseline before editing on any other machine, otherwise new breakage is indistinguishable
from pre-existing state.

## Resolved: Claude Code follows a symlinked `rules/`

This was the design's one load-bearing unknown, since a silent failure means the 7 global
rules stop loading with no error. It is now settled empirically.

The hazard was real at the OS level: `readdir(withFileTypes)` reports `isDirectory() ===
false` for a symlinked directory, so a naive enumerator would skip it. Verified with node:
`lstat().isDirectory()` is false, `stat().isDirectory()` is true, and `readdirSync()`
through the link succeeds.

Probe run on `nyx`, reproducing the production shape — a **real file** inside a
**symlinked directory**:

```
cd ~/.claude
echo 'The passphrase is: XYLOPHONE-7742' > rules/probe.md
mv rules rules.real && ln -s rules.real rules
claude -p "What is the passphrase? Reply with only the passphrase." --model haiku
→ XYLOPHONE-7742
```

The token is arbitrary by design. An earlier probe used a `gandalf.md` payload whose
passphrase was `friend`, which is guessable from the filename alone — and guessable in
precisely the failure direction under test, since a loader that enumerates entry names but
does not follow the link would put `gandalf.md` in context and let the model answer
`friend` from the filename. A true positive and that false positive are indistinguishable.
Unguessable tokens only.

The skills half needed no probe: Claude Code already loads the 18 symlinked
mattpocock skills today, which proves the same enumerator follows directory symlinks.

Consequence: the fallback (keeping `rules/` physically in `.claude/` and inverting the
shim) is not needed and is removed from this design.

## Known references left alone

The move does not require sweeping every mention of `.claude/rules` or `.claude/skills`.
These describe *runtime* paths under `~/.claude`, which stay valid via the shims:

- `home/.claude/skills/find-inspiration/SKILL.md:54,128,129,134` — `.claude/skills/find-inspiration/bin/triage-issues.py`
- `home/.claude/rules/skill-authoring.md:41` — `grep -rnE '^(source|forked-from): ...' .claude/skills/*/SKILL.md`

`scripts/migrate-to-home.sh:201,202,207,352,438,439,445,453,469` also hardcodes
`.claude/ext/mattpocock-skills` and `home/.claude/skills/*`. It is a historical one-shot
that migrates *from* the pre-`home/` layout, and it is **retained** for any host still on
that layout — it is deliberately left as-is by this change. `nyx` (this machine) is already
on `home/`; the handoff's belief that it wasn't came from misreading the `host=nyx`
manifest entry, which only customizes nyx's bashrc. How many hosts this repo is deployed to,
and their layout state, is not knowable from here — so no blanket "nothing needs migration"
claim is made. Two cases: a host already on `home/` (like nyx) needs only the submodule
fixup above after pulling; a host still on the pre-`home/` layout runs
`migrate-to-home.sh` first, then pulls `.agents` and applies the fixup. Because the script
predates `.agents`, such a host lands on `home/` with `.claude/{skills,ext}` and the
subsequent `.agents` pull completes the move; updating the script to be `.agents`-aware is
possible future work, not required here.

## Success criteria

- `make check-skills` (retargeted), `make check-symlinks`, `make check-copilot-instructions`, `make test` all pass
- `make check-skills` **fails** when a link under `home/.agents/skills` is deliberately dangled — proving it is not vacuous
- `check-copilot-instructions` run twice in a row is a no-op, and the 7 links still read `../../.agents/rules/*.md` afterward
- `git submodule status` shows no leading `-`, in both this repo and a simulated fresh clone that pulled the move
- `./deploy.sh audit` reports 25 ok, 0 drift, 0 missing
- `git ls-files -s | awk '$1=="120000"' | wc -l` reports **30** (29 existing − 1 deleted `gemini …/rules` + 2 new shims)
- `home/.gemini/antigravity-cli/rules` is gone; `home/.gemini/antigravity-cli/skills` resolves to `../../.agents/skills`
- no tracked path references `../../.claude/rules` or `../../.claude/skills` as a *symlink target*
  (documentation of runtime `~/.claude/...` paths is exempt; see above)
- a fresh Claude Code session loads all 7 rules from `home/.agents/rules/`
- `agy` still enumerates the skills (proving the retargeted skills link is live)
