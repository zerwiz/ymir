#!/usr/bin/env bash
# install-role-gate.test.sh — the installer installs ONLY the role's components
# (plan 51 P1, the install half). Behavioural: it runs `--check --role <r>` on
# this host and reads the TOON the installer printed. --check writes nothing, so
# this can run anywhere without touching the runtime or the home.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"
export YMIR_FLEET_REGISTRY="$TMP/fleet.json"
export YMIR_MACHINES_MD="$TMP/home/hodd/data/machines.md"
export YMIR_HOST="box1"
mkdir -p "$TMP/home/hodd/data"
printf '# Machines\n\n' >"$YMIR_MACHINES_MD"
printf '{"heart":"","hosts":{"box1":{"roles":["dev"]}}}\n' >"$YMIR_FLEET_REGISTRY"

run() {  # <role> -> --check TOON
  printf '{"heart":"","hosts":{"box1":{"roles":["%s"]}}}\n' "$1" >"$YMIR_FLEET_REGISTRY"
  timeout 300 bash "$ROOT/bin/engine/ymir-install.sh" --check --role "$1" 2>/dev/null
}
row() { printf '%s\n' "$1" | grep -E "\\\"$2\\\",\\\"$3\\\"" ; }

# ── dev — the harness/seats, and NO heart office ─────────────────────────────
dev="$(run dev)"
printf '%s' "$dev" | grep -q '"record","SKIP","not this machine.s role (heart only)' \
  && ok "dev: the record SKIPs with its reason (no heart office installed)" || bad "dev record: $(printf '%s' "$dev" | grep record)"
printf '%s' "$dev" | grep -q '"local-model","OK"' && ok "dev: the local rail installs" || bad "dev local-model"
printf '%s' "$dev" | grep -q '"omarchy","OK"' && ok "dev: the desktop layer installs" || bad "dev omarchy"

# ── heart — the record services, and NO dev desktop layer ────────────────────
heart="$(run heart)"
printf '%s' "$heart" | grep -q '"record","OK"' && ok "heart: the record stands" || bad "heart record: $(printf '%s' "$heart" | grep record)"
printf '%s' "$heart" | grep -q '"sessrumnir","SKIP","not this machine.s role (dev only)' \
  && ok "heart: the dev desktop layer SKIPs" || bad "heart sessrumnir"
printf '%s' "$heart" | grep -q '"omarchy","SKIP","not this machine.s role (dev only)' \
  && ok "heart: the desktop layer SKIPs" || bad "heart omarchy"
printf '%s' "$heart" | grep -q '"local-model","SKIP","not this machine.s role (forge,dev only)' \
  && ok "heart: the rail SKIPs (heavy serving is the forge's)" || bad "heart local-model"

# ── forge — the rail, and NO desktop / NO record ─────────────────────────────
forge="$(run forge)"
printf '%s' "$forge" | grep -q '"local-model","OK"' && ok "forge: the rail installs" || bad "forge local-model"
printf '%s' "$forge" | grep -q '"omarchy","SKIP","not this machine.s role (dev only)' \
  && ok "forge: the desktop layer SKIPs" || bad "forge omarchy"
printf '%s' "$forge" | grep -q '"record","SKIP","not this machine.s role (heart only)' \
  && ok "forge: the record SKIPs" || bad "forge record"
printf '%s' "$forge" | grep -q '"memory","SKIP","not this machine.s role (heart,dev only)' \
  && ok "forge: the well SKIPs" || bad "forge memory"

# ── hand — nothing persistent ────────────────────────────────────────────────
hand="$(run hand)"
printf '%s' "$hand" | grep -q '"apps","SKIP"' && printf '%s' "$hand" | grep -q '"models","SKIP"' \
  && ok "hand: only the role-neutral core installs" || bad "hand"

# ── an unknown role is refused before anything changes ───────────────────────
bash "$ROOT/bin/engine/ymir-install.sh" --check --role wizard >/dev/null 2>&1 \
  && bad "an unknown --role was accepted" || ok "an unknown --role is refused (exit 2)"

# ── --check writes nothing: the registry is untouched, no card is made ───────
[ "$(cat "$YMIR_FLEET_REGISTRY")" = "$(printf '{"heart":"","hosts":{"box1":{"roles":["hand"]}}}\n')" ] \
  && ok "--check leaves the fleet registry untouched" || bad "registry changed: $(cat "$YMIR_FLEET_REGISTRY")"
grep -q '^## Machine card' "$YMIR_MACHINES_MD" 2>/dev/null \
  && bad "--check wrote a machine card" || ok "--check writes no machine card"

# ── no network at all: the check still completes (plan 51 Part 2.5 rule 7) ──
if command -v unshare >/dev/null 2>&1 && unshare -rn true 2>/dev/null; then
  out="$(unshare -rn bash -c 'ip link set lo up 2>/dev/null; export YMIR_HOME="'"$YMIR_HOME"'" YMIR_FLEET_REGISTRY="'"$YMIR_FLEET_REGISTRY"'" YMIR_MACHINES_MD="'"$YMIR_MACHINES_MD"'" YMIR_HOST=box1; timeout 300 bash "'"$ROOT"'/bin/engine/ymir-install.sh" --check 2>/dev/null | grep -cE "^  ."' 2>/dev/null)"
  [ "${out:-0}" -gt 20 ] && ok "--check completes with no route to any machine ($out rows)" || bad "offline check: $out rows"
else
  printf 'ok - skipped (no unshare for a network namespace)\n'
fi

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
