#!/usr/bin/env bash
# One-shot migration: unify an in-use ~/.dotfiles checkout onto the home/ layout.
#
# `git checkout move-to-home` only renames *tracked* files. Everything ignored
# under .claude/ and .gemini/ (credentials, history, projects, oauth tokens)
# stays behind in a directory git then can't delete. This moves the strays,
# re-points the submodule at its moved worktree, and relinks $HOME.
#
# Throwaway. Delete once move-to-home has landed on main.
#
# Every filesystem change is a rename, journaled to $JOURNAL. Renames keep the
# inode, so anything holding these files open follows them; a copy would leave
# those writes going to a deleted inode.
#
# Usage:
#   migrate-to-home.sh                  # dry run (default)
#   migrate-to-home.sh --apply
#   migrate-to-home.sh --rollback JOURNAL

set -uo pipefail   # deliberately not -e (errors are handled) and not -f (globs needed)

DOTS="${DOTS:-$HOME/.dotfiles}"
BRANCH="${BRANCH:-move-to-home}"
JOURNAL_DIR="${JOURNAL_DIR:-$HOME/.migrate-to-home}"

apply=0
rollback_from=""
JOURNAL=""
failures=0
planned=0

say()  { printf '%s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
fail() { warn "$*"; failures=$((failures + 1)); }

step() {
    if [ "$apply" = 1 ]; then printf '%s\n' "$*"; else printf 'would: %s\n' "$*"; fi
    planned=$((planned + 1))
}

rel() { printf '%s' "${1#"$DOTS"/}"; }

# ---------------------------------------------------------------- journal

journal_init() {
    [ "$apply" = 1 ] || return 0
    local head
    head="$(git -C "$DOTS" rev-parse --short HEAD)" || die "cannot read HEAD"
    # Not $TMPDIR: macOS purges it, and the journal is the only copy of the
    # live settings.json and the pre-migration git config.
    mkdir -p "$JOURNAL_DIR" || die "cannot create $JOURNAL_DIR"
    JOURNAL="$JOURNAL_DIR/$head.$$.journal"
    : >"$JOURNAL" || die "cannot write journal at $JOURNAL"
    local branch
    branch="$(git -C "$DOTS" rev-parse --abbrev-ref HEAD)" || die "cannot read current branch"
    printf 'branch\t%s\t\n' "$branch" >>"$JOURNAL"
    say "journal: $JOURNAL"
}

record() {
    [ "$apply" = 1 ] || return 0
    printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >>"$JOURNAL"
}

# Copy a file aside before we rewrite it, so rollback can put it back verbatim.
# The data moves are all renames and reverse themselves; these small config
# files are the only things we edit in place, and an unjournaled edit would let
# rollback restore the worktree while leaving git pointing at nothing.
snapshot() {
    local f="$1" backup
    [ "$apply" = 1 ] || return 0
    [ -e "$f" ] || { fail "expected $f to exist before rewriting it"; return 1; }
    mkdir -p "$JOURNAL.d" || { fail "cannot create $JOURNAL.d"; return 1; }
    backup="$JOURNAL.d/$(printf '%s' "${f#"$DOTS"/}" | tr '/' '_')"
    cp -p "$f" "$backup" || { fail "could not snapshot $f"; return 1; }
    record restore "$f" "$backup"
}

# mv that journals. Never overwrites: caller guarantees the target is free.
do_mv() {
    local src="$1" dst="$2"
    if [ "$apply" = 0 ]; then return 0; fi
    mkdir -p "$(dirname "$dst")" || { fail "mkdir failed for $dst"; return 1; }
    if mv "$src" "$dst"; then
        record mv "$src" "$dst"
    else
        fail "mv failed: $src -> $dst"
        return 1
    fi
}

# rm of a dead symlink, journaled so rollback can recreate it.
do_unlink() {
    local path="$1" target
    target="$(readlink "$path")"
    if [ "$apply" = 0 ]; then return 0; fi
    rm "$path" && record link "$path" "$target" || fail "rm failed: $path"
}

rollback() {
    local j="$1" op a b orig_branch="" saved_settings="" rb=0
    [ -f "$j" ] || die "no such journal: $j"

    # A rollback is only safe against the tree the migration left. Anything
    # else tracked-and-modified is the user's work, and reversing renames
    # underneath it would be silent damage.
    local dirty
    dirty="$(git -C "$DOTS" status --porcelain --untracked-files=no)"
    if [ -n "$dirty" ]; then
        local expected
        expected="$(printf '%s\n' "$dirty" | grep -vE ' (home/)?\.claude/settings\.json$')"
        if [ -n "$expected" ]; then
            die "tracked changes present that this rollback did not make:
$expected
       Commit or stash them first — rollback reverses renames and would strand them."
        fi
    fi

    say "rolling back $j"
    # Reverse order: undo the most recent change first. Every op here is the
    # inverse of one the migration recorded, so a partial run unwinds to exactly
    # where it started.
    while IFS=$'\t' read -r op a b; do
        case "$op" in
            mv)       say "  mv $b -> $a"; mkdir -p "$(dirname "$a")"
                      mv "$b" "$a" || { warn "could not restore $a"; rb=$((rb + 1)); } ;;
            link)     say "  relink $a"
                      ln -s "$b" "$a" || { warn "could not recreate $a"; rb=$((rb + 1)); } ;;
            restore)  say "  restore $(rel "$a")"
                      cp -p "$b" "$a" || { warn "could not restore $a"; rb=$((rb + 1)); } ;;
            edited)   say "  discard our edit to $a"
                      git -C "$DOTS" checkout -- "$a" 2>/dev/null \
                          || warn "could not discard $a (may not exist yet)" ;;
            settings) saved_settings="$a" ;;
            branch)   orig_branch="$a" ;;
        esac
    done < <(tac "$j" 2>/dev/null || tail -r "$j")

    if [ -n "$orig_branch" ]; then
        say "  git checkout $orig_branch"
        git -C "$DOTS" checkout "$orig_branch" || { warn "could not return to $orig_branch"; rb=$((rb + 1)); }
    else
        warn "journal does not record the original branch; left on $(git -C "$DOTS" rev-parse --abbrev-ref HEAD)"
        rb=$((rb + 1))
    fi

    # Only meaningful once the checkout above has recreated the old path.
    if [ -n "$saved_settings" ]; then
        if [ -s "$saved_settings" ]; then
            say "  restore live .claude/settings.json"
            cp -p "$saved_settings" "$DOTS/.claude/settings.json" \
                || { warn "could not restore settings.json"; rb=$((rb + 1)); }
        else
            warn "saved settings.json missing or empty at $saved_settings; NOT restored"
            rb=$((rb + 1))
        fi
    fi

    if [ "$rb" -gt 0 ]; then
        say
        say "rollback finished with $rb problem(s) — the tree may be half-migrated."
        say "Journal left at $j for a second attempt."
        return 1
    fi
    say "rollback complete. Re-run ./deploy.sh apply to restore symlinks."
}

