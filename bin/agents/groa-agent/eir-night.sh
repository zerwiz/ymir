#!/usr/bin/env bash
# eir-night.sh — Eir after Gróa, every night, on every install (plan 350 part C; the Allfather, 2026-11-22:
# "all users get Gróa running on a cron job every night, and Eir after, so Ymir gets updated and healed").
#
# Seated by bin/agents/groa-agent/seat.sh as ~/.local/bin/eir-night.sh and run by eir-night.service, which
# Gróa's unit starts on success AND on failure (OnSuccess= / OnFailure=): the healer runs after the renewer
# whatever the renewer said, because "surfaces owed" is exactly the night Eir is for.
#
# The stages, each bounded (a stage that runs out of time is NAMED in the verdict, never left to hang):
#   groa     read Gróa's own result: the last tick line of state/groa-agent.log (rc, and the step it stopped in)
#   check    bin/agents/eir-doctor.sh check                   EIR_NIGHT_CHECK_S (600)
#   mend     bin/agents/eir-doctor.sh fix <surface>, ONLY for the surfaces whose risk is `safe`
#                                                              EIR_NIGHT_FIX_S (300) each
#   recheck  bin/agents/eir-doctor.sh check, again             EIR_NIGHT_CHECK_S
#   apps     bin/apps/apps.sh update <app> for each installed app EIR_NIGHT_APPS_S (600)
#   tell     the verdict to the arm holder, with a Veil id (bin/agents/veil.sh send; rodd-arm.sh tell when the
#            Veil is not in this release)
#
# Never root: YMIR_NO_SUDO=1 is set for every stage, so a step that needs root is skipped and named, never
# prompted. The verdict is kept in <state>/renewal/last-night.json (what Eir's `renewal` surface reads) and
# appended to <state>/renewal/nights.jsonl.
#
# Exit: 0 the night ran to its end (whatever is still owed is named in the verdict) · 1 a stage hung or a door
# is missing, or Gróa failed outright · 2 usage.
set -uo pipefail
case "${1:-}" in -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
REPO="${YMIR_REPO:-}"
[ -n "$REPO" ] || { [ -d "${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}" ] && REPO="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"; }
[ -n "$REPO" ] || REPO="$HOME/ymir"
export YMIR_NO_SUDO=1 SUDO_ASKPASS=/bin/false
STATE=""
if [ -r "$REPO/bin/vault/hoard-lib.sh" ]; then
  # shellcheck disable=SC1091
  . "$REPO/bin/vault/hoard-lib.sh" && hoard_state_dir STATE 2>/dev/null
fi
STATE="${EIR_NIGHT_STATE:-${STATE:-$HOME/.local/state/ymir}}"
DIR="$STATE/renewal"; mkdir -p "$DIR"
LOG="$DIR/eir-night.log"
EIR="${EIR_NIGHT_EIR:-$REPO/bin/agents/eir-doctor.sh}"
APPS="${EIR_NIGHT_APPS:-$REPO/bin/apps/apps.sh}"
GLOG="${EIR_NIGHT_GROA_LOG:-$STATE/groa-agent.log}"
host="$(hostname -s 2>/dev/null || uname -n)"
hung=""; failed=""
HUNG_FILE="$DIR/.hung.$$"; : >"$HUNG_FILE"   # a stage runs inside $( ), so a hang is written down, not set
stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '%s %s\n' "$(stamp)" "$*" >>"$LOG"; }

stage() {  # <name> <seconds> <command…> → its output on stdout; records a hang by name
  local name=$1 limit=$2; shift 2
  local out rc
  log "stage $name: start (limit ${limit}s)"
  out="$(timeout --kill-after=10 "$limit" "$@" </dev/null 2>&1)"; rc=$?
  log "stage $name: rc $rc"
  if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then printf '%s (over %ss)\n' "$name" "$limit" >>"$HUNG_FILE"; fi
  home_ward "$name"
  printf '%s\n' "$out"
  return "$rc"
}

