#!/bin/bash
# Tests for home/bin.Darwin/clipboard-bridge, the launchd responder behind the
# clipboard bridge (design: nonreagent/dotfiles,
# docs/superpowers/specs/2026-09-07-clipboard-bridge-design.md). The pasteboard
# is faked: stub osascript/sips/logger binaries on PATH answer the exact
# invocations the script makes, so this runs on Linux CI as well as macOS.
set -euf -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRIDGE="$ROOT/home/bin.Darwin/clipboard-bridge"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/test-clipboard-bridge.XXXXXX")"
BASE="$(cd "$BASE" && pwd)"
trap 'rm -rf "$BASE"' EXIT

pass=0
fail=0
ok()   { pass=$((pass + 1)); echo "PASS: $1"; }
bad()  { fail=$((fail + 1)); echo "FAIL: $1"; }
skip() { echo "SKIP: $1"; }

FAKEBIN="$BASE/bin"
FIXTURE="$BASE/fixture.png"
LOG="$BASE/syslog"
OUT="$BASE/out"
mkdir -p "$FAKEBIN" "$BASE/tmp"

# A 64x64 red PNG built from the spec, so no binary fixture lives in git.
python3 - "$FIXTURE" <<'EOF'
import struct, sys, zlib
w = h = 64
raw = b''.join(b'\x00' + bytes([200, 40, 40]) * w for _ in range(h))
def chunk(t, d):
    return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
open(sys.argv[1], 'wb').write(png)
EOF

# Stub for the two osascript invocations clipboard-bridge makes. FAKE_CLIPBOARD
# selects the pasteboard: png (PNGf+TIFF), tiff (TIFF only), text (no image).
cat > "$FAKEBIN/osascript" <<'EOF'
#!/bin/bash
args="$*"
dest="${args#*POSIX file \"}"; dest="${dest%%\"*}"
case "$args" in
  *"clipboard info"*)
    case "$FAKE_CLIPBOARD" in
      png)  echo '{{«class PNGf», 1234}, {«class TIFF», 5678}}' ;;
      tiff) echo '{{«class TIFF», 5678}, {«class PDF », 42}}' ;;
      denied) echo 'execution error: Not authorized to send Apple events. (-1743)' >&2; exit 1 ;;
      *)    echo '{{«class utf8», 12}, {string, 12}}' ;;
    esac ;;
  *"class PNGf"*)
    [ "$FAKE_CLIPBOARD" = png ] || { echo "execution error: Can't make some data into the expected type. (-1700)" >&2; exit 1; }
    cat "$FAKE_FIXTURE" > "$dest" ;;
  *"class TIFF"*)
    case "$FAKE_CLIPBOARD" in png|tiff) ;; *) exit 1 ;; esac
    printf 'not-a-png-yet' > "$dest" ;;
  *) echo "unexpected osascript call: $args" >&2; exit 2 ;;
esac
EOF

# Stub: `sips -s format png <in> --out <out>` becomes "write the fixture to <out>",
# but only when <in> (the first argument naming an existing file) is non-empty,
# so a broken TIFF write path fails the test instead of passing unnoticed.
cat > "$FAKEBIN/sips" <<'EOF'
#!/bin/bash
in=""; out=""; prev=""
for a in "$@"; do
  [ "$prev" = "--out" ] && out="$a"
  [ -z "$in" ] && [ -f "$a" ] && in="$a"
  prev="$a"
done
[ -n "$out" ] || out="${!#}"
[ -s "$in" ] || exit 1
cat "$FAKE_FIXTURE" > "$out"
EOF

# Stub: syslog becomes a file we can grep.
cat > "$FAKEBIN/logger" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_LOG"
EOF
chmod +x "$FAKEBIN/osascript" "$FAKEBIN/sips" "$FAKEBIN/logger"

# bridge <clipboard-mode> <stdin-bytes>: run the script the way launchd does
# (request on stdin, response on stdout). Captures stdout in $OUT, exit in $status.
bridge() {
  set +e
  printf '%s' "$2" | FAKE_CLIPBOARD="$1" FAKE_FIXTURE="$FIXTURE" FAKE_LOG="$LOG" \
    PATH="$FAKEBIN:$PATH" TMPDIR="$BASE/tmp" "$BRIDGE" > "$OUT"
  status=$?
  set -e
}

