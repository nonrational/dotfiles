---
name: find-inspiration
description: Use when comparing this dotfiles repo against another repo, tool or framework to decide what ideas to borrow — e.g. "see what's worth stealing from owner/repo", "find inspiration in X", "should we adopt their setup". Also use to re-triage previously spotted improvement candidates.
---

# find-inspiration

Good artists borrow; great artists steal. `/find-inspiration` figures out which is which.

Study an **inspiration repo** and let the user triage what to adopt into the **current repo**.
Directional, semantic adaptation — never a git merge; the repos share no history. Two sizes of steal:

- **Leaf steal** — a bounded capability (a config, alias, tool swap, one missing feature). Low blast
  radius. Translate it into this repo's conventions.
- **Foundation steal** — a top-level framework or deploy/secrets/runtime strategy that may *replace*
  a convention rather than fit inside it. High blast radius. Size honestly; pilot, never big-bang.

The current strategy is the DEFAULT target for leaf steals but is **not sacred** (unchanged since
~2011). A foundation steal may replace part of it ONLY if it clears the outsized-benefit bar.
"Fits my existing setup" is the right filter for leaf steals and the WRONG filter for foundation ones.

## Destination context (this repo — shape is stable; verify specifics)

Trust the shape below. **Verify any claim you are going to put in an item — a line number, a
count, whether a target exists — against `origin/main`, not the working tree.** This repo usually
has a feature branch checked out, and an item built on unlanded work files an issue that describes
a state main has never been in.

- **Deploy:** `manifest` + `deploy.sh` — symlink-only, `apply` / `audit`, `--dry-run`. Three
  whitespace columns: source, target, optional condition (`os=Darwin|Linux`, `host=<name>`,
  `tool=<name>`). Adding copy/concat/generate is a parked decision, recorded in
  `docs/superpowers/specs/2026-07-06-manifest-deploy-spike-design.md`.
- **Layout:** sources under `home/`, targets mostly `~/.x` — but already mixed, not uniformly
  home-root: `home/.config/*` targets `~/.config/`, `fonts` targets `~/Library/Fonts/dotfiles`.
- **Shell:** bash-first (Homebrew bash via `chsh`); zsh files present but secondary. Per window:
  `.bash_profile` → `.bashrc` → `.bashrc.<platform>` → `.bashrc.<host>`.
- **OS/host branching:** `.Darwin`/`.Linux` filename suffixes, `bin.Darwin`/`bin.Linux` → `~/bin`,
  per-host `.bashrc.<hostname>`, plus the manifest's condition column.
- **Packages:** Homebrew `Brewfile` (brew, cask and mas lines in one file). **Runtimes:** asdf
  `.tool-versions` — check it for the current set; it pins several ecosystems, not just one.
- **Agent config:** `home/.agents` is the source of truth for rules and skills, shared across
  harnesses by symlink shims (`~/.claude/rules`, `~/.claude/skills`) and per-file mirrors
  (`home/.copilot/instructions/*.instructions.md`). Renames dangle these silently, so
  `make check-symlinks`, `check-skills`, `check-copilot-instructions` and `check-skill-frontmatter`
  guard them. Many skills are vendored via the `mattpocock-skills` submodule and are not editable here.
- **macOS defaults:** imperative `.macos` + `make macos-*`. **Vendored:** git submodules.
- **Tests:** `make test` = `test/test_deploy.sh` + `test/test_shell.sh`, both sandboxing a
  throwaway `$HOME`.
- **CI:** `.github/workflows/ci.yml` on ubuntu + macOS runs `make test`, a deploy apply/audit
  against a temp `$HOME`, and the check targets. No real installation is exercised — Homebrew,
  asdf and bootstrap are never run, so nothing proves a new machine comes up.

For a **leaf steal**, translate into the above: new config = a file under `home/` plus a `manifest`
row; OS-specific = suffix file, `bin.*`, or an `os=` condition; per-host = a `host=` condition;
packages = `Brewfile`; agent rules and skills = `home/.agents` plus the harness shims; bash-first.

## Phase 1 — Acquire the source (read-only)

Local path → use directly. URL → `rm -rf /tmp/find-inspiration-src && git clone --depth 1 <url>
/tmp/find-inspiration-src` (the rm clears leftovers from a crashed earlier run). State the path;
confirm the current dir is the destination. **Never write to the source**; delete any temp
clone at the end.

## Phase 2 — Profile the source

Its management approach (mise/asdf, nix, chezmoi, stow, dotbot, bare-git, bespoke) and domains it
covers: shell, prompt, terminal, editor, multiplexer, git, runtime mgmt, packages, secrets, bootstrap,
OS-conditional logic, deploy strategy, tests, AI-agent config.

## Phase 3 — Compare and produce the item list

**First, load prior decisions** so the same ideas aren't re-litigated every run:

```
<skill-dir>/bin/triage-issues.py --summarize-decisions
```

(`<skill-dir>` is the directory holding this SKILL.md — resolve it rather than assuming
`~/.claude/skills/...`, which depends on which checkout is deployed on this machine. Invoke the
script directly rather than via `python3 script.py`: its shebang pins the system interpreter, so it
does not depend on the asdf-pinned python in `.tool-versions` being installed here.)

This returns the latest decision per `id` (last decision wins). Use **stable, idea-scoped ids**
(`manifest-deploy`, `secrets`, `xdg`, `zsh-migration`, `mise-vs-asdf`) that name the *idea for this
repo*, not the source — so a decision persists no matter which source repo surfaces it next time.

Candidates spotted in earlier comparisons live as ready-made items in `runs/` (e.g.
`runs/2026-07-04-priors.json`). Merge any whose id is still undecided into the item list instead
of re-deriving them — and set the merged item's optional `source` field to the original run's
`source_repo` so the filed issue doesn't misattribute the idea to the current inspiration repo.

For each shared problem and each "they have, you don't": a structured item. Then **set aside** any
item whose id already has a decision: `reject` (decided against) or `adopt`/`spike` (already filed).
The menu in Phase 4 shows only undecided items.

Apply the discipline:
- **Difference that matters** = the real tradeoff (reproducibility, portability, speed, lock-in), not syntax.
- **Foundation items** additionally require: a *nameable* outsized benefit (if you can't name what it
  unlocks that no leaf steal can, the verdict is reject), honest migration cost, reversibility, and a
  pilot slice. "It already works" is a legitimate reason to reject; novelty is not benefit.

Emit the list as JSON to `/tmp/find-inspiration-run.json` using this schema (decision left empty
for now; `rationale` is filled in at triage time — required for rejects, optional otherwise):

```json
{
  "source_repo": "owner/name",
  "run_date": "YYYY-MM-DD",
  "items": [
    {
      "id": "manifest-deploy",
      "title": "Manifest + dry-run + audit deploy",
      "kind": "foundation",
      "problem": "...", "you": "...", "them": "...", "difference": "...",
      "effort": "M", "risk": "med",
      "translation": "how it maps into THIS repo's conventions",
      "pilot": "smallest reversible slice (foundation items only)",
      "spike_question": "the question a research spike must answer (spike items)",
      "decision": "",
      "rationale": ""
    }
  ]
}
```

## Phase 4 — Triage (interactive — STOP and wait)

Print a compact numbered menu grouped LEAF / FOUNDATION, each line: `#. [kind, effort/risk] title`.
Below it, show a one-line **Previously decided (hidden)** summary from Phase 3's read-back, e.g.
`rejected: xdg, zsh-migration • tracked: manifest-deploy, secrets`. Tell the user they can say
`reconsider <id>` to pull any hidden item back into the menu (its new decision overrides the old one,
since the log is last-write-wins).

Ask the user to assign every visible item to exactly one bucket, accepting shorthand, e.g.:

```
adopt 1,3,4   spike 2,6   reject 5,7,8
```

Rules: unmentioned items are left untriaged (re-surfaced next run, no issue, no log entry). For each
**reject**, capture a one-line `rationale` (ask if not given — it's what stops the idea being
re-litigated later). For each **spike**, auto-draft `spike_question` from the difference/pilot and
let the user override. Write the chosen `decision` (and any `rationale` / edited `spike_question`)
back into the JSON. Do not create anything yet.

## Phase 5 — File issues (adopt + spike only)

Run the helper **dry-run first**, show the user exactly what will be created/skipped, then for real:

```
<skill-dir>/bin/triage-issues.py --run /tmp/find-inspiration-run.json --dry-run
<skill-dir>/bin/triage-issues.py --run /tmp/find-inspiration-run.json
```

The script is idempotent (dedups on a stable `[find-inspiration:<id>]` title marker), ensures labels
exist, builds the issue body from the structured fields, and appends ALL decisions (including
rejects, with rationale) to `decisions.jsonl` beside this SKILL.md so future runs can pre-filter.
The log lives inside the skill dir on purpose — it travels with the skill and survives a fresh
clone, where a path outside it would not. `reject` items create no issue.

The script never mutates or closes existing issues. When a `reconsider` changes a decision, it
prints a WARN — relabel or close the old issue by hand before moving on.

## Phase 6 — Optional immediate pilot

If the user wants to start now, implement the smallest **adopt** item (or a foundation item's pilot
slice) on a WIP branch, translated into this repo's conventions, with a tight before/after and a
documented rollback. Otherwise stop — the issues are the durable handoff.

## Phase 7 — Wrap up

Summarize filed / piloted / rejected / untriaged. Commit the updated `decisions.jsonl` (and any
new `runs/` file) — the log is the skill's memory and must survive a fresh clone. Delete any temp
clone. Confirm the source was never modified.
