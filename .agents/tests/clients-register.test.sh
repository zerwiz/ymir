#!/usr/bin/env bash
# clients-register.test.sh — plan 128, phases 1–4: a company we SERVE is never filed as one we ARE.
#
# The contract this proves, each part on a throwaway home (never the operator's):
#   1. a place whose company is a CLIENT is accepted ONLY when client_of names a house,
#      and is refused with a sentence naming the missing field otherwise;
#   2. a place that says whose client it is, beside no register, is refused naming the file;
#   3. projects.yaml's optional `client:` resolves against the register or is refused;
#   4. the register's own shape is checked loudly;
#   5. ymir-install.sh --check is a RED (exit 1, a FAIL row) when a place's client_of
#      cannot be resolved — absent is not a shrug;
#   6. migration 0013 seeds the register when absent, never edits one it finds, and is
#      idempotent (pending → applied → nothing to do);
#   7. the templates are ONE source: no inline heredoc writes projects.yaml.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PV="$ROOT/bin/identity/place-validate.sh"
CL="$ROOT/bin/identity/clients.sh"
PJ="$ROOT/bin/identity/projects-validate.sh"
INSTALL="$ROOT/bin/engine/ymir-install.sh"
MIGRATE="$ROOT/bin/engine/ymir-migrate.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s — %s\n' "$1" "${2-}"; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
H="$T/home"; ID="$H/hodd/identity"
mkdir -p "$ID/places/opticat/projects" "$ID/places/wayof/projects" "$H/state"
printf 'version: 1\ncompanies:\n  - id: wayof\n    name: WayOf\n' > "$ID/companies.yaml"
printf 'version: 1\nclients:\n  - id: opticat\n    name: OptiCat\n    state: active\n    served_by: wayof\n' > "$ID/clients.yaml"
printf 'place: opticat/projects\nclient_of: wayof\n' > "$ID/places/opticat/projects/place.yaml"
printf 'place: wayof/projects\n' > "$ID/places/wayof/projects/place.yaml"
export YMIR_HOME="$H"

# ── 1. the relation: client_of is required of a client's place ────────────────
YMIR_HOME="$H" bash "$PV" --all >/dev/null 2>&1 \
  && ok "a client place that names its serving house is accepted" \
  || bad "a client place that names its serving house is accepted"

printf 'place: opticat/projects\n' > "$ID/places/opticat/projects/place.yaml"
out="$(YMIR_HOME="$H" bash "$PV" --all 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "a client place with no client_of is REFUSED" || bad "a client place with no client_of is REFUSED" "rc=$rc"
printf '%s' "$out" | grep -q "declares no client_of" \
  && ok "…and the refusal names the missing field" || bad "…and the refusal names the missing field" "$out"

printf 'place: opticat/projects\nclient_of: nowhere\n' > "$ID/places/opticat/projects/place.yaml"
YMIR_HOME="$H" bash "$PV" --all >/dev/null 2>&1 \
  && bad "a client_of naming no house is refused" "it passed" \
  || ok "a client_of naming no house is refused"

# ── 2. a place that names a client beside no register is a refusal ────────────
printf 'place: opticat/projects\nclient_of: wayof\n' > "$ID/places/opticat/projects/place.yaml"
mv "$ID/clients.yaml" "$T/clients.yaml.bak"
out="$(YMIR_HOME="$H" bash "$PV" --all 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "an absent register beside a client place is REFUSED" || bad "an absent register beside a client place is REFUSED" "rc=$rc"
printf '%s' "$out" | grep -q 'clients.yaml' \
  && ok "…and the refusal names the register file" || bad "…and the refusal names the register file" "$out"
printf 'place: wayof/projects\n' > "$ID/places/opticat/projects/place.yaml"
YMIR_HOME="$H" bash "$PV" --all >/dev/null 2>&1 \
  && ok "a shelf of houses resolves with no register at all" || bad "a shelf of houses resolves with no register at all"
