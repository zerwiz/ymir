#!/usr/bin/env bash
# test_warden_lib.sh — plan 290 §3, proven: the wardens act only where the operator names them, only on
# the operator's own repositories, and only as the identity that machine gives the duty.
#
# The four proofs the errand asks for, each against a FENCED home, a fenced unit dir and a fake `gh` —
# nothing here touches the real home, the real ledger, or systemd:
#
#   1. a fresh home with no wardens.yaml seats NO outward timer (and every --install-timer refuses);
#   2. a repository that is not in the operator's registry is refused, by name;
#   3. a mismatched GitHub identity is refused, and the refusal prints BOTH names;
#   4. this machine's current doors keep working once its file names them, and a merge stays refused
#      everywhere but the fleet's heart;
#   5. every outward act leaves ONE Rune carrying machine, door, identity, repository and verdict.
#
# Exit 0 when every case passes.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
POLICY="$ROOT/bin/forge/warden-policy.py"
LIB="$ROOT/bin/forge/warden-lib.sh"
PASS=0; FAIL=0
check() { if [ "$1" = "0" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$2"; fi; }
refutes() { case "$1" in *"$2"*) return 0 ;; *) printf '   missing text: %s\n' "$2"; return 1 ;; esac; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/warden-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fenced() {  # a home with a registry and a fleet registry, no wardens.yaml
  local h="$1"
  mkdir -p "$h/hodd/identity" "$h/hodd/data" "$h/config/machines/${2:-heimdall}" "$h/state"
  cat >"$h/hodd/identity/projects.yaml" <<'YAML'
projects:
- id: ours
  git: { host: github.com, owner: octo, repo: ours, remote: origin, default_branch: main, auth: gh }
YAML
  cat >"$h/hodd/data/fleet.json" <<'JSON'
{"heart": "heartbox", "hosts": {"heimdall": {"roles": ["dev"]}, "heartbox": {"roles": ["heart"]}}}
JSON
}

# ── 1 · a fresh home seats nothing ────────────────────────────────────────────────────────────────
fresh="$WORK/fresh"; fenced "$fresh"
out="$(YMIR_HOME="$fresh" YMIR_MACHINE=heimdall python3 -I "$POLICY" doors 2>&1)"
printf '%s' "$out" | grep -q '"review-watch","timer","off"'; check $? "a fresh home: review-watch reads off"
printf '%s' "$out" | grep -q '"queue-warden","timer","off"'; check $? "a fresh home: queue-warden reads off"
YMIR_HOME="$fresh" YMIR_MACHINE=heimdall python3 -I "$POLICY" on ship-watch >/dev/null 2>&1; [ $? -ne 0 ]
check $? "a fresh home: 'on' answers no for a timer door"
# a hand-invoked door is never held off (never remove a feature)
YMIR_HOME="$fresh" YMIR_MACHINE=heimdall python3 -I "$POLICY" on gather >/dev/null 2>&1
check $? "a fresh home: gather (a hand's door) still answers yes"

# the seater writes no unit for an unnamed outward door, and DOES for a named one
mkdir -p "$WORK/units"
res="$(YMIR_HOME="$fresh" YMIR_MACHINE=heimdall YMIR_UNITS_NO_SYSTEMCTL=1 YMIR_UNITS_ROLES=dev \
  YMIR_UNIT_DIR="$WORK/units" YMIR_UNITS_NO_ROLE_PROBE=1 bash "$ROOT/bin/engine/units.sh" write --dry-run 2>&1)"
printf '%s' "$res" | grep -q '"queue-warden","timer","not-seated"'; check $? "a fresh home: the seater writes no queue-warden unit"
printf '%s' "$res" | grep -q '"review-watch","timer","not-seated"'; check $? "a fresh home: the seater writes no review-watch unit"

# every --install-timer path refuses before it touches systemd
YMIR_HOME="$fresh" YMIR_MACHINE=heimdall bash "$ROOT/bin/forge/review-shelf.sh" --install-timer >/dev/null 2>&1
[ $? -eq 3 ]; check $? "a fresh home: review-shelf --install-timer refuses (exit 3)"
YMIR_HOME="$fresh" YMIR_MACHINE=heimdall bash "$ROOT/bin/forge/pr-watch.sh" --install-timer >/dev/null 2>&1
[ $? -eq 3 ]; check $? "a fresh home: pr-watch --install-timer refuses (exit 3)"

# ── 2 · own repositories only ─────────────────────────────────────────────────────────────────────
YMIR_HOME="$fresh" YMIR_MACHINE=heimdall python3 -I "$POLICY" owns octo/ours >/dev/null 2>&1
check $? "a repository in the registry is the operator's"
why="$(YMIR_HOME="$fresh" YMIR_MACHINE=heimdall python3 -I "$POLICY" owns someone/else 2>&1)"
[ $? -ne 0 ]; check $? "a repository outside the registry is refused"
refutes "$why" "someone/else is not in"; check $? "the refusal names the repository"
# with no registry at all, nothing is the operator's
ghost="$WORK/ghost"; mkdir -p "$ghost/config/machines/heimdall"
YMIR_HOME="$ghost" YMIR_MACHINE=heimdall python3 -I "$POLICY" owns octo/ours >/dev/null 2>&1
[ $? -ne 0 ]; check $? "no registry: no repository is claimed"

# ── 3 · the identity named for the duty ───────────────────────────────────────────────────────────
named="$WORK/named"; fenced "$named"
cat >"$named/config/machines/heimdall/wardens.yaml" <<'YAML'
identity: heimdall-warden
review-watch:
  enabled: on
queue-warden:
  enabled: off
  merge: off
ship-watch:
  enabled: on
YAML
fakebin="$WORK/bin"; mkdir -p "$fakebin"
cat >"$fakebin/gh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in "api user") printf 'someone-else\n'; exit 0 ;; esac
exit 0
SH
chmod +x "$fakebin/gh"
mismatch="$(PATH="$fakebin:$PATH" YMIR_HOME="$named" YMIR_MACHINE=heimdall bash -c '
  . "'"$LIB"'"
  warden_begin review-watch
  warden_require_identity' 2>&1)"
[ $? -ne 0 ]; check $? "a mismatched identity is refused"
refutes "$mismatch" "heimdall-warden"; check $? "the refusal names the identity the machine wants"
refutes "$mismatch" "someone-else"; check $? "the refusal names the login that answered"

cat >"$fakebin/gh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in "api user") printf 'heimdall-warden\n'; exit 0 ;; esac
exit 0
SH
chmod +x "$fakebin/gh"
matched="$(PATH="$fakebin:$PATH" YMIR_HOME="$named" YMIR_MACHINE=heimdall bash -c '
  . "'"$LIB"'"
  warden_begin review-watch
  warden_require_identity >/dev/null 2>&1 || exit 1
  printf "named:%s match:%s\n" "$WARDEN_IDENTITY_NAMED" "$WARDEN_IDENTITY_MATCH"' 2>&1)"
[ $? -eq 0 ]; check $? "a matching identity is allowed through"
refutes "$matched" "named:heimdall-warden"; check $? "the machine-wide identity is read as the duty's default"
refutes "$matched" "match:1"; check $? "a matching identity is recorded as matched"

# an unnamed duty acts, and says so (today's machines have no warden token yet — plan 290 P5)
unnamed="$(PATH="$fakebin:$PATH" YMIR_HOME="$fresh" YMIR_MACHINE=heimdall bash -c '
  . "'"$LIB"'"
  warden_begin review-watch
  warden_require_identity' 2>&1)"
[ $? -eq 0 ]; check $? "an unnamed duty acts under the ambient login"
refutes "$unnamed" "names no identity"; check $? "an unnamed duty says out loud whose hand it is"

# ── 4 · named doors work; a merge stays refused everywhere but the heart ──────────────────────────
YMIR_HOME="$named" YMIR_MACHINE=heimdall python3 -I "$POLICY" on review-watch >/dev/null 2>&1
check $? "a named door answers yes"
res="$(YMIR_HOME="$named" YMIR_MACHINE=heimdall YMIR_UNITS_NO_SYSTEMCTL=1 YMIR_UNITS_ROLES=dev \
  YMIR_UNIT_DIR="$WORK/units2" YMIR_UNITS_NO_ROLE_PROBE=1 bash "$ROOT/bin/engine/units.sh" write --dry-run 2>&1)"
printf '%s' "$res" | grep -q '"review-watch","timer","would-write"'; check $? "a named door IS seated by the seater"

# a machine whose file SAYS merge: on, but which the fleet does not name heart: still refused
mergebox="$WORK/mergebox"; fenced "$mergebox"
cat >"$mergebox/config/machines/heimdall/wardens.yaml" <<'YAML'
ship-watch:
  enabled: on
  merge: on
YAML
merge_why="$(YMIR_HOME="$mergebox" YMIR_MACHINE=heimdall bash -c '
  . "'"$LIB"'"
  warden_begin ship-watch
  warden_merge_allowed 12' 2>&1)"
[ $? -ne 0 ]; check $? "merge: on is refused on a machine the fleet does not name heart"
refutes "$merge_why" "heartbox"; check $? "the merge refusal names the machine the fleet calls heart"

# ── 5 · the Rune ──────────────────────────────────────────────────────────────────────────────────
# the fake gh answers as someone else again, so the Rune must carry THAT name
cat >"$fakebin/gh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in "api user") printf 'someone-else\n'; exit 0 ;; esac
exit 0
SH
chmod +x "$fakebin/gh"
ledger="$WORK/runes_audit.md"
PATH="$fakebin:$PATH" BROKK_RUNES_FILE="$ledger" BROKK_RUNES_DIR="$WORK" BROKK_HOME="$WORK" \
  YMIR_HOME="$named" YMIR_MACHINE=heimdall bash -c '
  . "'"$LIB"'"
  warden_begin review-watch
  warden_require_identity >/dev/null 2>&1
  WARDEN_REPOS="octo/ours"
  warden_runes acted "raised 1 ask"' >"$WORK/rune.out" 2>&1
row="$(cat "$WORK/rune.out" 2>/dev/null)"
refutes "$row" "machine=heimdall"; check $? "the Rune carries the machine"
refutes "$row" "door=review-watch"; check $? "the Rune carries the door"
refutes "$row" "identity=someone-else"; check $? "the Rune carries the identity that acted"
refutes "$row" "repos=octo/ours"; check $? "the Rune carries the repository"

printf 'warden-lib tests: %d pass, %d fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
