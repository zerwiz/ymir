#!/usr/bin/env bash
# test_guards_inherited.sh — a ward's finding is OURS only when it names OUR copy of the path.
#
# Measured 2026-11-14: two pull requests (#747, #754) were refused because `runtime-pinned-guard` named
# `queue-warden.service → /home/<seat>/ymir/.yggdrasil/queue-warden-review/bin/forge/queue-warden.sh`, and
# `inherited()` matched the changed path `bin/forge/queue-warden.sh` as a SUBSTRING of that neighbour checkout's
# path. Both branches were refused for a fault that belonged to the machine's units, not to them.
#
# The decision under test, in one line: a path is a whole token — "$ROOT/<path>" absolute, or the path standing
# alone — never a tail of a longer path.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GUARDS="$ROOT/bin/gates/guards.sh"
[ -r "$GUARDS" ] || { printf 'FAIL no %s\n' "$GUARDS"; exit 1; }

# the function, exactly as the gate defines it
eval "$(sed -n '/^inherited() {/,/^}$/p' "$GUARDS")"
is_scoped() { return 0; }        # not in the SCOPED list
SCOPE_COUNT=0

ok=0; fail=0
good() { ok=$((ok+1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
CHANGED_LIST="$T/changed"
printf 'bin/forge/queue-warden.sh\n' >"$CHANGED_LIST"

# 1. a NEIGHBOUR checkout's copy is not ours — the exact finding that refused two PRs
neighbour="  \"a unit runs a working tree\",\"queue-warden.service → /home/seat/ymir/.yggdrasil/queue-warden-review/bin/forge/queue-warden.sh (working tree)\""
if inherited runtime-pinned-guard.sh "$neighbour"; then good 'a neighbour checkout’s copy is INHERITED, not ours'
else bad 'a neighbour checkout’s copy is INHERITED, not ours'; fi

# 2. an absolute path that IS this checkout's copy is ours
ours="  \"a unit runs a working tree\",\"pr-watch.service → $ROOT/bin/forge/queue-warden.sh (working tree)\""
if inherited runtime-pinned-guard.sh "$ours"; then bad 'our own absolute path is OURS (would have been missed)'
else good 'our own absolute path is OURS'; fi

# 3. a relative path standing alone is ours (the shape defaults-guard prints)
rel='  "a home guessed","bin/forge/queue-warden.sh","42","HOME_DIR=..."'
if inherited defaults-guard.sh "$rel"; then bad 'a relative path token is OURS (would have been missed)'
else good 'a relative path token is OURS'; fi

# 4. a relative path inside a longer path is NOT ours (the regression this test exists for)
deep='  "x","some/other/tree/bin/forge/queue-warden.sh:9","y"'
if inherited defaults-guard.sh "$deep"; then good 'a relative path buried in a longer path is INHERITED'
else bad 'a relative path buried in a longer path is INHERITED'; fi

# 5. an unrelated finding is inherited, and says so
if inherited cron-guard.sh '  "cron-guard: 5 referenced script(s) do not ship in the repo"'; then
  good 'an unrelated finding is INHERITED'
else bad 'an unrelated finding is INHERITED'; fi

printf '\nguards-inherited: %s ok, %s failed\n' "$ok" "$fail"
[ "$fail" = 0 ]