test_script_is_executable() {
  if [ -x "$BRIDGE" ]; then ok "clipboard-bridge is executable"; else bad "clipboard-bridge is executable"; fi
}

test_types_reports_png_when_image_present() {
  bridge png $'types\n'
  if [ "$status" = 0 ] && [ "$(cat "$OUT")" = "image/png" ]; then
    ok "types reports image/png for a PNG pasteboard"
  else
    bad "types reports image/png for a PNG pasteboard (status=$status out=$(cat "$OUT"))"
  fi
}

test_types_reports_png_for_tiff_only() {
  bridge tiff $'types\n'
  if [ "$status" = 0 ] && [ "$(cat "$OUT")" = "image/png" ]; then
    ok "types reports image/png for a TIFF-only pasteboard"
  else
    bad "types reports image/png for a TIFF-only pasteboard (status=$status out=$(cat "$OUT"))"
  fi
}

test_types_is_silent_for_text() {
  bridge text $'types\n'
  if [ "$status" = 0 ] && [ ! -s "$OUT" ]; then
    ok "types prints nothing for a text pasteboard"
  else
    bad "types prints nothing for a text pasteboard (status=$status out=$(cat "$OUT"))"
  fi
}

test_types_logs_a_failed_pasteboard_read() {
  : > "$LOG"
  bridge denied $'types\n'
  if [ "$status" = 0 ] && [ ! -s "$OUT" ] && grep -q 'clipboard info failed' "$LOG"; then
    ok "a failed pasteboard read is logged, not reported as no image"
  else
    bad "a failed pasteboard read is logged, not reported as no image (status=$status)"
  fi
}

test_png_streams_the_image() {
  bridge png $'png\n'
  if [ "$status" = 0 ] && cmp -s "$OUT" "$FIXTURE"; then
    ok "png streams the pasteboard image byte for byte"
  else
    bad "png streams the pasteboard image byte for byte (status=$status)"
  fi
}

test_png_converts_tiff_via_sips() {
  bridge tiff $'png\n'
  if [ "$status" = 0 ] && cmp -s "$OUT" "$FIXTURE"; then
    ok "png falls back to TIFF plus sips"
  else
    bad "png falls back to TIFF plus sips (status=$status)"
  fi
}

test_png_fails_closed_without_image() {
  bridge text $'png\n'
  if [ "$status" = 1 ] && [ ! -s "$OUT" ]; then
    ok "png with no image exits 1 and writes nothing"
  else
    bad "png with no image exits 1 and writes nothing (status=$status)"
  fi
}

test_unknown_request_is_refused_and_logged() {
  : > "$LOG"
  bridge png $'rm -rf /\n'
  if [ "$status" = 1 ] && [ ! -s "$OUT" ] && grep -q 'unknown request' "$LOG"; then
    ok "unknown request exits 1, writes nothing, logs"
  else
    bad "unknown request exits 1, writes nothing, logs (status=$status)"
  fi
}

test_crlf_request_is_accepted() {
  bridge png $'types\r\n'
  if [ "$status" = 0 ] && [ "$(cat "$OUT")" = "image/png" ]; then
    ok "a CRLF-terminated request is accepted"
  else
    bad "a CRLF-terminated request is accepted (status=$status)"
  fi
}

test_no_request_times_out() {
  set +e
  (sleep 2) | CLIPBOARD_BRIDGE_READ_TIMEOUT=1 FAKE_CLIPBOARD=png FAKE_FIXTURE="$FIXTURE" FAKE_LOG="$LOG" \
    PATH="$FAKEBIN:$PATH" TMPDIR="$BASE/tmp" "$BRIDGE" > "$OUT"
  status=$?
  set -e
  if [ "$status" = 1 ] && [ ! -s "$OUT" ]; then
    ok "a silent client is dropped after the read timeout"
  else
    bad "a silent client is dropped after the read timeout (status=$status)"
  fi
}

