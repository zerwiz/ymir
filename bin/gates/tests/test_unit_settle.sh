#!/usr/bin/env bash
# test_unit_settle.sh — plan 272 fault 12: no old checkout can re-point a pinned unit.
# Before: garmr.sh rendered `garmr-brain` against whatever tree it ran from when no pin directory existed, and nothing
# settled the unit through the register. Now every unit writer settles through the PIN's units.sh, and a guard names
# any writer that does not.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

# ── the settle step runs the PIN's writer, never the caller's tree ──
mkdir -p "$T/hm/pin/bin/engine" "$T/tree/bin/engine"
printf '#!/usr/bin/env bash\nprintf "pin %%s\\n" "$*" >>"%s/calls"\n' "$T" >"$T/hm/pin/bin/engine/units.sh"
printf '#!/usr/bin/env bash\nprintf "TREE %%s\\n" "$*" >>"%s/calls"\n' "$T" >"$T/tree/bin/engine/units.sh"
chmod +x "$T/hm/pin/bin/engine/units.sh" "$T/tree/bin/engine/units.sh"
. "$ROOT/bin/engine/unit-settle-lib.sh"
HOME="$T/h" YMIR_RUNTIME_DIR="$T/hm/pin" unit_settle garmr-brain >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && grep -q '^pin write garmr-brain --no-restart' "$T/calls" && ok "unit_settle runs the pin's units.sh with the unit's name and no restart" || bad "pin call: $(cat "$T/calls" 2>&1)"
grep -q TREE "$T/calls" 2>/dev/null && bad "the caller's own tree ran" || ok "the calling tree's units.sh is never the one run"
err="$(HOME="$T/h" YMIR_RUNTIME_DIR="$T/none" unit_settle garmr-brain 2>&1 >/dev/null)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$err" | grep -q 'no pinned runtime is seated' && ok "with no pin seated it says so and writes nothing" || bad "no pin: rc=$rc $err"

# ── garmr no longer falls back to the working tree ──
grep -q 'unit_root="\$ROOT"' "$ROOT/bin/ward/garmr.sh" && bad "garmr.sh still falls back to its own tree" || ok "garmr.sh has no fallback to its own tree for a unit root"
grep -q 'unit_settle garmr-brain' "$ROOT/bin/ward/garmr.sh" && ok "garmr.sh settles garmr-brain through the register" || bad "garmr.sh does not settle"

# ── the guard names a writer that bypasses the register ──
mkdir -p "$T/repo/bin/gates/guards" "$T/repo/bin/x" "$T/repo/config"
cp "$ROOT/bin/gates/guards/unit-writer-guard.sh" "$T/repo/bin/gates/guards/"
git -C "$T/repo" init -q
printf '#!/usr/bin/env bash\ncat > "$HOME/.config/systemd/user/thing.service" <<EOF\n[Service]\nEOF\n' >"$T/repo/bin/x/rogue.sh"
git -C "$T/repo" add . >/dev/null 2>&1
out="$(bash "$T/repo/bin/gates/guards/unit-writer-guard.sh" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'bin/x/rogue.sh' && ok "a writer that bypasses the register is named and refused" || bad "rogue not named: $out"
printf 'bin/x/rogue.sh\tengine-owned unit, not a Ymir tree unit\n' >"$T/repo/config/unit-writers-allow.txt"
git -C "$T/repo" add . >/dev/null 2>&1
bash "$T/repo/bin/gates/guards/unit-writer-guard.sh" >/dev/null 2>&1 && ok "a writer allowed with a reason passes" || bad "allowed writer refused"
printf 'bin/x/rogue.sh\t\n' >"$T/repo/config/unit-writers-allow.txt"
bash "$T/repo/bin/gates/guards/unit-writer-guard.sh" >/dev/null 2>&1 && bad "an allowance with no reason was honoured" || ok "an allowance with no reason is ignored"
printf '. x/unit-settle-lib.sh; unit_settle thing\n' >>"$T/repo/bin/x/rogue.sh"; git -C "$T/repo" add . >/dev/null 2>&1
bash "$T/repo/bin/gates/guards/unit-writer-guard.sh" >/dev/null 2>&1 && ok "the same writer passes once it settles through the register" || bad "settled writer refused"
# the real tree is clean
bash "$ROOT/bin/gates/guards/unit-writer-guard.sh" >/dev/null 2>&1 && ok "every unit writer in this tree settles through the register" || bad "the tree has an unsettled unit writer"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