# THE HOME WARD (Hávi, at the Allfather's word, 2026-11-22: "the night run must refuse to delete or relink a
# tracked home directory"). On 2026-11-22 at 05:41 the home's config/ became a link to a path that does not exist,
# and the house could not read its schedule. Every folder the home's git tracks at its top level must still be a
# real folder after Gróa's leg and after every stage; one that became a link or vanished FAILS the night, named with
# the stage that was running, and the fix is printed — never repaired silently, because the home is the operator's.
WARD_FILE="$DIR/.ward.$$"; : >"$WARD_FILE"
HOME_TREE="${EIR_NIGHT_HOME:-${YMIR_HOME:-}}"
if [ -z "$HOME_TREE" ] && [ -r "$REPO/bin/vault/hoard-lib.sh" ]; then
  # shellcheck disable=SC1091
  (. "$REPO/bin/vault/hoard-lib.sh" && ymir_home_root _h && printf '%s' "$_h") >"$DIR/.home.$$" 2>/dev/null
  HOME_TREE="$(cat "$DIR/.home.$$" 2>/dev/null)"; rm -f "$DIR/.home.$$"
fi
TRACKED_DIRS=""
[ -n "$HOME_TREE" ] && TRACKED_DIRS="$(git -C "$HOME_TREE" ls-tree -d --name-only HEAD 2>/dev/null | tr '\n' ' ')"
home_ward() {  # <after-which-stage>
  local d
  for d in $TRACKED_DIRS; do
    if [ -L "$HOME_TREE/$d" ]; then
      printf 'the home'"'"'s tracked folder %s/ became a link (-> %s) during %s — restore: rm %s && git -C %s checkout -- %s\n' \
        "$d" "$(readlink "$HOME_TREE/$d")" "$1" "$HOME_TREE/$d" "$HOME_TREE" "$d" >>"$WARD_FILE"
    elif [ ! -d "$HOME_TREE/$d" ]; then
      printf 'the home'"'"'s tracked folder %s/ vanished during %s — restore: git -C %s checkout -- %s\n' "$d" "$1" "$HOME_TREE" "$d" >>"$WARD_FILE"
    fi
  done
}
home_ward "groa (before Eir's night)"

# 1 · Gróa's own word: the last finished tick in her log
groa_line="$(grep -E 'tick finished \(rc [0-9]+\)' "$GLOG" 2>/dev/null | tail -1)"
groa_rc="$(printf '%s' "$groa_line" | sed -n 's/.*tick finished (rc \([0-9]*\)).*/\1/p')"
groa_verdict="$(grep -E '^groa-update: (whole|NOT whole)' "$GLOG" 2>/dev/null | tail -1 | cut -c1-300)"
groa_stuck=""
if [ "${groa_rc:-}" = 124 ]; then
  groa_stuck="$(grep -E '^(step|==|──|groa-update: step)' "$GLOG" 2>/dev/null | tail -1 | cut -c1-160)"
  hung="${hung:+$hung, }groa (timed out${groa_stuck:+ in: $groa_stuck})"
fi
case "${groa_rc:-}" in 0|4) ;; '') failed="no finished Gróa tick in $GLOG" ;; 124) ;; *) failed="Gróa exited ${groa_rc}" ;; esac

# 2 · Eir looks, mends what it may, and looks again
[ -x "$EIR" ] || { failed="${failed:+$failed; }Eir is missing at $EIR"; }
owed_before=""; mended=""; not_mended=""; owed_after=""
if [ -x "$EIR" ]; then
  out="$(stage check "${EIR_NIGHT_CHECK_S:-600}" bash "$EIR" check)"
  owed_before="$(printf '%s\n' "$out" | sed -n 's/^owed: \([a-z0-9-]*\) \([a-z]*\)$/\1:\2/p' | tr '\n' ' ')"
  for row in $owed_before; do
    name="${row%%:*}"; risk="${row##*:}"
    [ "$risk" = safe ] || continue
    if stage "mend:$name" "${EIR_NIGHT_FIX_S:-300}" bash "$EIR" fix "$name" >/dev/null; then
      mended="${mended:+$mended }$name"
    else
      not_mended="${not_mended:+$not_mended }$name"
    fi
  done
  out="$(stage recheck "${EIR_NIGHT_CHECK_S:-600}" bash "$EIR" check)"
  owed_after="$(printf '%s\n' "$out" | sed -n 's/^owed: \([a-z0-9-]*\) \([a-z]*\)$/\1 (\2)/p' | paste -sd, - | sed 's/,/, /g')"
fi