# ---------------------------------------------------------------- preflight

preflight() {
    [ -d "$DOTS/.git" ] || die "$DOTS is not a git checkout"

    # Guard only matters if this checkout is the one $HOME is wired to — that's
    # what makes a running Claude Code a hazard rather than a bystander. Keeping
    # the condition precise means a test run against a copy needs no backdoor.
    local live deployed
    deployed="$(readlink "$HOME/.claude" 2>/dev/null || true)"
    live="$(pgrep -x claude | wc -l | tr -d ' ')"
    if [ "$live" != "0" ] && [ "${deployed#"$DOTS"/}" != "$deployed" ]; then
        if [ "$apply" = 1 ]; then
            die "$live Claude Code process(es) running, and ~/.claude points into $DOTS.
       This migration moves ~/.claude out from under them.
       Quit Claude Code entirely, then re-run from a plain terminal."
        fi
        warn "$live Claude Code process(es) running — fine for a dry run, but --apply will refuse."
    fi

    git -C "$DOTS" rev-parse --verify "$BRANCH" >/dev/null 2>&1 || die "branch $BRANCH not found in $DOTS"

    # Tracked modifications block a checkout across a rename. settings.json is
    # expected (Claude rewrites it); anything else is a surprise we won't guess at.
    local dirty
    dirty="$(git -C "$DOTS" status --porcelain --untracked-files=no | grep -v ' \.claude/settings\.json$')"
    if [ -n "$dirty" ]; then
        die "uncommitted tracked changes beyond .claude/settings.json:
$dirty
       Commit or stash them first."
    fi

    git -C "$DOTS/.claude/ext/mattpocock-skills" rev-parse HEAD >/dev/null 2>&1 \
        || die "submodule at .claude/ext/mattpocock-skills does not resolve HEAD; fix it before migrating"

    [ ! -e "$DOTS/.git/modules/home" ] \
        || die ".git/modules/home exists — a buggy earlier run moved the object store.
       Git keys it by submodule name, not path; move it back to
       .git/modules/.claude/ext/mattpocock-skills before retrying."

    # A half-finished run must be rolled back, not layered over: a second
    # journal would snapshot already-rewritten config, and the two would only
    # unwind correctly in reverse order — a trap not worth leaving lying around.
    if [ "$apply" = 1 ] && [ -e "$DOTS/home" ]; then
        local prior hint
        prior="$(ls "$JOURNAL_DIR"/*.journal 2>/dev/null | head -1 || true)"
        if [ -n "$prior" ]; then
            hint="Roll it back first:  bash $0 --rollback $prior"
        else
            hint="No journal found in $JOURNAL_DIR; reconcile by hand before retrying."
        fi
        die "$DOTS/home already exists — an earlier run got partway.
       $hint"
    fi
}

