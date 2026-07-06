# Manifest-Driven Deploy Spike — Design

**Issue:** https://github.com/nonrational/dotfiles/issues/6 \
**Date:** 2026-07-06 \
**Kind:** spike (working pilot — keep the branch if the answer is "yes")

## Spike question

Can a manifest + small bash driver reach parity with `link-dotfiles.sh` for
`bin.*` and one per-host file — with `--dry-run`, backup-on-conflict and an
audit mode — without adopting an external engine?

## Current state

- `link-dotfiles.sh` links every root dotfile by convention (`find . -maxdepth 1 -name '.*'`
  with exclusions), plus a special case: `bin.$(uname)` → `~/bin`.
- OS/host variance is linked unconditionally (`.bashrc.Darwin`, `.bashrc.Linux`,
  `.bashrc.nyx`) and resolved at runtime by `.bashrc` via `source_if_exists`
  on `$platform` and `$host` (short hostname, `.lan`/`.local` stripped).
- Conflict handling is interactive: diff, then a backup/merge/overwrite/skip/quit menu.
- No way to preview what a run will do, and no drift report.

## Deliverables

1. `manifest` — declarative source→target mappings with per-entry conditions,
   covering only the pilot slice: `bin.Darwin`, `bin.Linux`, `.bashrc.nyx`.
2. `deploy.sh` — small bash driver with `apply` (default), `--dry-run` and `audit`.
3. Findings comment on issue #6 answering the spike question.

`link-dotfiles.sh` keeps handling everything not in the manifest, including its
`bin.$(uname)` special case, until a post-spike decision removes it. A new
machine runs `link-dotfiles.sh` first, then `deploy.sh`.

## Manifest format

`manifest` at repo root. One entry per line, three whitespace-separated columns;
`#` starts a comment; blank lines ignored.

```
# source        target              condition
bin.Darwin      ~/bin               os=Darwin
bin.Linux       ~/bin               os=Linux
.bashrc.nyx     ~/.bashrc.nyx       host=nyx
```

- **source** — path relative to the repo root.
- **target** — absolute path; a leading `~/` expands to `$HOME`. Neither sources
  nor targets may contain whitespace (acceptable for this repo; revisit post-spike
  if ever needed).
- **condition** — optional third column. `os=<uname>` or `host=<short hostname>`,
  using the same hostname normalization as `.bashrc` (`uname -n` with `.lan`/`.local`
  stripped). Empty means unconditional.

An entry whose condition does not match is **skipped, never removed**. The driver
manages only matching entries; e.g. `.bashrc.nyx` already linked on a non-nyx
machine is untouched.

## Driver behavior

`deploy.sh [--dry-run] [apply|audit]` — bash + coreutils only, no external engine.
Target size: ~100 lines.

### apply

For each matching entry, compare target state to desired link and act:

| Target state | Action |
|---|---|
| symlink to expected source | no-op |
| missing | `mkdir -p` parent, create symlink |
| symlink elsewhere | replace symlink |
| regular file or directory | **backup** (`mv target target.bak`), then symlink |

Backup is non-interactive by design — this replaces `link-dotfiles.sh`'s
interactive menu for manifest-managed entries. If `target.bak` already exists,
the entry is skipped with an error (never overwrite a previous backup) and the
run exits non-zero.

`--dry-run` prints the same decisions prefixed `would:` and touches nothing.
It only modifies `apply`; `audit` is always read-only, and `--dry-run audit`
behaves identically to `audit`.

### audit

Per matching entry, print one line: `ok` (symlink to expected source),
`missing` (target absent), or `drift` (target exists but is not the expected
symlink). Non-matching entries print `skip`. Exit non-zero if anything is
`missing` or `drift`.

## Error handling

- Malformed manifest line (fewer than 2 columns, unknown condition key):
  report line number, exit non-zero, act on nothing (validate fully before acting).
- Missing source file: report and exit non-zero before acting, same as above.
- `set -euf -o pipefail` like the existing script.

## Verification (parity answer)

1. On this converged machine (nyx, Darwin — both conditions match positively):
   `deploy.sh --dry-run apply` proposes zero changes, matching `link-dotfiles.sh`.
2. `deploy.sh audit` exits 0 on the converged machine.
3. Fault injection against a temp `$HOME` (driver honors `$HOME` so tests can
   redirect it): missing target → created; wrong symlink → relinked; regular
   file → backed up then linked; pre-existing `.bak` → skip + non-zero exit.
4. `--dry-run` provably changes nothing: checksum the temp tree before/after.
5. Post findings — parity verdict plus anything that didn't translate — to issue #6.

## Out of scope

- Migrating anything beyond the pilot slice.
- Removing the `bin.$(uname)` special case from `link-dotfiles.sh`.
- Interactive diff/merge for manifest entries.
- Timestamped/rotating backups, `os+host` compound conditions, targets with
  whitespace — revisit only if the spike answer is "yes".