test_no_temp_file_left_behind() {
  if [ -z "$(ls -A "$BASE/tmp")" ]; then
    ok "png requests leave no temp files"
  else
    bad "png requests leave no temp files ($(ls -A "$BASE/tmp"))"
  fi
}

test_plist_declares_socket_activation() {
  local plist="$ROOT/home/Library/LaunchAgents/org.nonrational.clipboard-bridge.plist"
  if [ -f "$plist" ] && python3 - "$plist" <<'EOF'
import plistlib, sys
d = plistlib.load(open(sys.argv[1], 'rb'))
l = d['Sockets']['Listener']
assert d['Label'] == 'org.nonrational.clipboard-bridge', d['Label']
assert d['ProgramArguments'][:2] == ['/bin/sh', '-c'], d['ProgramArguments']
assert 'clipboard-bridge' in d['ProgramArguments'][2], d['ProgramArguments']
assert l['SockNodeName'] == '127.0.0.1' and l['SockServiceName'] == '2224', l
assert l['SockType'] == 'stream' and l['SockFamily'] == 'IPv4', l
assert d['inetdCompatibility']['Wait'] is False, d['inetdCompatibility']
assert 'RunAtLoad' not in d and 'KeepAlive' not in d, sorted(d)
EOF
  then
    ok "plist declares loopback socket activation, inetd-style, no idle process"
  else
    bad "plist declares loopback socket activation, inetd-style, no idle process"
  fi
}

test_manifest_deploys_the_plist_on_darwin() {
  if grep -qE '^home/Library/LaunchAgents/org\.nonrational\.clipboard-bridge\.plist[[:space:]]+~/Library/LaunchAgents/org\.nonrational\.clipboard-bridge\.plist[[:space:]]+os=Darwin[[:space:]]*$' "$ROOT/manifest"; then
    ok "manifest deploys the plist on Darwin only"
  else
    bad "manifest deploys the plist on Darwin only"
  fi
}

test_ssh_include_forwards_the_bridge_port() {
  local conf="$ROOT/home/.ssh/config.d/exe.conf" got
  if ! command -v ssh >/dev/null 2>&1; then skip "ssh include (ssh not installed)"; return; fi
  if [ ! -f "$conf" ]; then bad "ssh include forwards 2224 and shares connections for *.exe.xyz only"; return; fi
  got="$(ssh -G -F "$conf" example.exe.xyz 2>/dev/null)" || got=""
  if grep -qE '^remoteforward \[?127\.0\.0\.1\]?:2224 \[?127\.0\.0\.1\]?:2224$' <<<"$got" \
      && grep -qx 'controlmaster auto' <<<"$got" \
      && grep -qx 'controlpersist 14400' <<<"$got" \
      && grep -qx 'serveraliveinterval 30' <<<"$got" \
      && grep -qx 'exitonforwardfailure no' <<<"$got" \
      && ! ssh -G -F "$conf" example.com 2>/dev/null | grep -q '^remoteforward'; then
    ok "ssh include forwards 2224 and shares connections for *.exe.xyz only"
  else
    bad "ssh include forwards 2224 and shares connections for *.exe.xyz only"
  fi
}

test_manifest_deploys_the_ssh_include_on_darwin() {
  if grep -qE '^home/\.ssh/config\.d/exe\.conf[[:space:]]+~/\.ssh/config\.d/exe\.conf[[:space:]]+os=Darwin[[:space:]]*$' "$ROOT/manifest"; then
    ok "manifest deploys the ssh include on Darwin only"
  else
    bad "manifest deploys the ssh include on Darwin only"
  fi
}

test_script_is_executable
test_types_reports_png_when_image_present
test_types_reports_png_for_tiff_only
test_types_is_silent_for_text
test_types_logs_a_failed_pasteboard_read
test_png_streams_the_image
test_png_converts_tiff_via_sips
test_png_fails_closed_without_image
test_unknown_request_is_refused_and_logged
test_crlf_request_is_accepted
test_no_request_times_out
test_no_temp_file_left_behind
test_plist_declares_socket_activation
test_manifest_deploys_the_plist_on_darwin
test_ssh_include_forwards_the_bridge_port
test_manifest_deploys_the_ssh_include_on_darwin

echo "----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