# ---------------------------------------------------------------- moving

# Move $1 onto $2, merging directories. Only ever renames, so open file
# descriptors follow their files. Refuses on any file-vs-file collision.
merge_move() {
    local src="$1" dst="$2" entry

    # Target free: take the whole subtree in one rename.
    if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
        step "move $(rel "$src") -> $(rel "$dst")"
        do_mv "$src" "$dst"
        return
    fi

    # Both real directories: git checkout may have left an empty placeholder
    # (the submodule), otherwise merge child by child.
    if [ -d "$src" ] && [ -d "$dst" ] && [ ! -L "$src" ] && [ ! -L "$dst" ]; then
        if [ -z "$(ls -A "$dst" 2>/dev/null)" ]; then
            step "move $(rel "$src") -> $(rel "$dst") (replacing empty dir)"
            if [ "$apply" = 1 ]; then rmdir "$dst" || { fail "rmdir $dst"; return 1; }; fi
            do_mv "$src" "$dst"
            return
        fi
        for entry in "$src"/* "$src"/.[!.]* "$src"/..?*; do
            [ -e "$entry" ] || [ -L "$entry" ] || continue   # unmatched glob
            merge_move "$entry" "$dst/$(basename "$entry")"
        done
        return
    fi

    fail "conflict: $(rel "$src") and $(rel "$dst") both exist and cannot merge"
}

# What will actually strand? The checkout moves every *tracked* path out of the
# legacy directory, leaving exactly the untracked and ignored ones behind. We
# can predict that set without checking out — which is the only way a dry run
# describes the world the apply will meet, rather than the one it starts in.
#
# Prints one line per top-level entry that needs us:
#   whole <name>   git leaves it entirely; we rename it across
#   merge <name>   tracked, but holds ignored content; recurse into it
plan_legacy() {
    local legacy="$1" entry base
    for entry in "$DOTS/$legacy"/* "$DOTS/$legacy"/.[!.]* "$DOTS/$legacy"/..?*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        base="$(basename "$entry")"
        if [ -z "$(git -C "$DOTS" ls-files --cached -- "$legacy/$base" | head -1)" ]; then
            printf 'whole\t%s\n' "$base"
        elif [ ! -d "$entry" ] || [ -L "$entry" ]; then
            :   # tracked file: the checkout moves it, nothing for us to do
        elif git -C "$DOTS" status --porcelain --ignored=matching -- "$legacy/$base" 2>/dev/null \
             | grep -qE '^(\?\?|!!)'; then
            printf 'merge\t%s\n' "$base"
        elif git -C "$DOTS" ls-files --stage -- "$legacy/$base" | grep -q '^160000'; then
            # Holds a submodule worktree. git moves the gitlink and leaves an
            # empty dir; the actual checkout stays behind for us to rename.
            printf 'merge\t%s\n' "$base"
        fi
    done
}

# ---------------------------------------------------------------- phases

# The top-level symlinks under .claude/ point at ../ext/... which resolves
# outside .claude entirely. All dangle, none are tracked, and Claude Code reads
# skills from skills/ anyway — so they are dead in a place nothing reads.
drop_dead_links() {
    local legacy="$DOTS/.claude" l target n=0
    [ -d "$legacy" ] || return 0
    # `*` alone skips dot-prefixed names — which is how .claude/.claude, the
    # one entry this function exists to catch, got missed the first time.
    for l in "$legacy"/* "$legacy"/.[!.]* "$legacy"/..?*; do
        [ -L "$l" ] || continue
        # Every one of these is untracked today; refuse to touch anything git
        # knows about rather than rely on that staying true.
        [ -z "$(git -C "$DOTS" ls-files --cached -- "${l#"$DOTS"/}")" ] || continue
        target="$(readlink "$l")"
        if [ ! -e "$l" ]; then
            step "drop dangling link .claude/$(basename "$l") -> $target"
        elif [ "${target#"$DOTS"/}" != "$target" ]; then
            # Absolute link back into the tree we're about to dismantle: it
            # resolves now and would dangle the moment step 7 runs. (Relative
            # links like skills/tdd -> ../ext/... travel with the tree and stay
            # correct, so the test has to be absoluteness, not target.)
            step "drop stale self-link .claude/$(basename "$l") -> $target"
        else
            continue
        fi
        do_unlink "$l"
        n=$((n + 1))
    done
    [ "$n" = 0 ] || say "  ($n untracked, in a directory Claude Code does not read)"
}

# One `../` per component of $1.
ups() {
    local n i s=""
    n="$(printf '%s' "$1" | awk -F/ '{print NF}')"
    for ((i = 0; i < n; i++)); do s="../$s"; done
    printf '%s' "$s"
}

# Read the submodule's name and path from the *branch's* .gitmodules.
#
# The worktree copy still describes the old layout until the checkout lands, so
# reading it in a dry run would print the current values and advertise step 5 as
# a no-op. The branch's copy is correct in both modes.
submodule_facts() {
    local gm out
    gm="$(mktemp)" || return 1
    if ! git -C "$DOTS" show "$BRANCH:.gitmodules" >"$gm" 2>/dev/null; then
        rm -f "$gm"; return 1
    fi
    out="$(git config -f "$gm" --get-regexp '^submodule\..*\.path$' \
        | awk '$2 ~ /mattpocock-skills$/ {print $1, $2}')"
    rm -f "$gm"
    [ -n "$out" ] || return 1
    # name<TAB>path
    printf '%s\t%s\n' \
        "$(printf '%s' "$out" | awk '{print $1}' | sed 's/^submodule\.//; s/\.path$//')" \
        "$(printf '%s' "$out" | awk '{print $2}')"
}

# Re-point the submodule at its moved worktree.
#
# Git keys the object store by submodule *name* — the [submodule "..."] header
# in .gitmodules — not by path. The branch changed only `path`, so the name is
# still ".claude/ext/mattpocock-skills" and .git/modules/.claude/ext/... is
# already exactly where git looks. Moving it would orphan it: the next
# `git submodule update` would find nothing at the name-keyed path and re-clone.
#
# So the object store stays put. Only the two relative paths between it and the
# worktree change, because the worktree gained a `home/` level.
fix_submodule() {
    local facts name path gitdir worktree

    facts="$(submodule_facts)" || { fail "could not read submodule name/path from $BRANCH:.gitmodules"; return; }
    name="${facts%%$'\t'*}"
    path="${facts#*$'\t'}"

    gitdir="$DOTS/.git/modules/$name"
    worktree="$DOTS/$path"
    say "  name: $name"
    say "  path: $path"

    [ -d "$gitdir" ] || { fail "no object store at .git/modules/$name; skipping rewire"; return; }

    step "rewrite gitlink -> $(ups "$path").git/modules/$name"
    if [ "$apply" = 1 ]; then
        snapshot "$worktree/.git" || { fail "refusing to rewrite gitlink without a backup"; return; }
        printf 'gitdir: %s.git/modules/%s\n' "$(ups "$path")" "$name" >"$worktree/.git" \
            || fail "could not write gitlink"
    fi

    step "rewrite core.worktree -> $(ups ".git/modules/$name")$path"
    if [ "$apply" = 1 ]; then
        snapshot "$gitdir/config" || { fail "refusing to rewrite core.worktree without a backup"; return; }
        git config -f "$gitdir/config" core.worktree "$(ups ".git/modules/$name")$path" \
            || fail "could not set core.worktree"
    fi

    # Register it. This is the pre-existing defect that made `git submodule
    # status` print a leading `-`. init only writes .git/config; it won't clone.
    step "git submodule init -- $path"
    if [ "$apply" = 1 ]; then
        snapshot "$DOTS/.git/config" || { fail "refusing to run submodule init without a backup"; return; }
        git -C "$DOTS" submodule init -- "$path" || fail "git submodule init failed"
    fi
}

remove_empty_legacy() {
    local d
    for d in "$@"; do
        [ -d "$DOTS/$d" ] || continue

        # Nothing has moved in a dry run, so a leftovers check here would only
        # ever report the files the checkout hasn't taken away yet.
        if [ "$apply" = 0 ]; then
            step "remove $d/ once emptied"
            continue
        fi

        find "$DOTS/$d" -type d -empty -delete 2>/dev/null
        if [ -d "$DOTS/$d" ]; then
            fail "$d/ survived; left in place with:"
            ls -A "$DOTS/$d" 2>/dev/null | sed 's/^/    /' >&2
        else
            step "remove empty $d/"
        fi
    done
}

verify() {
    # Start from the damage already recorded. Without this, a stranded
    # projects/ warns during step 4 and still prints "migration verified".
    local bad="$failures" s
    [ "$bad" = 0 ] || say "carrying $bad problem(s) from the migration into verification"

    say
    say "=== verify ==="

    if (cd "$DOTS" && ./deploy.sh audit) >/dev/null 2>&1; then
        say "ok: all manifest symlinks resolve"
    else
        say "FAIL: deploy.sh audit reported drift:"
        (cd "$DOTS" && ./deploy.sh audit) 2>&1 | grep -vE '^ok:' | sed 's/^/    /'
        bad=$((bad + 1))
    fi

    # rev-parse alone is not enough: a gitlink and core.worktree that agree with
    # each other will resolve HEAD happily even when the object store sits
    # somewhere git's own submodule lookup will never find it — or when the
    # worktree it points at is an empty placeholder.
    if git -C "$DOTS/home/.claude/ext/mattpocock-skills" rev-parse HEAD >/dev/null 2>&1; then
        say "ok: submodule worktree resolves HEAD ($(git -C "$DOTS/home/.claude/ext/mattpocock-skills" rev-parse --short HEAD))"
    else
        say "FAIL: submodule worktree does not resolve HEAD"
        bad=$((bad + 1))
    fi

    if [ -d "$DOTS/home/.claude/ext/mattpocock-skills/skills" ]; then
        say "ok: submodule worktree has content"
    else
        say "FAIL: submodule worktree is empty — the real checkout stranded"
        bad=$((bad + 1))
    fi

    local st
    st="$(git -C "$DOTS" submodule status -- home/.claude/ext/mattpocock-skills 2>/dev/null)"
    case "$st" in
        -*) say "FAIL: git still considers the submodule uninitialized:${st}"; bad=$((bad + 1)) ;;
        +*) say "FAIL: submodule is at the wrong commit:${st}"; bad=$((bad + 1)) ;;
        "") say "FAIL: git submodule status reports nothing for the new path"; bad=$((bad + 1)) ;;
        *)  say "ok: git submodule status clean (${st# })" ;;
    esac

    if [ -e "$DOTS/.git/modules/home" ]; then
        say "FAIL: orphaned object store at .git/modules/home — git looks up by name, not path"
        bad=$((bad + 1))
    else
        say "ok: no orphaned object store under .git/modules/home"
    fi

    local dangling=0
    for s in "$DOTS"/home/.claude/skills/*; do
        [ -L "$s" ] || continue
        [ -e "$s" ] || { say "FAIL: dangling skill $(basename "$s")"; dangling=$((dangling + 1)); }
    done
    [ "$dangling" = 0 ] && say "ok: all skill symlinks resolve"
    [ "$dangling" = 0 ] || bad=$((bad + 1))

    # Existence is not enough for settings.json: a truncated copy still exists.
    for s in settings.json .credentials.json history.jsonl; do
        if [ -s "$HOME/.claude/$s" ]; then say "ok: ~/.claude/$s present and non-empty"
        elif [ -e "$HOME/.claude/$s" ]; then say "FAIL: ~/.claude/$s is EMPTY"; bad=$((bad + 1))
        else say "FAIL: ~/.claude/$s missing"; bad=$((bad + 1)); fi
    done

    # The bulk of the runtime state, which the spot-checks above would miss.
    for s in projects plugins sessions; do
        if [ -d "$HOME/.claude/$s" ] && [ -n "$(ls -A "$HOME/.claude/$s" 2>/dev/null)" ]; then
            say "ok: ~/.claude/$s/ present ($(du -sh "$HOME/.claude/$s" 2>/dev/null | cut -f1))"
        else
            say "FAIL: ~/.claude/$s/ missing or empty"
            bad=$((bad + 1))
        fi
    done

    # Nothing may be left at the old paths.
    for s in .claude .gemini; do
        if [ -e "$DOTS/$s" ]; then say "FAIL: $s/ still exists at the repo root"; bad=$((bad + 1))
        else say "ok: $s/ gone from the repo root"; fi
    done

    if [ "$bad" = 0 ]; then
        say
        say "migration verified. Journal kept at $JOURNAL — delete once you're happy."
        return 0
    fi
    say
    say "$bad check(s) failed. Roll back with:"
    say "  bash $0 --rollback $JOURNAL"
    return 1
}

# ---------------------------------------------------------------- main

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --apply)    apply=1 ;;
            --dry-run)  apply=0 ;;
            --rollback)
                shift
                [ $# -gt 0 ] || die "--rollback needs a journal path"
                rollback_from="$1" ;;
            *) die "usage: $0 [--apply] [--rollback JOURNAL]" ;;
        esac
        shift
    done

    if [ -n "$rollback_from" ]; then rollback "$rollback_from"; exit $?; fi

    preflight

    if [ "$apply" = 0 ]; then
        say "DRY RUN — nothing will change. Re-run with --apply to execute."
        say
    fi

    journal_init

    # Read the manifest from the branch: it is the branch's own account of what
    # moves, so this can't drift from what we're migrating to.
    local sources
    sources="$(git -C "$DOTS" show "$BRANCH:manifest" | sed 's/#.*//' | awk 'NF {print $1}' | grep '^home/')"
    [ -n "$sources" ] || die "no home/ entries in $BRANCH:manifest — is this the right branch?"

    say "=== 1. preserve live settings.json ==="
    local saved=""
    if ! git -C "$DOTS" diff --quiet -- .claude/settings.json 2>/dev/null; then
        step "save modified .claude/settings.json aside"
        step "discard it so the checkout can rename the file"
        if [ "$apply" = 1 ]; then
            saved="$JOURNAL.d/live-settings.json"
            mkdir -p "$JOURNAL.d" || die "cannot create $JOURNAL.d"
            # Checked, and checked again for content: the next line destroys the
            # only other copy, and a truncated backup would take it with it.
            cp -p "$DOTS/.claude/settings.json" "$saved" \
                || die "could not back up settings.json; refusing to discard the live copy"
            [ -s "$saved" ] || die "backup of settings.json is empty; refusing to discard the live copy"
            record settings "$saved"
            git -C "$DOTS" checkout -- .claude/settings.json \
                || die "could not discard settings.json; nothing else has changed"
        fi
    else
        say "  (unmodified; nothing to preserve)"
    fi

    say
    say "=== 2. drop dead top-level links ==="
    drop_dead_links

    say
    say "=== 3. git checkout $BRANCH ==="
    step "git checkout $BRANCH"
    if [ "$apply" = 1 ]; then
        git -C "$DOTS" checkout "$BRANCH" || {
            say "checkout failed. Steps 1-2 already ran; undo them with:"
            say "  bash $0 --rollback $JOURNAL"
            die "aborting at the checkout"
        }
    fi

    say
    say "=== 4. move stranded state into home/ ==="
    local src legacy legacies=() plan whole merge
    while IFS= read -r src; do
        legacy="${src#home/}"
        [ -e "$DOTS/$legacy" ] || continue

        if [ "$apply" = 1 ]; then
            # Post-checkout the legacy path only exists if something stranded.
            legacies+=("$legacy")
            merge_move "$DOTS/$legacy" "$DOTS/$src"
            continue
        fi

        # Dry run: predict what the checkout will leave behind.
        [ -d "$DOTS/$legacy" ] && [ ! -L "$DOTS/$legacy" ] || continue
        plan="$(plan_legacy "$legacy")"
        [ -n "$plan" ] || continue
        legacies+=("$legacy")
        whole="$(printf '%s\n' "$plan" | grep -c '^whole' || true)"
        merge="$(printf '%s\n' "$plan" | awk '$1=="merge" {print $2}' | tr '\n' ' ')"
        step "merge $legacy/ -> $src/ ($whole entries move whole${merge:+, recurse into: ${merge% }})"
    done <<<"$sources"

    say
    say "=== 5. re-wire submodule ==="
    fix_submodule

    say
    say "=== 6. restore settings.json ==="
    if [ -n "$saved" ] || [ "$apply" = 0 ]; then
        step "restore saved settings.json -> home/.claude/settings.json"
        if [ "$apply" = 1 ]; then
            cp -p "$saved" "$DOTS/home/.claude/settings.json" || fail "could not restore settings.json"
            record edited "home/.claude/settings.json"
        fi
    else
        say "  (nothing to restore)"
    fi

    say
    say "=== 7. remove emptied legacy dirs ==="
    [ "${#legacies[@]}" -gt 0 ] && remove_empty_legacy "${legacies[@]}"

    say
    say "=== 8. relink \$HOME ==="
    step "./deploy.sh apply"
    if [ "$apply" = 1 ]; then
        (cd "$DOTS" && ./deploy.sh apply) || fail "deploy.sh apply reported problems"
    fi

    if [ "$apply" = 0 ]; then
        say
        say "$planned step(s) planned. Nothing changed."
        say "Run with --apply to execute."
        exit 0
    fi

    verify
}

main "$@"
