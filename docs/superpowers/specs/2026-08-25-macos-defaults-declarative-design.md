# Declarative macOS Defaults — Design

**Issue:** https://github.com/nonrational/dotfiles/issues/8 \
**Date:** 2026-08-25 \
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

Granting Full Disk Access is a checked prerequisite, not a rejected idea: 39 Safari and Mail rows cannot be audited without it, which is a bigger loss than the cost of one one-time setup step. `scripts/macos-defaults.sh doctor` checks for it and exits 1 with instructions when it is missing; `make macos` depends on `macos-doctor`, so a fresh Mac is stopped before `apply` rather than silently skipping the app-container rows forever. `audit` still degrades gracefully without it — the 39 rows report `skip: ... (tcc)` instead of failing — so a machine that has not yet granted access, and CI, still get a usable (if partial) audit.

### Root-owned domains need no sudo to read

`/Library/Preferences/com.apple.loginwindow.plist` is `-rw-r--r-- root wheel`. Audit reads it fine. **Only `apply` ever needs sudo**, which is what makes `make macos-audit` cheap enough to run casually.

## The table

`macos-defaults` at the repo root, beside `manifest`. Tab-delimited, four or five columns.

```
# domain	key	type	value	status
NSGlobalDomain	NSWindowResizeTime	float	0.001
com.apple.print.PrintingPrefs	Quit When Finished	bool	true
currentHost:com.apple.ImageCapture	disableHotPlug	bool	true
/Library/Preferences/com.apple.loginwindow	showInputMenu	bool	true
com.apple.Safari	AlwaysRestoreSessionAtLaunch	bool	true	noaudit=tcc
```

- **domain** — a bundle id, `NSGlobalDomain`, `.GlobalPreferences`, an absolute plist path, or a `currentHost:` prefix (two rows use it).
- **key** — verbatim; may contain spaces. `com.apple.print.PrintingPrefs "Quit When Finished"` and `com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)"` are why this file is tab-delimited rather than whitespace-columned like `manifest`.
- **type** — `bool`, `int`, `float`, `string`, `raw` (written with no type flag), plus `array`, `dict`, `dict-add`, `date` on `noaudit=complex` rows.
- **value** — human form. Booleans read `true`/`false` in the file; normalization happens at compare time.
- **status** — omitted on the 158 live rows. Otherwise `noaudit=tcc`, `noaudit=unset`, or `noaudit=complex`. The parser also accepts `os=` and `host=`, unused today, so a second Mac needs no format change.

### Why `noaudit=` and not `skip=`

Those 60 rows still have to be *written* on a fresh Mac, or `.macos` cannot retire. Only the *audit* cannot check them. `noaudit=<reason>` means apply writes the row and audit does not check it, uniformly across all three reasons.

### Parsing rules

Three of these are deliberate departures from `deploy.sh`.

1. **A line is a comment only if its first non-whitespace character is `#`.** `deploy.sh` uses `${line%%#*}`, which would eat a `#` inside a value. No value contains one today; the parser should not depend on that staying true.
2. **Split tabs by parameter expansion, never `IFS=$'\t' read`.** Bash treats tab as IFS *whitespace*, so it collapses runs of tabs and drops a leading one. An empty column silently shifts every field left and the run reports plausible nonsense. The probe that produced this design hit exactly this and reported almost every key missing before the bug was found.
3. **Four or five fields, nothing else, or a hard error naming the line — and nothing runs.** Only the trailing `status` field may be omitted, so there is no shift risk. It is omitted rather than left empty because `.editorconfig` sets `trim_trailing_whitespace = true` and a five-field row with an empty status would end in a tab.
4. Validate the whole file before acting on any row, matching `deploy.sh`.

Comments above rows carry the *why* over from `.macos`, all 44 section banners included. That commentary is the most valuable content in the file.

## The applier

`scripts/macos-defaults.sh audit|apply|accept [--dry-run]`

### audit

Read-only always; never invokes sudo. One line per row:

| Outcome | Line |
|---|---|
| Live value matches | `ok: <domain> <key>` |
| Live value differs | `drift: <domain> <key> want=X live=Y` |
| Key absent | `missing: <domain> <key>` |
| `noaudit=` row | `skip: <domain> <key> (<reason>)` |

Exits non-zero on any `drift` or `missing`. Skips never affect the exit code.

`missing` is reported separately from `drift` on purpose. Conflating them is what made the first probe run unreadable.

### apply

Writes only rows whose live value differs. `noaudit=` rows are always written, since audit cannot tell whether they need it.

`sudo` is used only when the target plist exists and is not writable by the current user, decided at apply time. Inferring it from the path shape would break the test sandbox, which uses absolute-path domains under a temp directory.

`--dry-run` prints the same decisions prefixed `would:` and touches nothing.

### accept

`accept [domain key ...]` rewrites the table's `value` and `type` from what is live. With no arguments it takes every drifting row. This is also the day-one seeding tool, so seeding and blessing share one code path.

A row marked `noaudit=unset` that has since become readable is promoted to a live row and the marker cleared.

### Comparison rules

The naive `[ "$want" = "$live" ]` is wrong in four ways:

- **bool** normalizes both sides: `{true,TRUE,YES,yes,1}` → 1, `{false,FALSE,NO,no,0}` → 0.
- **string** and **raw** compare byte-exact. `AppleLocale`'s `USD` versus `usd` is real drift macOS created; `accept` blesses it once and it stays green.
- **Type drift is drift.** `defaults read-type` disagreeing with the table's `type` is reported.
- **A missing key is not a mismatched key.** `defaults read` exiting non-zero yields `missing`.