printf 'place: opticat/projects\nclient_of: wayof\n' > "$ID/places/opticat/projects/place.yaml"
mv "$T/clients.yaml.bak" "$ID/clients.yaml"

# ── 3. projects.yaml's optional client: field ─────────────────────────────────
printf 'version: 1\nprojects:\n  - id: ovk\n    name: OVK\n    client: opticat\n  - id: ymir\n    name: Ymir\n' > "$ID/projects.yaml"
YMIR_HOME="$H" bash "$PJ" >/dev/null 2>&1 \
  && ok "a project's client: resolves against the register" || bad "a project's client: resolves against the register"
printf 'version: 1\nprojects:\n  - id: ovk\n    name: OVK\n    client: nobody\n' > "$ID/projects.yaml"
out="$(YMIR_HOME="$H" bash "$PJ" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "a project's client: that names nobody is REFUSED" || bad "a project's client: that names nobody is REFUSED" "rc=$rc"
printf '%s' "$out" | grep -q 'client=' \
  && ok "…and the refusal names the field" || bad "…and the refusal names the field" "$out"

# ── 4. the register's own shape ───────────────────────────────────────────────
YMIR_HOME="$H" bash "$CL" validate >/dev/null 2>&1 \
  && ok "a well-shaped register validates" || bad "a well-shaped register validates"
printf 'version: 1\nclients:\n  - id: opticat\n    name: OptiCat\n    state: invented\n    served_by: wayof\n' > "$ID/clients.yaml"
out="$(YMIR_HOME="$H" bash "$CL" validate 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "a register with an invented state is REFUSED" || bad "a register with an invented state is REFUSED" "rc=$rc"
printf '%s' "$out" | grep -q 'state' && ok "…and the refusal names the field" || bad "…and the refusal names the field" "$out"
printf 'version: 1\nclients:\n  - id: opticat\n    name: OptiCat\n    state: active\n    served_by: wayof\n' > "$ID/clients.yaml"

# ── 5. the install's check mode is a RED, not a shrug ─────────────────────────
if command -v timeout >/dev/null 2>&1; then TO="timeout 600"; else TO=""; fi
good="$($TO env YMIR_HOME="$H" bash "$INSTALL" --check 2>/dev/null | grep '"clients"')"
printf '%s' "$good" | grep -q '"clients","OK"' \
  && ok "install --check reports the resolved register" || bad "install --check reports the resolved register" "$good"
printf 'place: opticat/projects\n' > "$ID/places/opticat/projects/place.yaml"
row="$($TO env YMIR_HOME="$H" bash "$INSTALL" --check 2>/dev/null | grep '"clients"')"
printf '%s' "$row" | grep -q '"clients","FAIL"' \
  && ok "install --check is a RED when a place's client_of cannot be resolved" \
  || bad "install --check is a RED when a place's client_of cannot be resolved" "$row"
printf '%s' "$row" | grep -q 'opticat/projects/place.yaml' \
  && ok "…and the red names the file" || bad "…and the red names the file" "$row"
$TO env YMIR_HOME="$H" bash "$INSTALL" --check >/dev/null 2>&1
[ "$?" -ne 0 ] && ok "…and the install exits non-zero" || bad "…and the install exits non-zero"
printf 'place: opticat/projects\nclient_of: wayof\n' > "$ID/places/opticat/projects/place.yaml"

# ── 6. migration 0013 — create, never edit, idempotent ────────────────────────
SEED="$T/mig"; mkdir -p "$SEED/home/hodd/identity" "$SEED/home/state"
# Everything but 0013 already applied, so the proof runs 0013 alone.
ls "$ROOT/.agents/migrations"/[0-9][0-9][0-9][0-9]-*.sh | xargs -n1 basename | sed 's/\.sh$//' \
  | grep -v '^0013-' > "$SEED/home/state/migrations"
st="$($TO env YMIR_HOME="$SEED/home" bash "$MIGRATE" status 2>&1 | grep '0013')"
printf '%s' "$st" | grep -q '"pending"' && ok "0013 shows PENDING on a home without the register" \
  || bad "0013 shows PENDING on a home without the register" "$st"
