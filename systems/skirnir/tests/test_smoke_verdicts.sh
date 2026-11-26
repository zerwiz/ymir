#!/usr/bin/env bash
# test_smoke_verdicts.sh — a check books ONE verdict, quiet or not; a squatted voice port is named.
#
# THE FAULT THIS PROVES GONE (measured 2026-11-26): the nightly row runs `smoke.sh --quiet`, where
# `ok()` returned non-zero, so every `test && ok … || bad …` that PASSED was also booked as a failure —
# about ten false failures a day. And a stray web server on the voice's port read as "the voice answers".
#
# Usage: bash systems/skirnir/tests/test_smoke_verdicts.sh
set -u
HERE="$(CDPATH='' dirname "${BASH_SOURCE[0]}")"
ROOT="$(realpath "$HERE/../../..")"
SMOKE="$ROOT/systems/skirnir/services/smoke.sh"
pass=0; fail=0
t_ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
t_bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
echo "test_smoke_verdicts"

# the verdict functions, lifted from the door itself
defs="$(sed -n '/^PASS=0; SKIP=0; FAIL=0$/,/^bad()/p' "$SMOKE")"
for q in 0 1; do
  got="$(QUIET=$q bash -c "$defs
    true && ok a || bad a x
    true && skip b why || bad b x
    printf '\n%s %s %s' \$PASS \$SKIP \$FAIL" 2>/dev/null | tail -n 1)"
  if [ "$got" = "1 1 0" ]; then t_ok "one verdict per check (QUIET=$q)"; else t_bad "QUIET=$q booked: $got"; fi
done

# a program that is not kokoro, holding the port, is named
T="$(mktemp -d)"; srv=""
trap '[ -n "$srv" ] && kill "$srv" 2>/dev/null; rm -rf "$T"' EXIT
python3 -c 'import socket,sys,time
s=socket.socket(); s.bind(("127.0.0.1",0)); s.listen()
open(sys.argv[1],"w").write(str(s.getsockname()[1])); time.sleep(30)' "$T/port" &
srv=$!
for _ in $(seq 1 50); do [ -s "$T/port" ] && break; sleep 0.1; done
if command -v ss >/dev/null 2>&1; then
  said="$(KOKORO_SERVICE_URL="http://127.0.0.1:$(cat "$T/port")" \
          bash -c '. "$1/bin/voice/kokoro-lib.sh"; kokoro_port_squatter' _ "$ROOT")"
  case "$said" in *"pid $srv "*) t_ok "the squatter is named by pid" ;; *) t_bad "squatter not named: $said" ;; esac
else
  printf '  skip the squatter check — no ss here\n'
fi

printf 'test_smoke_verdicts: %d ok · %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
