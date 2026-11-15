#!/usr/bin/env bash
# test_wardens_off_until_named.sh — the Allfather's word, proven: an existing installation gets the change,
# and after the update road NO outward warden runs until the operator names it for that machine.
#
# The proof runs against a COPY of an old-shaped home — no wardens.yaml, an outward timer seated and running
# by the old install — with `systemctl` stubbed, so what is judged is exactly what the migration does:
#
#   1. on an old-shaped home the update road turns every outward door OFF and stops its clock;
#   2. it RECORDS what was running (`was_on:`), so the operator can turn back on what he owns;
#   3. it disables exactly the outward timers, and nothing else;
#   4. it is idempotent (a second run does nothing);
#   5. a door a PERSON named (`enabled: on`, no migration marker) is left alone, timer and all;
#   6. a fresh install receives the template with every door off (bin/engine/home-seed.sh);
#   7. after the migration the doors refuse and the seater retires their units.
#
# Exit 0 when every case passes.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
POLICY="$ROOT/bin/forge/warden-policy.py"
MIGRATE="$ROOT/.agents/migrations/0024-wardens-off-until-named.sh"
PASS=0; FAIL=0
check() { if [ "$1" = "0" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$2"; fi; }
refutes() { case "$1" in *"$2"*) return 0 ;; *) printf '   missing text: %s\n' "$2"; return 1 ;; esac; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/warden-update.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# ── the stub: a systemd that remembers what it was told ─────────────────────────────────────────
mkdir -p "$WORK/bin" "$WORK/units"
cat >"$WORK/bin/systemctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUB_LOG"
verb="$2"; unit="${!#}"   # disable takes `--now <unit>`: the unit is the LAST word
state="$STUB_STATE/$unit"
case "$verb" in
  is-active|is-enabled)
    [ -n "$unit" ] && [ -f "$state" ] && { printf 'active\n'; exit 0; }
    [ -n "$unit" ] && [ -f "$state" ] && { printf 'enabled\n'; exit 0; }
    printf 'inactive\n'; exit 3 ;;
  disable|stop) rm -f "$state"; exit 0 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$WORK/bin/systemctl"

old_home() {  # <dir> — an old-shaped home: no wardens.yaml, the post-0023 file is absent too
  local h="$1"
  mkdir -p "$h/hodd/identity" "$h/hodd/data" "$h/config"
  cat >"$h/hodd/identity/projects.yaml" <<'YAML'
projects:
- id: ours
  git: { host: github.com, owner: octo, repo: ours, remote: origin, default_branch: main, auth: gh }
YAML
  cat >"$h/hodd/data/fleet.json" <<'JSON'
{"heart": "heartbox", "hosts": {"oldbox": {"roles": ["dev"]}, "heartbox": {"roles": ["heart"]}}}
JSON
}

seat_old_install() {  # the seven clocks the old install seated, on and enabled
  export STUB_STATE="$WORK/systemd-state"; mkdir -p "$STUB_STATE"
  for u in queue-warden review-watch review-seat review-loop pr-watch issue-watch ship-watch; do
    : >"$STUB_STATE/$u.timer"
  done
  # a NON-outward unit that must not be touched
  : >"$STUB_STATE/mimir.service"
}

# ── 1..3 · an old-shaped home, after the update road ─────────────────────────────────────────────
home="$WORK/oldbox"; old_home "$home"; seat_old_install
export STUB_LOG="$WORK/systemctl.log"; : >"$STUB_LOG"
out="$(PATH="$WORK/bin:$PATH" STUB_LOG="$STUB_LOG" STUB_STATE="$STUB_STATE" \
  YMIR_HOME="$home" YMIR_MACHINE=oldbox YMIR_UNIT_DIR="$WORK/units" \
  bash "$MIGRATE" 2>&1)"
check $? "the update road runs the migration and exits 0"
[ -f "$home/config/machines/oldbox/wardens.yaml" ]; check $? "an old-shaped home receives the file"

for d in queue-warden review-watch review-seat review-loop pr-watch issue-watch ship-watch \
         gna-mail snotra-mail git-sync private-scan; do
  YMIR_HOME="$home" YMIR_MACHINE=oldbox python3 -I "$POLICY" on "$d" >/dev/null 2>&1
  [ $? -ne 0 ]; check $? "after the update: $d does not run until named"
done

grep -qE '^\s+was_on:' "$home/config/machines/oldbox/wardens.yaml"; check $? "it records that the old install was running them"
n_was="$(grep -cE '^\s+was_on:' "$home/config/machines/oldbox/wardens.yaml")"
[ "$n_was" = 7 ]; check $? "it recorded all seven doors the old install seated (got $n_was)"

