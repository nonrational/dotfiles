#!/bin/sh
# sync-plugins.sh — make this machine's Claude Code plugins match the committed
# config in settings.json. Adds any marketplace the enabled plugins need, then
# installs the enabled plugins that aren't present yet. Safe to re-run.
#
# settings.json records which plugins are enabled but not where their
# marketplaces come from, so the name -> source mapping lives in
# marketplace_source() below. Add a case there when you start using a new one.
#
# Uses the macOS system Python (/usr/bin/python3) so it runs during dotfiles
# bootstrap, before asdf or any toolchain is on PATH.

set -eu

PY=/usr/bin/python3
CLAUDE_DIR="${HOME}/.claude"
SETTINGS="${CLAUDE_DIR}/settings.json"
KNOWN_MARKETPLACES="${CLAUDE_DIR}/plugins/known_marketplaces.json"
INSTALLED="${CLAUDE_DIR}/plugins/installed_plugins.json"

# Map a marketplace name to the source `claude plugin marketplace add` expects.
marketplace_source() {
  case "$1" in
    claude-plugins-official) echo "anthropics/claude-plugins-official" ;;
    *) echo "" ;;
  esac
}

if [ ! -f "$SETTINGS" ]; then
  echo "No settings.json at $SETTINGS — nothing to sync." >&2
  exit 0
fi

# Plugins marked enabled (value true) in settings.json, one "name@marketplace" per line.
enabled_plugins() {
  "$PY" - "$SETTINGS" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
for name, on in (data.get("enabledPlugins") or {}).items():
    if on:
        print(name)
PYEOF
}

# Keys of a JSON object, one per line. Pass a top-level key to read a nested object.
json_keys() {
  file="$1"; top="$2"
  [ -f "$file" ] || return 0
  "$PY" - "$file" "$top" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
node = data.get(sys.argv[2]) if sys.argv[2] else data
for k in (node or {}):
    print(k)
PYEOF
}

ENABLED="$(enabled_plugins)"
if [ -z "$ENABLED" ]; then
  echo "No enabled plugins in settings.json — nothing to do."
  exit 0
fi

# --- Add required marketplaces ------------------------------------------------
KNOWN="$(json_keys "$KNOWN_MARKETPLACES" "")"
MARKETPLACES="$(printf '%s\n' "$ENABLED" | sed -n 's/.*@//p' | sort -u)"

for mkt in $MARKETPLACES; do
  if printf '%s\n' "$KNOWN" | grep -qx "$mkt"; then
    continue
  fi
  src="$(marketplace_source "$mkt")"
  if [ -z "$src" ]; then
    echo "WARNING: marketplace '$mkt' is required but has no source mapping." >&2
    echo "         Add a case for it to marketplace_source() in this script." >&2
    continue
  fi
  echo "Adding marketplace $mkt ($src)"
  claude plugin marketplace add "$src"
done

# --- Install enabled plugins that aren't installed yet ------------------------
INSTALLED_KEYS="$(json_keys "$INSTALLED" "plugins")"

printf '%s\n' "$ENABLED" | while IFS= read -r plugin; do
  [ -n "$plugin" ] || continue
  if printf '%s\n' "$INSTALLED_KEYS" | grep -qx "$plugin"; then
    echo "Already installed: $plugin"
    continue
  fi
  echo "Installing $plugin"
  claude plugin install "$plugin" --scope user
done

echo "Plugin sync complete."
