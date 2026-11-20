#!/usr/bin/env bash
# role-lib.test.sh — role capture and component selection (plan 51 P1, the
# install half). Proves the ONE table, the resolution chain (registry → machine
# card → ask → safe body), and that the machine card folds into machines.md
# idempotently and append-only.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"
export YMIR_FLEET_REGISTRY="$TMP/fleet.json"
export YMIR_MACHINES_MD="$TMP/machines.md"
export YMIR_HOST="box1"
mkdir -p "$TMP/home/hodd/data"
printf '{"heart":"","hosts":{}}\n' >"$YMIR_FLEET_REGISTRY"
printf '# Machines\n\n| machine | hostname | role |\n|---|---|---|\n' >"$YMIR_MACHINES_MD"
unset YMIR_ROLE

# shellcheck source=bin/role-lib.sh
. "$ROOT/bin/role-lib.sh"

# ── the ONE component table ─────────────────────────────────────────────────
[ "$(components_for heart)" = "core,record,well,web,mesh" ] && ok "heart owes the record, not the desktop/rail" || bad "heart: $(components_for heart)"
[ "$(components_for forge)" = "core,rail,harness,sandbox" ] && ok "forge owes the rail, not the desktop/record" || bad "forge: $(components_for forge)"
[ "$(components_for hand)" = "core" ] && ok "hand owes only the core" || bad "hand: $(components_for hand)"
case "$(components_for heart,forge)" in *record*rail*) ok "a two-role machine unions its parts" ;; *) bad "union: $(components_for heart,forge)" ;; esac

# ── the resolution chain ────────────────────────────────────────────────────
# establish_roles exports YMIR_ROLE so children agree; clear it between reads.
CHECK=0; ASSUME_YES=0
establish_roles
[ "$ROLE_SET" = dev ] && [ "$ROLE_SRC" = none ] && [ "$ROLE_DEFAULTED" = 1 ] \
  && ok "a host declared nowhere takes the safe BODY (dev), not the union" || bad "missing role: $ROLE_SET/$ROLE_SRC"
case ",$ROLE_COMPONENTS," in *,record,*) bad "the safe body installed a heart office" ;; *) ok "the safe body installs no heart office" ;; esac

bash "$ROOT/bin/role.sh" set box1 forge >/dev/null 2>&1
unset YMIR_ROLE; establish_roles
[ "$ROLE_SET" = forge ] && [ "$ROLE_SRC" = registry ] && ok "the registry answers when it has the host" || bad "registry: $ROLE_SET/$ROLE_SRC"

printf '{"heart":"","hosts":{}}\n' >"$YMIR_FLEET_REGISTRY"
printf '| `box1` | `box1` | **heart** — the record |\n' >>"$YMIR_MACHINES_MD"
unset YMIR_ROLE; establish_roles
[ "$ROLE_SET" = heart ] && [ "$ROLE_SRC" = card ] && ok "the machine card answers when the registry is silent" || bad "card: $ROLE_SET/$ROLE_SRC"

YMIR_ROLE=hand establish_roles
[ "$ROLE_SET" = hand ] && [ "$ROLE_SRC" = env ] && ok "an explicit role wins over every read source" || bad "env: $ROLE_SET/$ROLE_SRC"

# ── the ASK path: a real run, a tty, nothing declared ───────────────────────
printf '{"heart":"","hosts":{}}\n' >"$YMIR_FLEET_REGISTRY"
printf '# Machines\n\n' >"$YMIR_MACHINES_MD"
unset YMIR_ROLE
if command -v script >/dev/null 2>&1; then
  out="$(printf 'f\n' | script -qec "bash -c '. \"$ROOT/bin/role-lib.sh\"; export YMIR_HOME=\"$YMIR_HOME\" YMIR_FLEET_REGISTRY=\"$YMIR_FLEET_REGISTRY\" YMIR_MACHINES_MD=\"$YMIR_MACHINES_MD\" YMIR_HOST=box1; CHECK=0; ASSUME_YES=0; establish_roles; printf \"ROLES=%s SRC=%s COMP=%s\\\\n\" \"\$ROLE_SET\" \"\$ROLE_SRC\" \"\$ROLE_COMPONENTS\"'" /dev/null 2>&1)"
  printf '%s' "$out" | grep -q 'ROLES=forge SRC=declared' \
    && ok "an undeclared role is ASKED on a tty, and the answer is used" || bad "ask path: $out"
else
  printf 'ok - skipped (no script(1) for a pty)\n'
fi

# ── the machine card folds into the ONE registry ────────────────────────────
out="$(machine_card_write box1 heart core,record,well,web,mesh declared)"
[ "$out" = written ] && grep -qxF '## Machine card — box1 (role: heart)' "$YMIR_MACHINES_MD" \
  && ok "the card lands in machines.md" || bad "card write: $out"
out="$(machine_card_write box1 heart core,record,well,web,mesh declared)"
[ "$out" = unchanged ] && ok "a repeat install writes nothing (idempotent)" || bad "idempotence: $out"
out="$(machine_card_write box1 dev core,harness declared)"
[ "$out" = written ] && [ "$(grep -c '^## Machine card — box1' "$YMIR_MACHINES_MD")" = 2 ] \
  && ok "a role change APPENDS a new card (append-only)" || bad "role change: $out"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
