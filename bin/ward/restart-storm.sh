#!/usr/bin/env bash
# restart-storm.sh — the ward that stops a unit spinning on its own face (plan 286 P4).
#
# WHY (the Allfather's night of 2026-11-14): two units on the heart restarted 2,277 times in two
# hours — one 1,283 times (its working directory was gone), the other 994 — and together they
# filled an 11 GB machine with restarts until it ran out of memory and swap. Every unit showed
# green while it did. A unit that restarts more than N times in an hour is not running: it
# is a fault with a restart policy on top. So it is stopped, named, and its last error is carried
# to the Allfather instead of being buried in a journal nobody reads.
#
# WHAT IT DOES, per pass:
#   1. Asks each candidate unit how many times it restarted inside the window — from the journal's
#      own `Scheduled restart job` lines (exact timestamps), and when the journal cannot answer,
#      from the sampler's ledger (`NRestarts` deltas, plan 286 P0). It records WHICH source spoke.
#   2. A unit strictly above the limit is stopped — unless a call is held on the desk and the unit
#      is the audio family, or the operator excluded it, or the ward is switched off (report only).
#   3. Writes a `kind:"storm"` row into the same ledger the sampler writes, and sends through
#      `bin/notify/send.sh`, so the stop is a Rune and a message, not a log line.
#
# Never stopped: a unit whose file is the distribution's (not the house's to stop), a unit named
# by `restart_storm.exclude`, and — while `bin/desk/in-call.sh holder` names a call — a unit in
# `restart_storm.defer_in_call` (the audio and voice family), which is deferred and said so.
#
# USAGE
#   restart-storm.sh [--pass] [--dry-run] [--quiet] [--json]
#                    [--scope user|system|both] [--threshold N] [--window-minutes M]
#   restart-storm.sh --status
#   restart-storm.sh --version
#
# THE CONFIG lives in the home, never in this tree: `$YMIR_HOME/config/soak.yaml`
#
#   restart_storm:
#     enabled: true          # false = report, stop nothing
#     threshold: 10          # restarts inside the window, above which a unit is stopped
#     window_minutes: 60
#     scope: user            # user | system | both   (stopping a system unit needs the privilege)
#     exclude: ""            # extended regex of units never stopped
#     defer_in_call: "^(snotra|speech-to-speech|kokoro|rodd|ymir-voice|pipewire|wireplumber)"
#     cooldown_minutes: 60   # do not re-notify about one unit inside this window
#
# EXIT: 0 a pass that found no storm, or stopped what it found · 1 a stop was attempted and failed
#       (named) · 2 usage.
#
# ENV (test seams, so the ward is provable without a real fault):
#   YMIR_SOAK_STATE · YMIR_SOAK_CONFIG · YMIR_SOAK_SYSTEMCTL · YMIR_SOAK_JOURNALCTL
#   YMIR_SOAK_NOTIFY · YMIR_SOAK_IN_CALL
set -uo pipefail

