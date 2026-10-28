#!/bin/bash
# Tests for home/.config/kitty/fish-shell.sh, the script kitty.conf includes
# through `geninclude`. It must print the `shell` line only when fish is
# executable and exit 0 either way, so a Mac without fish keeps its default shell.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/home/.config/kitty/fish-shell.sh"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-kitty.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT

pass=0
fail=0
ok()  { pass=$((pass + 1)); echo "PASS: $1"; }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

printf '#!/bin/sh\nexit 0\n' >"$BASE/fish"
chmod +x "$BASE/fish"

got="$(FISH_BIN="$BASE/fish" "$SCRIPT")"
if [ "$got" = "shell $BASE/fish --login --interactive" ]; then
  ok "prints the shell line when fish is executable"
else
  bad "prints the shell line when fish is executable (got: $got)"
fi

set +e
got="$(FISH_BIN="$BASE/missing" "$SCRIPT" 2>&1)"
rc=$?
set -e
if [ -z "$got" ] && [ "$rc" -eq 0 ]; then
  ok "prints nothing and exits 0 when fish is missing"
else
  bad "prints nothing and exits 0 when fish is missing (status $rc, got: $got)"
fi

if grep -qx 'geninclude fish-shell.sh' "$ROOT/home/.config/kitty/kitty.conf"; then
  ok "kitty.conf includes the script through geninclude"
else
  bad "kitty.conf includes the script through geninclude"
fi

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
