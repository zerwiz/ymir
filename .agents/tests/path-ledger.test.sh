#!/usr/bin/env bash
# path-ledger.test.sh — Rule 25's ward: a shipped file may not use a superseded path.
#
# Tested against a THROWAWAY tree: a ledger, a stale reference, a clean file, a written
# waiver, and the suffix case (bin/time/x contains bin/x and must NOT be flagged).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$ROOT/bin/gates/guards/path-ledger-guard.sh"
fail=0; ok() { printf 'ok - %s\n' "$1"; }; bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.agents/guards" "$T/RULES" "$T/bin" "$T/tools" "$T/scripts" "$T/config" "$T/apps" "$T/packages" "$T/RULES" "$T/docs" "$T/bin/gates/guards"
cat >"$T/.agents/paths-ledger.yaml" <<'YAML'
moves:
  - old: "bin/old-thing.sh"
    new: "bin/new/thing.sh"
    date: "2026-10-18"
    why: "shelved"
    superseded: true
YAML
printf '#!/usr/bin/env bash\necho bin/old-thing.sh\n' >"$T/bin/stale.sh"
printf '#!/usr/bin/env bash\necho bin/new/thing.sh\n'  >"$T/bin/fresh.sh"
YMIR_GUARD_ROOT="$T" bash "$GUARD" check >/dev/null 2>&1 && bad "a stale reference passed" || ok "a stale reference FAILS the ward"

rm "$T/bin/stale.sh"; printf '#!/usr/bin/env bash\necho bin/new/thing.sh\n' >"$T/bin/fresh.sh"
YMIR_GUARD_ROOT="$T" bash "$GUARD" check >/dev/null 2>&1 && ok "the new path alone passes (the suffix case does not false-positive)" || bad "the new path was flagged"

printf '#!/usr/bin/env bash\necho bin/old-thing.sh  # allow-superseded-path: this line RECORDS the move\n' >"$T/bin/quoted.sh"
YMIR_GUARD_ROOT="$T" bash "$GUARD" check >/dev/null 2>&1 && ok "a written waiver is honoured" || bad "the waiver was refused"

mkdir -p "$T/docs/fixes/gate" && printf 'a note about bin/old-thing.sh\n' >"$T/docs/fixes/gate/x.md"
rm "$T/bin/quoted.sh"
YMIR_GUARD_ROOT="$T" bash "$GUARD" check >/dev/null 2>&1 && ok "history (docs/fixes) is exempt" || bad "the record was flagged"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"; exit "$fail"