VERSION="1.0.0"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _w in "$SELF_DIR/../vault/hoard-lib.sh" "$ROOT/bin/vault/hoard-lib.sh"; do
    [ -r "$_w" ] && { . "$_w"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _w
fi
# The home and the state are RESOLVED, never guessed (Rule 07): hoard-lib owns both answers.
HOME_DIR=""; declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR 2>/dev/null
if [ -z "$HOME_DIR" ]; then printf 'error: the home is unresolved (bin/vault/hoard-lib.sh)\n' >&2; exit 1; fi
STATE_BASE=""; declare -f hoard_state_dir >/dev/null 2>&1 && hoard_state_dir STATE_BASE 2>/dev/null
if [ -z "$STATE_BASE" ]; then printf 'error: the state dir is unresolved (bin/vault/hoard-lib.sh)\n' >&2; exit 1; fi
SOAK_STATE="${YMIR_SOAK_STATE:-$STATE_BASE/soak}"
CONFIG="${YMIR_SOAK_CONFIG:-$HOME_DIR/config/soak.yaml}"
LEDGER_DIR="$SOAK_STATE/services"
WARD_STATE="$SOAK_STATE/storm-state.json"
SYSTEMCTL="${YMIR_SOAK_SYSTEMCTL:-systemctl}"
JOURNALCTL="${YMIR_SOAK_JOURNALCTL:-journalctl}"
NOTIFY="${YMIR_SOAK_NOTIFY:-$ROOT/bin/notify/send.sh}"
IN_CALL="${YMIR_SOAK_IN_CALL:-$ROOT/bin/desk/in-call.sh}"

usage() { sed -n '2,52p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'error: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf 'help: %s\n' "$2" >&2; exit 2; }

cfg_get() {  # <dotted.key> <default> → "value<TAB>config|default" (the same reader as the sampler)
  python3 - "$CONFIG" "$1" "$2" <<'PY' 2>/dev/null || printf '%s\tdefault\n' "$3"
import sys
path, dotted, default = sys.argv[1], sys.argv[2], sys.argv[3]
data = None
try:
    import yaml
    with open(path) as fh:
        data = yaml.safe_load(fh)
except Exception:
    data = None
if not isinstance(data, dict):
    data = {}
    try:
        section = None
        for raw in open(path):
            line = raw.split("#", 1)[0].rstrip()
            if not line.strip():
                continue
            if not line.startswith((" ", "\t")) and line.rstrip().endswith(":"):
                section = line.strip()[:-1]
                data.setdefault(section, {})
                continue
            if ":" in line:
                k, v = line.strip().split(":", 1)
                v = v.strip().strip('"').strip("'")
                if line.startswith((" ", "\t")) and section:
                    data[section][k] = v
                else:
                    data[k] = v
    except Exception:
        data = {}
cur = data
for part in dotted.split("."):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        print("%s\tdefault" % default)
        sys.exit(0)
if isinstance(cur, bool):
    cur = "true" if cur else "false"
if cur is None or cur == "":
    print("%s\tdefault" % default)
    sys.exit(0)
print("%s\tconfig" % cur)
PY
}
cfg_val() { cfg_get "$1" "$2" | cut -f1; }

desk_holder() {  # prints the holder when a call is held on this desk; empty when free
  [ -x "$IN_CALL" ] || return 0
  "$IN_CALL" holder 2>/dev/null | head -n 1
}

# ── candidates: a unit with a restart policy, or one that has already restarted ──
candidates() {  # <scope> → TSV: id scope active sub restarts fragment restart
  local scope="$1"
  local -a flags=() names=() chunk=()
  case "$scope" in
    user) flags=(--user) ;;
    system) flags=(--system) ;;
    *) return 0 ;;
  esac
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    names+=("${line%% *}")
  done < <("$SYSTEMCTL" "${flags[@]}" list-units --type=service --all --plain --no-legend --no-pager 2>/dev/null)
  [ "${#names[@]}" -gt 0 ] || return 0
  local i=0
  while [ "$i" -lt "${#names[@]}" ]; do
    chunk=("${names[@]:$i:100}")
    "$SYSTEMCTL" "${flags[@]}" show --no-pager \
      -p Id -p ActiveState -p SubState -p NRestarts -p FragmentPath -p Restart "${chunk[@]}" 2>/dev/null
    i=$((i + 100))
  done | SCOPE="$scope" python3 -c '
import os, sys
scope = os.environ["SCOPE"]
blocks, cur = [], {}
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line.strip():
        if cur: blocks.append(cur); cur = {}
        continue
    if "=" in line:
        k, v = line.split("=", 1); cur[k] = v
if cur: blocks.append(cur)
for b in blocks:
    if not b.get("Id"): continue
    restart = b.get("Restart", "no") or "no"
    try: n = int(b.get("NRestarts", "0") or 0)
    except ValueError: n = 0
    if restart in ("no", "") and n == 0 and b.get("SubState") != "auto-restart":
        continue
    print("\t".join([b.get("Id",""), scope, b.get("ActiveState",""), b.get("SubState",""),
                     str(n), b.get("FragmentPath",""), restart]))
'
}

journal_restarts() {  # <scope> <unit> <window> <live-counter> → count, or nothing when it cannot answer
  local scope="$1" unit="$2" window="$3" counter="${4:-0}"
  local -a flags=()
  [ "$scope" = user ] && flags=(--user)
  local body rc=0
  body="$("$JOURNALCTL" "${flags[@]}" -u "$unit" --since "-$window min" -o cat --no-pager 2>/dev/null)" || rc=$?
  [ "$rc" -eq 0 ] || return 1          # the journal could not be read: not an answer of zero
  if [ -z "$body" ]; then
    # Nothing logged in the window. If systemd's own counter also says nothing has restarted, that
    # is a trustworthy zero; otherwise fall through to the ledger and then to the live counter.
    [ "$counter" = 0 ] || return 1
    printf '0\n'; return 0
  fi
  printf '%s\n' "$body" | grep -c 'Scheduled restart job' || true
}