### Applying complex rows

The 11 `array`/`dict`/`dict-add`/`date` rows cannot express their value as a `type` + `value` pair. Those rows hold the literal argument tail, and the applier runs `eval defaults write "$domain" "$key" -dict-add $value`. Scalar rows never touch `eval`.

This is the same trust level as `sh .macos` — a shell script from this repo, run deliberately by its owner — and the alternative is keeping a second writer alive forever.

## Migration

`scripts/migrate-macos-defaults.sh` generates the table by parsing `.macos` with a `defaults` shell shim. Committed rather than run and discarded, following the `scripts/migrate-to-home.sh` precedent, so the transcription is reviewable rather than trusted.

**Verification:** re-parse `.macos` at its pre-change commit, re-parse the generated table, and diff the `domain/key/type/value` sets. They must be identical except for rows explicitly accepted. That is a one-command proof that nothing was dropped across 218 lines.

Seeding fills values from live. The four drifting rows are held back as a decision rather than auto-accepted:

| Row | Decision |
|---|---|
| `NSGlobalDomain AppleLocale` | accept — macOS canonicalized the currency code |
| `com.apple.ActivityMonitor ShowCategory` | accept — `100` is what a current Activity Monitor writes for the "all processes" view the comment asks for; confirm against the app |
| `com.apple.ActivityMonitor OpenMainWindow` | accept. If it drifts back, the app rewrites it on quit and the row wants a `noaudit=` marker |
| `.GlobalPreferences com.apple.mouse.scaling` | **reapply** — the table wins; mouse acceleration should be off |
| `com.apple.AppleMultitouchTrackpad FirstClickThreshold` | accept. Same value, different storage: the trackpad pane rewrote both keys as booleans. Writing `-int` back invites the pane to rewrite it again and turns the row into recurring noise |
| `com.apple.AppleMultitouchTrackpad SecondClickThreshold` | accept, same reason |

The 9 unset rows enter as `noaudit=unset` so the baseline is green: `helpviewer DevMode`, `QuickTimePlayerX MGPlayMovieOnOpen`, `Siri` ×2, `GameCenter GKInviteAlertEnabled`, `TextEdit` ×3, `addressbook ABShowDebugMenu`.

## What `.macos` keeps

All 218 `defaults write` lines leave. Roughly 45 lines remain: the System Settings quit, the sudo keepalive, `nvram SystemAudioVolume`, `systemsetup -settimezone`, the nine `PlistBuddy` Finder-view calls, both `chflags`, `lsregister`, the Dock `find -delete`, `tmutil disable`, the closing `killall` loop, and the final echo.

It keeps its filename and gains a header comment pointing at `macos-defaults`. Nothing is symlinked to it — it has no `manifest` entry — so a later rename to `scripts/macos-imperative.sh` costs nothing but muscle memory.

## Make targets

```text
macos-audit    ->  ./scripts/macos-defaults.sh audit
macos-apply    ->  ./scripts/macos-defaults.sh apply
macos-accept   ->  ./scripts/macos-defaults.sh accept
macos          ->  apply the table, then sh .macos, then the restart osascript
```

`make macos` keeps its current behavior, restart included. `make macos-audit` is the one meant for casual use, and it needs no sudo.

`make check-macos-defaults` validates that the table parses, joining the existing `check-*` family so a malformed row fails in review rather than on the next `make macos`. `make preflight` already aggregates `test` plus every `check-*` target and CI calls `preflight`, so this needs no edit to `ci.yml`.

## Tests

`test/test_macos_defaults.sh`, sandboxed the way `test_deploy.sh` is.

**The sandbox works because `defaults` accepts an absolute plist path as a domain.** Tests point at domains under `mktemp -d` and never touch a real preference.

- Parser tests run on any platform: field counts, an omitted status column (the tab trap), `#` inside a value, line-numbered errors on malformed rows, exit codes.
- `defaults`-backed tests run only on Darwin and print a skip line elsewhere.
- Added to `make test`, so both CI legs pick it up.

`.editorconfig` gains a `[macos-defaults]` stanza documenting that the tabs are data separators rather than indentation.

## TCC and writes, resolved

**Writes were never blocked.** `defaults write com.apple.Safari AutoFillPasswords -bool false; echo $?` exits 0 whether or not the terminal has Full Disk Access — TCC gates reading a container domain's preferences, not writing them. `.macos` has been landing its Safari and Mail settings correctly the whole time; only auditing them was blocked.

Reads fail only for the reason above. Without Full Disk Access, `defaults read com.apple.Safari AutoFillPasswords` reports the domain does not exist. With it granted, `./scripts/macos-defaults.sh audit` checks all 39 Safari and Mail rows instead of skipping them — its summary line reports `tcc 0` in the skip breakdown, not 39.

## Out of scope

- Comparing `array` and `dict` values. Normalizing plist container output is a larger job than drift detection warrants; those rows stay `noaudit=complex`.
- Per-host rows. The `os=` and `host=` vocabulary parses but no row uses it.
- Moving the imperative tail (`PlistBuddy`, `nvram`, `chflags`, `systemsetup`) into any declarative form.
- Renaming `.macos`.
- Detecting settings the machine has that the table does not declare. Audit is one-directional: it only checks declared rows against the machine, never the reverse. A green audit means "everything declared is true," not "the machine is fully described."