for u in queue-warden review-watch review-seat review-loop pr-watch issue-watch ship-watch; do
  grep -q "disable --now $u.timer" "$STUB_LOG"; check $? "it disabled $u.timer"
done
grep -q "mimir" "$STUB_LOG"; [ $? -ne 0 ]; check $? "it touched no unit that is not an outward warden"
n_dis="$(grep -c 'disable --now' "$STUB_LOG")"
[ "$n_dis" = 7 ]; check $? "it disabled exactly the seven outward timers (got $n_dis)"
live="$(ls "$STUB_STATE" 2>/dev/null | grep -cE 'warden|watch|review' || true)"
[ "${live:-0}" = 0 ]; check $? "no outward timer is left running"

# ── 4 · idempotent ──────────────────────────────────────────────────────────────────────────────
before="$(cat "$home/config/machines/oldbox/wardens.yaml")"
: >"$STUB_LOG"
PATH="$WORK/bin:$PATH" STUB_LOG="$STUB_LOG" STUB_STATE="$STUB_STATE" \
  YMIR_HOME="$home" YMIR_MACHINE=oldbox bash "$MIGRATE" >/dev/null 2>&1
after="$(cat "$home/config/machines/oldbox/wardens.yaml")"
[ "$before" = "$after" ]; check $? "a second run changes nothing"
n2="$(grep -c 'disable --now' "$STUB_LOG" || true)"
[ "${n2:-0}" = 0 ]; check $? "a second run disables nothing again"

# ── 5 · a door a PERSON named is left alone ─────────────────────────────────────────────────────
named="$WORK/namedbox"; old_home "$named"
mkdir -p "$named/config/machines/namedbox"
cat >"$named/config/machines/namedbox/wardens.yaml" <<'YAML'
pr-watch:
  enabled: on
queue-warden:
  enabled: off
YAML
export STUB_STATE="$WORK/systemd-state2"; mkdir -p "$STUB_STATE"; : >"$STUB_STATE/pr-watch.timer"
: >"$STUB_LOG"
PATH="$WORK/bin:$PATH" STUB_LOG="$STUB_LOG" STUB_STATE="$STUB_STATE" \
  YMIR_HOME="$named" YMIR_MACHINE=namedbox bash "$MIGRATE" >/dev/null 2>&1
YMIR_HOME="$named" YMIR_MACHINE=namedbox python3 -I "$POLICY" on pr-watch >/dev/null 2>&1
check $? "a door this operator named on is still on"
grep -q "disable --now pr-watch.timer" "$STUB_LOG"; [ $? -ne 0 ]; check $? "and its timer was not stopped"
[ -f "$STUB_STATE/pr-watch.timer" ]; check $? "the operator's named clock keeps running"

# ── 6 · a fresh install receives the template, every door off ───────────────────────────────────
fresh="$WORK/fresh"; mkdir -p "$fresh"
YMIR_HOME="$fresh" YMIR_MACHINE=freshbox bash "$ROOT/bin/engine/home-seed.sh" >/dev/null 2>&1
[ -f "$fresh/config/machines/freshbox/wardens.yaml" ]; check $? "a fresh install receives its wardens.yaml"
if [ -f "$fresh/config/machines/freshbox/wardens.yaml" ]; then
  n_on="$(grep -cE '^\s+enabled:\s+on' "$fresh/config/machines/freshbox/wardens.yaml" || true)"
  [ "${n_on:-0}" = 0 ]; check $? "the template ships every outward door off"
  YMIR_HOME="$fresh" YMIR_MACHINE=freshbox python3 -I "$POLICY" on review-watch >/dev/null 2>&1
  [ $? -ne 0 ]; check $? "a fresh install's review-watch does not run until named"
fi

# ── 7 · after the migration the seater retires what is left ─────────────────────────────────────
res="$(STUB_LOG="$WORK/systemctl2.log" STUB_STATE="$STUB_STATE" PATH="$WORK/bin:$PATH" \
  YMIR_HOME="$home" YMIR_MACHINE=oldbox YMIR_UNITS_ROLES=dev YMIR_UNITS_NO_ROLE_PROBE=1 \
  YMIR_UNIT_DIR="$WORK/units" bash "$ROOT/bin/engine/units.sh" write 2>&1)"
printf '%s' "$res" | grep -q '"queue-warden","timer","not-seated"'; check $? "the seater reports the unnamed door as not-seated"
printf '%s' "$res" | grep -q 'does not name it'; check $? "and says the unit file is kept, not deleted"

printf 'wardens-off-until-named tests: %d pass, %d fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