journal_last_error() {  # <scope> <unit> <window> → the last error line, trimmed
  local scope="$1" unit="$2" window="$3"
  local -a flags=()
  [ "$scope" = user ] && flags=(--user)
  "$JOURNALCTL" "${flags[@]}" -u "$unit" --since "-$window min" -o cat --no-pager 2>/dev/null \
    | grep -viE 'Scheduled restart job|^Started |^Stopping |^Stopped |^Starting |^Reloading ' \
    | grep -iE 'error|fail|exception|traceback|status=|denied|missing|not found|no such' \
    | tail -n 1 | cut -c1-220
}

ledger_restarts() {  # <unit> <window> → count from the sampler's NRestarts deltas, or nothing
  local unit="$1" window="$2"
  [ -d "$LEDGER_DIR" ] || return 1
  SOAK_LEDGER="$LEDGER_DIR" SOAK_UNIT="$unit" SOAK_WINDOW="$window" python3 - <<'PY' 2>/dev/null || return 1
import datetime, glob, json, os, time
unit = os.environ["SOAK_UNIT"]
window = int(os.environ["SOAK_WINDOW"])
cutoff = time.time() - window * 60
def parse(ts):
    try:
        return datetime.datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=datetime.timezone.utc).timestamp()
    except Exception:
        return None
rows = []
for path in sorted(glob.glob(os.path.join(os.environ["SOAK_LEDGER"], "*.jsonl")))[-3:]:
    try:
        for line in open(path):
            try:
                row = json.loads(line)
            except Exception:
                continue
            if row.get("kind") != "service" or row.get("name") != unit:
                continue
            at = parse(row.get("ts", ""))
            if at is None:
                continue
            rows.append((at, int(row.get("restarts", 0) or 0)))
    except OSError:
        continue
if not rows:
    raise SystemExit(1)
rows.sort()
total, prev = 0, None
for at, restarts in rows:
    if at < cutoff:
        prev = restarts
        continue
    if prev is not None and restarts > prev:
        total += restarts - prev
    prev = restarts
print(total)
PY
}

# ── the pass ────────────────────────────────────────────────────────────────────
cmd_pass() {
  local dry=0 quiet=0 json=0 scope_arg="" threshold_arg="" window_arg=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --pass) ;;
      --dry-run) dry=1 ;;
      --quiet) quiet=1 ;;
      --json) json=1 ;;
      --scope) scope_arg="${2:-}"; shift ;;
      --threshold) threshold_arg="${2:-}"; shift ;;
      --window-minutes) window_arg="${2:-}"; shift ;;
      *) die "unknown flag $1" "restart-storm.sh [--pass] [--dry-run] [--quiet] [--json]" ;;
    esac
    shift
  done
  local enabled threshold window scope exclude defer cooldown
  enabled="$(cfg_val restart_storm.enabled true)"
  threshold="${threshold_arg:-$(cfg_val restart_storm.threshold 10)}"
  window="${window_arg:-$(cfg_val restart_storm.window_minutes 60)}"
  scope="${scope_arg:-${YMIR_SOAK_SCOPE:-$(cfg_val restart_storm.scope user)}}"
  exclude="$(cfg_val restart_storm.exclude '')"
  defer="$(cfg_val restart_storm.defer_in_call '^(snotra|speech-to-speech|kokoro|rodd|ymir-voice|pipewire|wireplumber)')"
  cooldown="$(cfg_val restart_storm.cooldown_minutes 60)"
  case "$scope" in user|system|both) ;; *) die "scope must be user|system|both (got '$scope')" ;; esac
  case "$threshold" in ''|*[!0-9]*) die "threshold must be a number (got '$threshold')" ;; esac
  case "$window" in ''|*[!0-9]*) die "window_minutes must be a number (got '$window')" ;; esac
  case "$cooldown" in ''|*[!0-9]*) cooldown=60 ;; esac

  # One hand at a time: two passes would stop the same unit and say so twice.
  if command -v flock >/dev/null 2>&1; then
    mkdir -p "$SOAK_STATE" 2>/dev/null || true
    exec 9>"$SOAK_STATE/.ward.lock" 2>/dev/null || true
    if ! flock -n 9; then
      [ "$quiet" = 1 ] || printf 'storm,skipped,another pass holds the ward\n'
      return 0
    fi
  fi

  local ts pass host now today
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  pass="$(date -u +%Y%m%dT%H%M%SZ)"
  host="$(hostname -s 2>/dev/null || echo unknown)"
  now="$(date +%s)"; today="$(date +%F)"
  local holder; holder="$(desk_holder || true)"

  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/ymir-storm.XXXXXX")" || die "no temp dir"
  local cands="$tmp/cands.tsv" found="$tmp/found.tsv"
  : > "$cands"; : > "$found"
  case "$scope" in
    user) candidates user >> "$cands" ;;
    system) candidates system >> "$cands" ;;
    both) candidates user >> "$cands"; candidates system >> "$cands" ;;
  esac

  # What was already stopped and said, read once, so a stopped unit is not told off every pass.
  local state_tsv="$tmp/ward-state.tsv"
  : > "$state_tsv"
  if [ -f "$WARD_STATE" ]; then
    WARD_STATE="$WARD_STATE" python3 - > "$state_tsv" 2>/dev/null <<'PY' || true