# 3 · the apps renew after the flip
apps_line="skipped (no apps door)"
desk=""
[ -x "$REPO/bin/desk/in-call.sh" ] && desk="$(timeout 10 bash "$REPO/bin/desk/in-call.sh" holder 2>/dev/null | head -1)"
midrun=""
command -v smidja >/dev/null 2>&1 && midrun="$(timeout 20 smidja sessions 10 2>/dev/null | awk '$3 ~ /^(running|started|active|in-progress|working)$/ {print $1; exit}')"
if [ -n "$desk" ]; then
  apps_line="skipped — the desk is in a call ($desk); no app restarts while it is"
elif [ -n "$midrun" ]; then
  apps_line="skipped — a smithy run is mid-phase ($midrun); no app renews under a live run"
elif [ -x "$APPS" ] && [ "${EIR_NIGHT_APPS_UPDATE:-on}" != off ]; then
  installed="$(timeout 60 bash "$APPS" list 2>/dev/null | sed -n 's/^  "\([a-z0-9-]*\)",.*,"home"$/\1/p' | tr '\n' ' ')"
  ok_apps=""; bad_apps=""
  for a in $installed; do
    if stage "apps:$a" "${EIR_NIGHT_APPS_S:-600}" bash "$APPS" update "$a" >/dev/null; then ok_apps="${ok_apps:+$ok_apps }$a"; else bad_apps="${bad_apps:+$bad_apps }$a"; fi
  done
  apps_line="updated: ${ok_apps:-none}${bad_apps:+; failed: $bad_apps}"
fi

# 4 · the verdict
home_ward "the end of the night"
_w="$(awk '!seen[$0]++' "$WARD_FILE" 2>/dev/null | head -3 | paste -sd';' - | sed 's/;/; /g')"; rm -f "$WARD_FILE"
[ -n "$_w" ] && failed="${failed:+$failed; }$_w"
_h="$(paste -sd, "$HUNG_FILE" 2>/dev/null | sed 's/,/, /g')"; rm -f "$HUNG_FILE"
[ -n "$_h" ] && hung="${hung:+$hung, }$_h"
result=green
[ -n "$owed_after" ] && result=owed
[ -n "$hung$failed" ] && result=failed
release="$(readlink -f "$REPO" 2>/dev/null | sed 's#.*/##')"
python3 - "$DIR" "$host" "$result" "${groa_rc:-none}" "$groa_verdict" "$mended" "$not_mended" "$owed_after" "$hung" "$failed" "$apps_line" "$release" <<'PY'
import json, os, sys, time
d, host, result, grc, gv, mended, notm, owed, hung, failed, apps, release = sys.argv[1:]
rec = {"ts": int(time.time()), "host": host, "result": result, "groa_rc": grc, "groa_verdict": gv,
       "mended": mended.split(), "not_mended": notm.split(), "owed": owed, "hung": hung, "failed": failed,
       "apps": apps, "release": release}
tmp = os.path.join(d, "last-night.json.tmp")
json.dump(rec, open(tmp, "w"))
os.replace(tmp, os.path.join(d, "last-night.json"))
with open(os.path.join(d, "nights.jsonl"), "a") as fh:
    fh.write(json.dumps(rec) + "\n")
PY
line="the night on $host ($release): $result — Gróa rc ${groa_rc:-none}; Eir mended: ${mended:-nothing}${not_mended:+; could not mend: $not_mended}; still owed: ${owed_after:-nothing}${hung:+; HUNG: $hung}${failed:+; FAILED: $failed}; apps $apps_line"
log "verdict: $line"
printf '%s\n' "$line"

# 5 · tell the arm holder, with an id it answers (the receipt contract)
if [ "${EIR_NIGHT_TELL:-on}" != off ]; then
  if [ -x "$REPO/bin/agents/veil.sh" ]; then
    timeout 120 bash "$REPO/bin/agents/veil.sh" send --from "script Eir after Gróa ($host)" --kind report "$line" >>"$LOG" 2>&1 \
      || log "tell: the Veil could not hand the verdict on (the sweep and the trouble panel carry it)"
  elif [ -x "$REPO/bin/voice/rodd-arm.sh" ]; then
    timeout 60 bash "$REPO/bin/voice/rodd-arm.sh" tell --from "script Eir after Gróa ($host)" "$line" >>"$LOG" 2>&1 || log "tell: no arm is held"
  fi
fi
[ "$result" = failed ] && exit 1
exit 0
