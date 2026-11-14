#!/usr/bin/env bash
# test_unit_path_shims.sh — every house unit's PATH can reach the house's tools.
#
# WHY THIS EXISTS (plan 275 item 26, measured 2026-11-14 03:55): the Sága digest drawn
# INSIDE the gate answered `error: gh is not installed — the PR list cannot be read`, while
# `gh --version` answered in every shell. `gh` is installed under mise
# (`~/.local/share/mise/shims/gh`), and the gate's unit carried
# `Environment=PATH=%h/.bun/bin:/usr/bin:/bin` — a PATH that stops short of the shims. The
# same fault reached the digest's other readers, so the fix is every house unit, not one.
#
# The claim this test holds: every shipped unit template that sets a PATH names a place
# where a mise-installed tool answers, and the shims come AFTER the system directories so a
# system binary still wins.
#
# Usage: test_unit_path_shims.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

printf 'unit PATH — the house’s tools are reachable\n'

files=()
for f in "$ROOT"/tools/web/systemd/*.service "$ROOT"/tools/mill/systemd/*.service \
         "$ROOT"/tools/skills-mcp/systemd/*.service; do
  [ -f "$f" ] || continue
  grep -q '^Environment=PATH=' "$f" || continue
  files+=("$f")
done

if [ "${#files[@]}" -eq 0 ]; then
  bad "house unit templates found" "none carry Environment=PATH= — the probe found nothing to judge"
else
  ok "${#files[@]} house unit templates carry a PATH"
fi

shimfail=0
for f in "${files[@]}"; do
  line="$(grep -m1 '^Environment=PATH=' "$f")"
  val="${line#Environment=PATH=}"
  case "$val" in
    *%h/.local/share/mise/shims*) ;;
    *) shimfail=$((shimfail+1)); bad "$(basename "$f") names the mise shims" "$val" ;;
  esac
done
[ "$shimfail" -eq 0 ] && ok "every house unit's PATH reaches the mise shims"

# The shims must not outrank /usr/bin: a mise shim placed first shadows every system tool
# (a shimmed python3 or git in front of the system one is a second, invisible interpreter).
rankfail=0
for f in "${files[@]}"; do
  val="$(grep -m1 '^Environment=PATH=' "$f")"; val="${val#Environment=PATH=}"
  case "$val" in
    *mise/shims*/usr/bin*) rankfail=$((rankfail+1)) ;;
  esac
done
[ "$rankfail" -eq 0 ] && ok "the shims sit after /usr/bin, so a system binary still wins"

# The two doors the digest complained about, named on their own: a future edit that drops
# the shims from one of them fails here with the file's own name.
for f in "$ROOT/tools/web/systemd/hlidskjalf-gate.service" "$ROOT/tools/web/systemd/bifrost.service"; do
  if grep -q '^Environment=PATH=.*mise/shims' "$f" 2>/dev/null; then
    ok "$(basename "$f") names the mise shims"
  else
    bad "$(basename "$f") names the mise shims" "the gate and the bridge are where it was measured"
  fi
done

printf 'unit PATH: %s ok / %s fail\n' "$pass" "$fail"
[ "$fail" = 0 ]