YMIR_HOME="$SEED/home" bash "$MIGRATE" apply >/dev/null 2>&1
[ -f "$SEED/home/hodd/identity/clients.yaml" ] && ok "a real run seeds the register from the template" \
  || bad "a real run seeds the register from the template"
printf 'version: 1\nclients:\n  - id: mine\n    name: Mine\n    state: active\n    served_by: wayof\n' \
  > "$SEED/home/hodd/identity/clients.yaml"
run="$($TO env YMIR_HOME="$SEED/home" bash "$MIGRATE" apply 2>&1)"
printf '%s' "$run" | grep -q '"apply",0,' && ok "a second apply has nothing to do" \
  || bad "a second apply has nothing to do" "$run"
grep -q 'id: mine' "$SEED/home/hodd/identity/clients.yaml" \
  && ok "an existing register is never edited by the migration" || bad "an existing register is never edited by the migration"
YMIR_HOME="$SEED/home" bash "$ROOT/.agents/migrations/0013-clients-register.sh" 2>&1 | grep -q 'nothing touched' \
  && ok "…and it says why it did nothing" || bad "…and it says why it did nothing"

# ── 7. one template shelf, no second source ──────────────────────────────────
[ -f "$ROOT/registry/clients.yaml.example" ] && ok "registry/clients.yaml.example ships" \
  || bad "registry/clients.yaml.example ships"
[ -f "$ROOT/registry/companies.yaml.example" ] && ok "registry/companies.yaml.example ships" \
  || bad "registry/companies.yaml.example ships"
n="$(ls -1 "$ROOT"/registry/projects.yaml.example 2>/dev/null | wc -l)"
[ "$n" = 1 ] && ok "exactly one project template on the shelf" || bad "exactly one project template on the shelf" "found $n"
grep -qE "cat *>.*identity/projects\.yaml" "$INSTALL" \
  && bad "no heredoc writes projects.yaml any more" "a heredoc is still there" \
  || ok "no heredoc writes projects.yaml any more"
grep -q 'cp "$ROOT/registry/projects.yaml.example"' "$INSTALL" \
  && ok "…the installer copies the template instead" || bad "…the installer copies the template instead"

# ── 8. the install's seeding door — one copy, an existing register untouched ──
SEEDR="$T/seed"; mkdir -p "$SEEDR/home"
out="$(YMIR_HOME="$SEEDR/home" bash "$ROOT/bin/identity/registers-seed.sh" 2>&1)"
if [ -f "$SEEDR/home/hodd/identity/clients.yaml" ] && [ -f "$SEEDR/home/hodd/identity/companies.yaml" ]; then
  ok "registers-seed.sh seeds both registers from the templates"
else
  bad "registers-seed.sh seeds both registers from the templates" "$out"
fi
printf 'version: 1\nclients:\n  - id: mine\n    name: Mine\n    state: active\n    served_by: wayof\n' \
  > "$SEEDR/home/hodd/identity/clients.yaml"
out="$(YMIR_HOME="$SEEDR/home" bash "$ROOT/bin/identity/registers-seed.sh" 2>&1)"
printf '%s' "$out" | grep -q 'nothing touched' \
  && ok "a second seed says nothing to do" || bad "a second seed says nothing to do" "$out"
grep -q 'id: mine' "$SEEDR/home/hodd/identity/clients.yaml" \
  && ok "…and it never overwrites a register the operator wrote" \
  || bad "…and it never overwrites a register the operator wrote"
rm -f "$SEEDR/home/hodd/identity/clients.yaml"
YMIR_HOME="$SEEDR/home" bash "$ROOT/bin/identity/registers-seed.sh" --check >/dev/null 2>&1
[ -f "$SEEDR/home/hodd/identity/clients.yaml" ] \
  && bad "--check writes nothing" "it created the register" \
  || ok "--check reports and writes nothing"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