import json, os
st = json.load(open(os.environ["WARD_STATE"]))
for unit, rec in st.items():
    print("%s\t%s\t%s" % (unit, int(rec.get("last_stop", 0) or 0), int(rec.get("last_notify", 0) or 0)))
PY
  fi

  local seen=0 storms=0 stopped=0 failed=0 deferred=0 reported=0 countered=0 quieted=0 already=0
  local uid uscope active sub restarts fragment restart count source last_error action did say
  while IFS=$'\t' read -r uid uscope active sub restarts fragment restart; do
    [ -n "$uid" ] || continue
    seen=$((seen + 1))
    # The distribution's units are not the house's to stop, nor to judge.
    case "$fragment" in /usr/lib/systemd/*|/lib/systemd/*|/usr/share/systemd/*) continue ;; esac
    if [ -n "$exclude" ] && printf '%s' "$uid" | grep -qE "$exclude"; then continue; fi
    count="$(journal_restarts "$uscope" "$uid" "$window" "$restarts")" || count=""
    source="journal"
    if [ -z "$count" ]; then
      count="$(ledger_restarts "$uid" "$window")" || count=""
      source="ledger"
    fi
    if [ -z "$count" ]; then
      # The live counter is systemd's own total since activation: it cannot invent a storm, but it
      # can prove there is none — and when it is above the limit it is the storm itself.
      count="$restarts"; source="counter"
      countered=$((countered + 1))
    fi
    [ "$count" -gt "$threshold" ] || continue
    storms=$((storms + 1))
    last_error="$(journal_last_error "$uscope" "$uid" "$window")" || last_error=""
    [ -n "$last_error" ] || last_error="(no error line: state=${active}/${sub}, result=${restart})"
    action="stop"
    [ "$enabled" != "true" ] && action="report"
    if [ "$action" = "stop" ] && [ -n "$holder" ] && printf '%s' "$uid" | grep -qE "$defer"; then
      action="deferred"
    fi
    # Cooldown: a `report` or a `deferred` is said once per window, not every five minutes.
    local last_stop last_notify
    last_stop="$(awk -F'\t' -v u="$uid" '$1==u{print $2; exit}' "$state_tsv" 2>/dev/null)"
    last_notify="$(awk -F'\t' -v u="$uid" '$1==u{print $3; exit}' "$state_tsv" 2>/dev/null)"
    last_stop="${last_stop:-0}"; last_notify="${last_notify:-0}"
    # A unit this ward already stopped and which has not been raised again is not a live storm:
    # stopping it every five minutes would be the noise this ward exists to remove.
    if [ "$action" = "stop" ] && [ "$last_stop" -gt 0 ] \
       && [ $((now - last_stop)) -lt $((cooldown * 60)) ] \
       && ! case "$active" in active|activating|reloading) true ;; *) false ;; esac; then
      action="already-stopped"
    fi
    say=1
    if [ "$action" != "stop" ] && [ "$last_notify" -gt 0 ] \
       && [ $((now - last_notify)) -lt $((cooldown * 60)) ]; then say=0; fi
    did="not-stopped"
    case "$action" in
      report) did="reported"; reported=$((reported + 1)) ;;
      deferred) did="deferred"; deferred=$((deferred + 1)) ;;
      already-stopped) did="already-stopped"; already=$((already + 1)) ;;
      stop)
        if [ "$dry" = 1 ]; then
          did="would-stop"
        else
          local -a sflags=()
          [ "$uscope" = user ] && sflags=(--user)
          if "$SYSTEMCTL" "${sflags[@]}" stop "$uid" >/dev/null 2>&1; then
            did="stopped"; stopped=$((stopped + 1))
          else
            did="stop-failed"; failed=$((failed + 1))
          fi
        fi
        ;;
    esac
    [ "$say" = 1 ] || quieted=$((quieted + 1))
    # A row is the record of an ACT (or of the first word about it). A quet week's worth of
    # "still down, nothing new" would bury the one pass where it mattered.
    local record=1
    case "$did" in stopped|stop-failed|would-stop) ;; *) [ "$say" = 1 ] || record=0 ;; esac
    [ "$record" = 1 ] && printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$ts" "$uid" "$uscope" "$action" "$did" "$count" "$source" "$say" "$last_error" >> "$found"

    # One message per storm, said in the voice that carries the facts (never a log line alone).
    local sev="HIGH" message=""
    message="restart storm: $uid restarted $count times in $window min (limit $threshold)"
    case "$did" in
      stopped) message="$message — stopped; last error: $last_error" ;;
      would-stop) message="$message — would be stopped (dry run); last error: $last_error" ;;
      stop-failed) sev="CRITICAL"; message="$message — THE STOP FAILED; last error: $last_error" ;;
      deferred) sev="MEDIUM"; message="$message — deferred: a call is held ($holder) and this is the audio family; last error: $last_error" ;;
      reported) sev="MEDIUM"; message="$message — reporting only (the ward is switched off); last error: $last_error" ;;
      already-stopped) message="$message — still down from the ward's own stop; last error: $last_error" ;;
    esac
    if [ "$say" = 1 ] && [ "$dry" = 0 ]; then
      "$NOTIFY" --source ward --severity "$sev" --message "$message" \
        --key "storm-$uid" --target "file:$LEDGER_DIR/$today.jsonl" >/dev/null 2>&1 || true
    fi
  done < "$cands"

  # The ledger rows and the ward's own memory, written once, from the pass's own TSV.
  local rows="$tmp/rows.jsonl"
  : > "$rows"
  if [ -s "$found" ]; then
    SOAK_TS="$ts" SOAK_PASS="$pass" SOAK_HOST="$host" SOAK_WINDOW="$window" \
    SOAK_THRESHOLD="$threshold" SOAK_HOLDER="$holder" SOAK_FOUND="$found" \
    python3 - > "$rows" <<'PY'
import json, os
for line in open(os.environ["SOAK_FOUND"]):
    bits = line.rstrip("\n").split("\t")
    if len(bits) < 9:
        continue
    ts, unit, scope, action, did, count, source, say, last_error = bits[:9]
    print(json.dumps({"ts": ts, "pass": os.environ["SOAK_PASS"], "host": os.environ["SOAK_HOST"],
                      "kind": "storm", "name": unit, "scope": scope, "action": did,
                      "verdict": action, "restarts": int(count), "source": source,
                      "window_minutes": int(os.environ["SOAK_WINDOW"]),
                      "threshold": int(os.environ["SOAK_THRESHOLD"]),
                      "desk": os.environ.get("SOAK_HOLDER", ""),
                      "notified": say == "1", "last_error": last_error},
                     separators=(",", ":")))
PY
  fi
  if [ "$dry" = 1 ]; then
    [ -s "$rows" ] && cat "$rows"
  else
    if [ -s "$rows" ]; then
      mkdir -p "$LEDGER_DIR" 2>/dev/null && cat "$rows" >> "$LEDGER_DIR/$today.jsonl"
    fi
    if [ -s "$found" ]; then
      WARD_STATE="$WARD_STATE" SOAK_FOUND="$found" SOAK_NOW="$now" python3 - <<'PY' 2>/dev/null || true
import json, os
path = os.environ["WARD_STATE"]
try:
    st = json.load(open(path))
    if not isinstance(st, dict):
        st = {}
except Exception:
    st = {}
now = int(os.environ["SOAK_NOW"])
for line in open(os.environ["SOAK_FOUND"]):
    bits = line.rstrip("\n").split("\t")
    if len(bits) < 9:
        continue
    ts, unit, scope, action, did, count, source, say, last_error = bits[:9]
    rec = st.get(unit) or {}
    rec["last_seen"] = now
    rec["last_count"] = int(count)
    rec["last_source"] = source
    rec["last_action"] = did
    rec["last_error"] = last_error
    if did in ("stopped", "stop-failed", "would-stop", "already-stopped"):
        rec["last_stop"] = now
    if say == "1":
        rec["last_notify"] = now
    st[unit] = rec
try:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    json.dump(st, open(tmp, "w"), indent=1, sort_keys=True)
    os.replace(tmp, path)
except Exception:
    pass
PY
    fi
  fi
  rm -rf "$tmp"

  if [ "$json" = 1 ]; then
    printf '{"scope":"%s","threshold":%s,"window_minutes":%s,"candidates":%s,"storms":%s,"stopped":%s,"stop_failed":%s,"deferred":%s,"reported":%s,"counter_only":%s,"already_stopped":%s,"quieted":%s,"desk":"%s"}\n' \
      "$scope" "$threshold" "$window" "$seen" "$storms" "$stopped" "$failed" "$deferred" "$reported" "$countered" "$already" "$quieted" "${holder//\"/}"
  elif [ "$quiet" = 0 ]; then
    printf 'storm,scope=%s,candidates=%s,storms=%s,stopped=%s,failed=%s,deferred=%s,reported=%s,counter_only=%s,already_stopped=%s,threshold=%s,window=%s\n' \
      "$scope" "$seen" "$storms" "$stopped" "$failed" "$deferred" "$reported" "$countered" "$already" "$threshold" "$window"
  fi
  [ "$failed" -eq 0 ] || return 1
  return 0
}

cmd_status() {
  local enabled threshold window scope exclude defer cooldown
  enabled="$(cfg_val restart_storm.enabled true)"; threshold="$(cfg_val restart_storm.threshold 10)"
  window="$(cfg_val restart_storm.window_minutes 60)"; scope="$(cfg_val restart_storm.scope user)"
  exclude="$(cfg_val restart_storm.exclude '')"
  defer="$(cfg_val restart_storm.defer_in_call '^(snotra|speech-to-speech|kokoro|rodd|ymir-voice|pipewire|wireplumber)')"
  cooldown="$(cfg_val restart_storm.cooldown_minutes 60)"
  printf 'config,%s\n' "$CONFIG"
  printf 'enabled,%s [%s]\n' "$enabled" "$(cfg_get restart_storm.enabled true | cut -f2)"
  printf 'threshold,%s [%s]\n' "$threshold" "$(cfg_get restart_storm.threshold 10 | cut -f2)"
  printf 'window_minutes,%s\n' "$window"
  printf 'scope,%s [%s]\n' "$scope" "$(cfg_get restart_storm.scope user | cut -f2)"
  printf 'cooldown_minutes,%s\n' "$cooldown"
  printf 'exclude,%s\n' "${exclude:-(none)}"
  printf 'defer_in_call,%s\n' "$defer"
  printf 'state,%s\n' "$WARD_STATE"
  local holder; holder="$(desk_holder || true)"
  printf 'desk,%s\n' "${holder:-(free)}"
  if [ -f "$WARD_STATE" ]; then
    python3 - "$WARD_STATE" <<'PY'
import json, sys
try:
    st = json.load(open(sys.argv[1]))
except Exception:
    st = {}
for unit in sorted(st):
    rec = st[unit]
    print("warded,%s,last_action=%s,count=%s" % (unit, rec.get("last_action", ""), rec.get("last_count", "")))
PY
  fi
}

case "${1:-pass}" in
  --pass|pass|"") shift || true; cmd_pass "$@" ;;
  --status|status) cmd_status ;;
  -v|--version) printf '%s\n' "$VERSION" ;;
  -h|--help|help) usage ;;
  *) die "unknown action $1" "restart-storm.sh [--pass|--status]" ;;
esac
