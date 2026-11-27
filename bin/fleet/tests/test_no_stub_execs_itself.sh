#!/usr/bin/env bash
# test_no_stub_execs_itself.sh — no forwarding stub may exec its own path (2026-11-27: bin/fleet/role.sh was
# overwritten by the stub that points at it, so every arm daemon looped in exec and never wrote its lease).
set -u
ROOT="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 2
fail=0; n=0
while IFS= read -r f; do
  t="$(grep -oE 'exec "\$_d/[^"]+"' "$f" | head -1 | sed -E 's/exec "\$_d\/([^"]+)"/\1/')"
  [ -n "$t" ] || continue
  n=$((n+1))
  r="$(realpath -m --relative-to=. "$(dirname "$f")/$t")"
  if [ "$r" = "$f" ]; then printf 'FAIL %s execs itself\n' "$f"; fail=1; fi
done < <(git ls-files '*.sh')
[ "$n" -gt 0 ] || { echo "FAIL no forwarding stubs found — the scan read nothing"; exit 1; }
timeout 20 bash bin/fleet/role.sh --help >/dev/null 2>&1 || { echo "FAIL bin/fleet/role.sh --help did not return in 20 s"; fail=1; }
[ "$fail" = 0 ] && echo "test_no_stub_execs_itself: PASS ($n stubs checked)" || echo "test_no_stub_execs_itself: FAIL"
exit "$fail"
