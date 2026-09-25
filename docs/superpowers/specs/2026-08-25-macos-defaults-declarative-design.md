# Declarative macOS Defaults — Design

**Issue:** https://github.com/nonrational/dotfiles/issues/8 \
**Date:** 2026-08-25 \
**Revised:** 2026-09-24, folding the table back into `.macos` (see [The source](#the-source)) \
**Kind:** architectural

## Problem

`.macos` is a one-way imperative script. It writes 218 `defaults write` lines and keeps no record of desired state, so nothing detects when macOS or an application rewrites a setting after an OS update, a manual change in System Settings, or an app's own housekeeping.

A read-only probe of all 218 lines against this machine (macOS 26) found four settings already untrue. The probe compared values only; the finished tool also compares storage types, which later surfaced two more:

| Row | `.macos` declares | Live |
|---|---|---|
| `NSGlobalDomain AppleLocale` | `en_US@currency=USD` | `en_US@currency=usd` |
| `com.apple.ActivityMonitor ShowCategory` | `0` | `100` |
| `com.apple.ActivityMonitor OpenMainWindow` | `true` | `0` |
| `.GlobalPreferences com.apple.mouse.scaling` | `-1` | `3` |
| `com.apple.AppleMultitouchTrackpad FirstClickThreshold` | `int 1` | `bool 1` |
| `com.apple.AppleMultitouchTrackpad SecondClickThreshold` | `int 1` | `bool 1` |

The last one matters: `.macos` disables mouse acceleration and the machine has it on. Nothing would ever have reported that.

## Goal

**Drift detection is the primary job.** A `make macos-audit` that tells you what your machine changed out from under you, and that you trust enough to act on. Apply and accept exist to resolve what audit reports, not as ends in themselves.

Success looks like: an audit that exits zero on a converged machine, reports genuine drift when it happens, and never cries wolf. An audit you learn to ignore has failed.

## Probe findings

Every `defaults write` in `.macos`, parsed with a shell shim and compared against live values. Read-only.

| Bucket | Count | Meaning |
|---|---|---|
| Auditable, matches live | 152 | The healthy core |
| Genuine drift | 6 | The four above, plus two trackpad keys the pane restored as booleans |
| TCC-blocked | 39 | Safari 34, Mail 5 |
| Actually unset | 9 | Key absent from a domain that reads fine |
| Genuinely complex | 12 | `array` / `dict` / `dict-add` / `date` |

Four of the complex rows (`com.apple.mail NSUserKeyEquivalents`, `DraftsViewerAttributes` ×3) are blocked by TCC *and* by their container types. They are marked `noaudit=complex`, because that is the binding constraint: granting Full Disk Access would still leave them uncomparable.

### TCC is a hard constraint

`~/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.plist` exists and is written regularly, but `ls` on that directory returns `Operation not permitted` and `defaults read com.apple.Safari` reports the domain does not exist. That is TCC, not a missing key. Those 39 rows cannot be audited from a shell without granting Full Disk Access to the terminal, and CI can never have it.

The test that separates the two cases is whether the *domain* reads, not whether the key does: `defaults read com.apple.Safari` fails, while `defaults read com.apple.GameCenter` succeeds and only the key is absent. `com.apple.TextEdit` and `com.apple.addressbook` look unset but fail the domain read and own TCC container directories, so they belong with Safari and Mail. An earlier draft of this spec put them in the unset bucket by checking `defaults domains`, which lists `com.apple.TextEdit` even though reading it fails.

Granting Full Disk Access is a checked prerequisite, not a rejected idea: 39 Safari and Mail rows cannot be audited without it, which is a bigger loss than the cost of one one-time setup step. `scripts/macos-defaults.sh doctor` checks for it and exits 1 with instructions when it is missing; `make macos` depends on `macos-doctor`, so a fresh Mac is stopped before writing anything rather than silently skipping the app-container rows forever. `audit` still degrades gracefully without it — the 39 rows report `skip: ... (unreadable domain)` instead of failing — so a machine that has not yet granted access, and CI, still get a usable (if partial) audit.

### Root-owned domains need no sudo to read

`/Library/Preferences/com.apple.loginwindow.plist` is `-rw-r--r-- root wheel`. Audit reads it fine. **Only `apply` ever needs sudo**, which is what makes `make macos-audit` cheap enough to run casually.

## The source

`.macos` itself. Every `defaults write` line in it is a row; everything else in it (`nvram`, `systemsetup`, `PlistBuddy`, `chflags`, `killall`) is imperative and invisible to the tooling. The file stays a runnable script, so `sh .macos` is still the fresh-Mac bootstrap and there is only one place a setting is written down.

```bash
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool true
defaults write com.apple.helpviewer DevMode -bool true # noaudit=unset
defaults write com.apple.Safari ProxiesInBookmarksBar "()" # noaudit=complex
```

- **domain** — a bundle id, `NSGlobalDomain`, `.GlobalPreferences`, an absolute plist path, or the `-currentHost` flag (two rows use it). A `sudo` prefix is accepted and preserved.
- **key** — verbatim, quoted when it contains spaces, exactly as `defaults` wants it.
- **type** — the `defaults` flag: `-bool`, `-int`, `-float`, `-string`, or none (`raw`, handed to `defaults` to parse as a plist fragment), plus the containers `-array`, `-dict`, `-dict-add`, `-date`, `-data`. `-array-add` is refused: appending can never converge, so every apply would add the elements again.
- **value** — as written. `${HOME}` inside double quotes is kept as a token so a row describes desired state rather than one Mac's paths; audit and apply expand it, accept puts it back.
- **marker** — an optional trailing comment of one or more `key=value` tokens, which bash ignores. `noaudit=unset` for a key that never reads back even after apply (9 rows); `noaudit=complex` on an untyped value that is really a container (1 row); `host=<name>` to scope a row to one machine, which combines with either (`# noaudit=unset host=name`). A trailing comment with no `key=value` in it is prose and is preserved by accept; one that mixes a marker with prose is an error, so a marker cannot degrade silently.

### Why the table was folded back

The first cut of this design generated a tab-delimited table from `.macos` and left `.macos` as a 70-line imperative remainder. That meant two files describing one machine, a committed one-shot generator to keep them honest, and a format nobody else uses. The generator already *was* a parser for `defaults write` lines, so moving it into `scripts/macos-defaults.sh` and pointing it at `.macos` deleted the table, the generator, and the `.editorconfig` stanza for the table's tabs, and let a line copied from macos-defaults.com go straight in.

What was lost: the table's fifth column. Two of its three `noaudit` reasons turned out to be derivable (`complex` from the type flag, `tcc` from whether the domain reads at audit time), so only `unset` needed a written marker, and a trailing comment carries it.

### Why `noaudit=` and not `skip=`

Marked rows still have to be *written* on a fresh Mac. Only the *audit* cannot check them. `noaudit=<reason>` means apply writes the row and audit does not check it.

### Parsing rules

1. **The shell tokenizes, but only after the line is proven inert.** Each `defaults write`, `defaults -currentHost write` or `sudo defaults write` line (backslash continuations joined verbatim, as bash joins them, and never after a comment) must first match an allowlist regex: plain words, single-quoted strings, double-quoted strings whose only expansion is `${HOME}`, and an optional trailing comment. `;`, `&`, `|`, redirections, `$(...)`, backticks, unquoted parens and globs are rejected before anything is evaluated, so `check` and `audit` can never run a command. A line copied from macos-defaults.com with `&& killall Dock` on the end is the motivating case: it has to be split, not silently obeyed on every audit. What passes is `eval`ed with `defaults` and `sudo` shimmed, so quoting and `${HOME}` behave exactly as they do when `.macos` runs. No hand-rolled tokenizer to drift from bash. This is the same trust level as `sh .macos` (see [Applying complex rows](#applying-complex-rows)); the shims are unset the moment parsing ends so every later `defaults` call reaches the binary.
2. **Every other line is ignored**, including a commented-out `# defaults write`, `defaults delete`, and the imperative tail. The tooling never runs them.
3. **A malformed write is a hard error naming the line, and nothing runs.** Missing value, stray argument, unknown type flag (`-number`), `-array-add`, a `noaudit=tcc` marker (derived, so always stale), `noaudit=complex` on a typed scalar (always comparable), `noaudit=unset` on a container, an unknown marker, a marker mixed with prose, or a duplicate domain+key under the same host (`dict-add` exempt). A leading minus followed by a digit is a value, not a flag: `com.apple.mouse.scaling -1` is a real line.
4. Validate the whole file before acting on any row, matching `deploy.sh`.

The comments above each line are the *why*, and they never left the file.

## The applier

`scripts/macos-defaults.sh audit|apply|accept [--dry-run]`

### audit

Read-only always; never invokes sudo. One line per row:

| Outcome | Line |
|---|---|
| Live value matches | `ok: <domain> <key>` |
| Live value differs | `drift: <domain> <key> want=X live=Y` |
| Key absent from a domain that reads | `missing: <domain> <key>` |
| Domain will not read (TCC, or an app that never wrote preferences) | `skip: <domain> <key> (unreadable domain)` |
| Key absent, line marked `noaudit=unset` | `skip: <domain> <key> (unset)` |
| Container type, or `noaudit=complex` | `skip: <domain> <key> (complex)` |
| `host=` does not match | `skip: <domain> <key> (host=<name>)` |

Exits non-zero on any `drift` or `missing`. Skips never affect the exit code. A summary line counts each bucket so the numbers sum to the row count.

`missing` is reported separately from `drift` on purpose. Conflating them is what made the first probe run unreadable.

### apply

Writes only rows whose live value differs. `noaudit=` rows are always written, since audit cannot tell whether they need it.

`sudo` is used only when the target plist exists and is not writable by the current user, decided at apply time. Inferring it from the path shape would break the test sandbox, which uses absolute-path domains under a temp directory.

`--dry-run` prints the same decisions prefixed `would:` and touches nothing.

### accept

`accept [domain [key]]` rewrites the drifting `defaults write` line in `.macos` from what is live: same indentation, same `sudo` or `-currentHost` prefix, the live type flag and value, quoted the way the shell needs, and the markers or prose comment the line carried. With no arguments it takes every drifting row. Every other byte of the file is untouched. The new file is assembled beside the old one and moved into place in a single rename, mode preserved, so a failure part-way leaves `.macos` as it was.

A line marked `noaudit=unset` that has since become readable has the marker cleared. A line spanning continuation lines, or a live value containing a tab or newline, is refused with a message rather than rewritten. Container rows are never accepted: `defaults read` returns a multi-line plist dump that has no single-line spelling.

### Comparison rules

The naive `[ "$want" = "$live" ]` is wrong in four ways:

- **bool** normalizes both sides: `{true,TRUE,YES,yes,1}` → 1, `{false,FALSE,NO,no,0}` → 0.
- **string** and **raw** compare byte-exact. `AppleLocale`'s `USD` versus `usd` is real drift macOS created; `accept` blesses it once and it stays green.
- **Type drift is drift.** `defaults read-type` disagreeing with the line's type flag is reported.
- **A missing key is not a mismatched key.** `defaults read` exiting non-zero yields `missing`.

### Applying complex rows

The 12 container rows cannot express their value as a `type` + `value` pair. Those rows hold the literal argument tail the parser saw, and the applier runs `eval defaults write "$domain" "$key" -dict-add $value`. Scalar rows never touch `eval` on write.

This is the same trust level as `sh .macos` — a shell script from this repo, run deliberately by its owner — and the same argument covers parsing the lines with `eval` in the first place.

## Seeding

The drifts the first audit found were resolved one at a time and are recorded as edits to the `defaults write` lines themselves:

| Row | Decision |
|---|---|
| `NSGlobalDomain AppleLocale` | accept — macOS canonicalized the currency code to `usd` |
| `com.apple.ActivityMonitor ShowCategory` | accept — `100` is what a current Activity Monitor writes for the "all processes" view the comment asks for |
| `com.apple.ActivityMonitor OpenMainWindow` | reapply — it drifted opposite its own comment |
| `.GlobalPreferences com.apple.mouse.scaling` | rewrite as `-float 3`. The original bare `-1` wrote the *string* `-1`, which macOS ignores; the owner has since chosen `3` |
| `com.apple.AppleMultitouchTrackpad FirstClickThreshold` | accept as `-bool true`. Same value, different storage: the trackpad pane rewrote both keys as booleans. Writing `-int` back invites the pane to rewrite it again and turns the row into recurring noise |
| `com.apple.AppleMultitouchTrackpad SecondClickThreshold` | accept, same reason |
| `com.apple.dock showLaunchpadGestureEnabled` | the second of two identical lines removed; the duplicate check now rejects it |

The 9 unset rows carry `# noaudit=unset` so the baseline is green: `helpviewer DevMode`, `QuickTimePlayerX MGPlayMovieOnOpen`, `Siri` ×2, `GameCenter GKInviteAlertEnabled`, `TextEdit` ×3, `addressbook ABShowDebugMenu`.

**Verification of the fold-back:** the retired generator, run over the restored `.macos`, produced the same 217 domain/key/type/value rows as the retired table. The live audit before and after reads identically: 196 ok, 0 drift, 0 missing, 21 skipped (9 unset, 12 complex).

## Make targets

```text
macos-doctor          ->  ./scripts/macos-defaults.sh doctor
macos-audit           ->  ./scripts/macos-defaults.sh audit
macos-apply           ->  ./scripts/macos-defaults.sh apply      (only the rows that differ)
macos-accept          ->  ./scripts/macos-defaults.sh accept
check-macos-defaults  ->  ./scripts/macos-defaults.sh check
macos                 ->  doctor, then sh .macos, then the restart osascript
```

`make macos` is the fresh-Mac bootstrap and runs `.macos` whole, which writes every default and then the imperative tail. `make macos-apply` is the routine follow-up to an audit: it closes the delta without re-running `lsregister -kill`, the Launchpad reset or the `killall` loop. `make macos-audit` is the one meant for casual use, and it needs no sudo.

`make check-macos-defaults` validates that `.macos` parses, joining the existing `check-*` family so a malformed line fails in review rather than on the next `make macos`. It makes no `defaults` calls, so it runs on the ubuntu leg. `make preflight` already aggregates `test` plus every `check-*` target and CI calls `preflight`, so this needs no edit to `ci.yml`.

## Tests

`test/test_macos_defaults.sh`, sandboxed the way `test_deploy.sh` is.

**The sandbox works because `defaults` accepts an absolute plist path as a domain.** Tests point at domains under `mktemp -d` and never touch a real preference.

- Parser tests run on any platform: malformed writes with line-numbered errors, every marker rule, continuation lines, quoted keys, a `#` inside a quoted value, `sudo` and `-currentHost` prefixes, commented-out and imperative lines contributing nothing (and not running), exit codes.
- `defaults`-backed tests run only on Darwin and print a skip line elsewhere. The accept tests prove a rewritten line re-parses and that every other line of the fixture is byte-identical.
- Added to `make test`, so both CI legs pick it up.

## TCC and writes, resolved

**Writes were never blocked.** `defaults write com.apple.Safari AutoFillPasswords -bool false; echo $?` exits 0 whether or not the terminal has Full Disk Access — TCC gates reading a container domain's preferences, not writing them. `.macos` has been landing its Safari and Mail settings correctly the whole time; only auditing them was blocked.

Reads fail only for the reason above. Without Full Disk Access, `defaults read com.apple.Safari AutoFillPasswords` reports the domain does not exist. With it granted, `./scripts/macos-defaults.sh audit` checks all 39 Safari and Mail rows instead of skipping them — its summary line reports `unreadable 0` in the skip breakdown, not 39.

## Out of scope

- Comparing `array` and `dict` values. Normalizing plist container output is a larger job than drift detection warrants; those rows skip as `complex`.
- Per-host rows. The `host=` marker parses but no row uses it. There is no `os=` marker: `.macos` is Darwin by construction. Note that `sh .macos` run whole ignores the marker and writes every line; only the tooling honors it. If per-host rows arrive, `make macos` should become doctor, then `macos-apply`, then the imperative tail alone.
- Round-tripping escaped output through `accept`. `defaults read` prints a backslash as `\\` and non-ASCII as `\Uxxxx`, and accept stores what it prints, so accepting such a value doubles the escaping. No current row is affected; this was true of the table too.
- Moving the imperative tail (`PlistBuddy`, `nvram`, `chflags`, `systemsetup`) into any declarative form.
- Renaming `.macos`.
- Detecting settings the machine has that the table does not declare. Audit is one-directional: it only checks declared rows against the machine, never the reverse. A green audit means "everything declared is true," not "the machine is fully described."
