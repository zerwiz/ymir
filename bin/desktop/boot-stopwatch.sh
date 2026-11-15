#!/usr/bin/env bash
# boot-stopwatch.sh — how long each Ymir app takes to answer, and whether it stays up (plan 275 item 10).
#
#   boot-stopwatch.sh <app> [--cold] [--watch S] [--json]   one app, timed
#   boot-stopwatch.sh --smoke [--cold] [--watch S]          every app, in turn, against its own budget
#   boot-stopwatch.sh --list                                the registry: class, DevTools port, budgets
#
# The Allfather: "we need to do the boot faster and better of the apps" · "audit the boots" · "can we make the
# boots faster in anyway and more stable". An audit by eye cannot name the second the window took, so this is
# the stopwatch, and it measures the three things a person feels:
#
#   click → window mapped   `ymir-app <app>` is run, and the compositor is asked until the app's own window
#                           class is mapped (bin/desktop/app-lib.sh · app_class — one source of truth).
#   window → first answer   the renderer is asked, over the app's OWN DevTools port
#                           (bin/desktop/app-lib.sh · app_devtools_port, always on), whether its document is
#                           ready AND has painted a body. A mapped white window is NOT an answer — that is the
#                           freeze the Allfather saw: the window maps, the app does not answer.
#   still up, no dialog     for --watch seconds after the click (default 60; 300 is the plan's five minutes)
#                           the window must still be there, and no Hyprland "Application Not Responding" dialog
#                           may have been raised. A dialog is named by the house's own tracer:
#                           browserkill-trace logs `SEND … to=hyprland-dialog`, and a dialog still on screen is
#                           caught by pgrep. One dialog fails the run: it is the user's own evidence.
#
# Every run APPENDS one line to the state ledger, so "the stopwatch will say" is a record, not a memory (the
# 02:35 closes of Smíðja, Óðrerir and Bilskirnir were never proved).
#
# Two laws this obeys, both the Allfather's:
#   The desk. A cold boot is a restart, so it happens ONLY while no call is held — bin/desk/in-call.sh holder
#   must print nothing (exit 3 otherwise, naming the holder). The microphone, the sound and the GPU are his.
#   The open window. An app he has open is not restarted on a worker's word: a cold boot of an open app is
#   REFUSED, and the refusal prints the one line to send the helm. --yes says the helm has answered.
#
# Env: YMIR_BOOT_LAUNCHER  the ymir-app to click (a test tree); default: the installed one, then the pin's.
#      BOOT_BUDGET_{WINDOW,ANSWER}_<APP>  override a budget, in seconds.
# Usage: boot-stopwatch.sh <app|--smoke|--list> [--cold] [--warm] [--watch S] [--yes] [--json] [--timeout S]
# Exit:  0 every measured app is inside its budget · 1 a budget was missed, a dialog fired, or the app died
#        3 the desk is in a call · 4 refused (the app is open; the helm was not asked) · 2 usage
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VERSION="1.0.0"

for _bl in "$HERE/app-lib.sh" "$ROOT/bin/desktop/app-lib.sh"; do
  [ -r "$_bl" ] && { . "$_bl"; break; }
done

APPS_ALL=(hlidskjalf smidja odrerir bilskirnir rodd)          # Sessrúmnir is measured by its own worker
STATE_DIR="${YMIR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}"
LEDGER="$STATE_DIR/boot-stopwatch.jsonl"

# ── the budgets, in seconds, with the reason each one is what it is ────────────────────────────────────────
# window: how long the compositor may take to map the app's window after the click.
# answer: how long the renderer may then take to answer (document ready AND painted).
# A budget is the operator's patience, not the machine's average — the point past which the click feels
# ignored. Each is set close to the measured number (the ledger holds the measurements, the fix note says
# what was cut), because a budget the machine beats every time will one day hide a regression.
budget_window() {  # <app>
  case "${1-}" in
    hlidskjalf) printf '%s' "${BOOT_BUDGET_WINDOW_HLIDSKJALF:-3.0}" ;;
    smidja)     printf '%s' "${BOOT_BUDGET_WINDOW_SMIDJA:-3.0}" ;;
    odrerir)    printf '%s' "${BOOT_BUDGET_WINDOW_ODRERIR:-3.0}" ;;
    bilskirnir) printf '%s' "${BOOT_BUDGET_WINDOW_BILSKIRNIR:-8.0}" ;;
    rodd)       printf '%s' "${BOOT_BUDGET_WINDOW_RODD:-8.0}" ;;
    *)          printf '%s' "${BOOT_BUDGET_WINDOW_DEFAULT:-5.0}" ;;
  esac
}
budget_answer() {  # <app>
  case "${1-}" in
    hlidskjalf) printf '%s' "${BOOT_BUDGET_ANSWER_HLIDSKJALF:-6.0}" ;;
    smidja)     printf '%s' "${BOOT_BUDGET_ANSWER_SMIDJA:-6.0}" ;;
    odrerir)    printf '%s' "${BOOT_BUDGET_ANSWER_ODRERIR:-6.0}" ;;
    bilskirnir) printf '%s' "${BOOT_BUDGET_ANSWER_BILSKIRNIR:-12.0}" ;;
    rodd)       printf '%s' "${BOOT_BUDGET_ANSWER_RODD:-12.0}" ;;
    *)          printf '%s' "${BOOT_BUDGET_ANSWER_DEFAULT:-8.0}" ;;
  esac
}

now_ms() { date +%s%3N; }
secs() { awk -v a="${1:-0}" -v b="${2:-0}" 'BEGIN{ if (!b || b <= a) { print "0.00"; exit } printf "%.2f", (b - a) / 1000 }'; }
over() { awk -v a="${1:-0}" -v b="${2:-0}" 'BEGIN{ exit !(a > b) }'; }
clean() { printf '%s' "$1" | tr '\n\t' '  ' | tr '"' "'" | sed 's/[[:space:]]*$//'; }

# ── the one launcher a click runs ──────────────────────────────────────────────────────────────────────────
# The apps run from the PIN, never from a worker's worktree (RULES/02 §7): `ymir-app` resolves the pin itself,
# and even a worktree's copy hands over to it. YMIR_BOOT_LAUNCHER names another launcher, loudly, for a test.
launcher() {
  if [ -n "${YMIR_BOOT_LAUNCHER:-}" ]; then printf '%s' "$YMIR_BOOT_LAUNCHER"; return 0; fi
  local c; c="$(command -v ymir-app 2>/dev/null || true)"
  [ -n "$c" ] && { printf '%s' "$c"; return 0; }
  [ -x "$HERE/ymir-app" ] && { printf '%s' "$HERE/ymir-app"; return 0; }
  return 1
}
tree_of_launcher() {  # the tree that launcher belongs to — its apps, its scripts
  local l; l="$(launcher)" || return 1
  if [ -n "${YMIR_BOOT_LAUNCHER:-}" ]; then ( cd "$(dirname "$l")/../.." && pwd ); else bash "$l" --where 2>/dev/null || true; fi
}

# ── is the window open, and is the desk in a call? ────────────────────────────────────────────────────────
window_state() {  # <class> [loose-suffix] → address<TAB>workspace<TAB>the window's real class
  # The registry's class is what the window MUST present (app_class). A window that merely ends in the app's
  # name is still found — and its real class is returned, so a misnamed window is NAMED in the report instead of
  # silently making an app invisible (Rödd presented `zerwiz-rodd` from its package name until 2026-11-14, which
  # is exactly how a routing table and a window come to disagree without anyone noticing).
  command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl clients -j 2>/dev/null | CLS="${1-}" LOOSE="${2-}" python3 -c '
import json, os, sys
try:
    ws = json.load(sys.stdin)
except Exception:
    sys.exit(0)
cls, loose = os.environ["CLS"], os.environ["LOOSE"]
def live(w):
    return w.get("mapped", True)
def emit(w):
    print("%s\t%s\t%s" % (w.get("address", ""), (w.get("workspace") or {}).get("id", ""), w.get("class", "")))
for w in ws:
    if w.get("class") == cls and live(w):
        emit(w); sys.exit(0)
if loose:
    for w in ws:
        c = w.get("class") or ""
        if live(w) and (c == loose or c.endswith("-" + loose) or c.endswith("_" + loose)):
            emit(w); sys.exit(0)
' 2>/dev/null
}

desk_held() {  # the holder's name when a call is being held on this desk, nothing when the desk is free
  local h
  [ -x "$ROOT/bin/desk/in-call.sh" ] || return 0
  h="$(bash "$ROOT/bin/desk/in-call.sh" holder 2>/dev/null || true)"
  [ -n "$h" ] && printf '%s' "$h"
  return 0
}

# ── dialogs: the not-responding window, named ─────────────────────────────────────────────────────────────
# browserkill-trace (bpftrace, /etc/ymir/browserkill.bt) logs every fatal signal with its SENDER, so a Hyprland
# "Application Not Responding" dialog appears as `to=hyprland-dialog`. The process is also caught live,
# because a dialog may still be on screen when the watch ends.
dialogs_since() {  # <epoch-seconds>
  local n
  n="$(journalctl -q -u browserkill-trace --since "@${1:-0}" --no-pager 2>/dev/null | grep -c 'to=hyprland-dialog' || true)"
  printf '%s' "${n:-0}"
}
dialogs_live() {
  local n
  n="$(pgrep -x hyprland-dialog 2>/dev/null | wc -l)"
  printf '%s' "${n:-0}"
}

# ── start, and stop ───────────────────────────────────────────────────────────────────────────────────────
launch() {  # <app> <log> → the click's pid
  local app="$1" log="$2" l port
  l="$(launcher)" || { printf 'error: no ymir-app to click — run bin/desktop/shortcuts.sh\n' >&2; return 1; }
  mkdir -p "$STATE_DIR"
  # The port the app will answer on — its own fixed one (bin/desktop/app-lib.sh). It is exported so the
  # measurement also works on a tree that has not yet wired the always-on door; it is the SAME value that door
  # uses, so a wired app reads it as a redundant confirmation and never as a second opinion.
  port="$(app_devtools_port "$app" 2>/dev/null || true)"
  ( [ -n "$port" ] && export YMIR_DEVTOOLS_PORT="$port"
    exec "$l" "$app" ) >"$log" 2>&1 < /dev/null &
  printf '%s' "$!"
}

stop_app() {  # <app> — lower the app by its own door, never by pattern
  local app="$1" tree i
  tree="$(tree_of_launcher 2>/dev/null || true)"
  case "$app" in
    hlidskjalf|smidja|odrerir)
      [ -n "$tree" ] && [ -r "$tree/scripts/electron.sh" ] && bash "$tree/scripts/electron.sh" stop --view "$app" >/dev/null 2>&1 ;;
    bilskirnir)
      [ -n "$tree" ] && [ -x "$tree/apps/bilskirnir/start.sh" ] && bash "$tree/apps/bilskirnir/start.sh" --stop >/dev/null 2>&1 ;;
    rodd)
      # Rödd's window is raised by her unit OR by her own start.sh — both are lowered, because either may be
      # what a click began (ymir-app restarts the unit; a test tree runs start.sh directly). Each door is
      # idempotent, so asking both never stops anything twice.
      systemctl --user stop ymir-rodd.service >/dev/null 2>&1 || true
      [ -n "$tree" ] && [ -x "$tree/apps/rodd/start.sh" ] && bash "$tree/apps/rodd/start.sh" --stop >/dev/null 2>&1 ;;
  esac
  for i in $(seq 1 40); do            # the window must be gone before the next boot is called cold
    [ -z "$(window_state "$(app_class "$app")" "$app")" ] && return 0
    sleep 0.25
  done
  return 0
}

# ── one app, timed. measure() writes RESULT_* and never prints. ────────────────────────────────────────────
measure() {  # <app> <cold|warm> <watch-seconds> <timeout-seconds>
  local app="$1" mode="$2" watch="$3" timeout="$4"
  local cls port t_click t_window t_answer deadline log out last
  cls="$(app_class "$app")"
  port="$(app_devtools_port "$app" 2>/dev/null || true)"
  log="$STATE_DIR/boot-$app.log"

  RESULT_WINDOW_MS=""; RESULT_ANSWER_MS=""; RESULT_DIALOGS=0; RESULT_ALIVE=1
  RESULT_VERDICT="fail"; RESULT_WHY=""; RESULT_MODE="$mode"; RESULT_PORT="${port:-0}"; RESULT_CLASS="$cls"
  RESULT_BW="$(budget_window "$app")"; RESULT_BA="$(budget_answer "$app")"

  # 1 · the click
  t_click="$(now_ms)"
  launch "$app" "$log" >/dev/null || { RESULT_WHY="no launcher to click"; return 0; }

  # 2 · click → window mapped
  t_window=""; deadline=$(( $(date +%s) + timeout ))
  while [ "$(date +%s)" -le "$deadline" ]; do
    local seen; seen="$(window_state "$cls" "$app")"
    if [ -n "$seen" ]; then
      t_window="$(now_ms)"; RESULT_CLASS="$(printf '%s' "$seen" | cut -f3)"
      break
    fi
    sleep 0.1
  done
  [ -n "$t_window" ] || { RESULT_WHY="no $cls window in ${timeout}s — see $log"; return 0; }
  [ "$RESULT_CLASS" = "$cls" ] || printf 'warning: %s presented its window as "%s", not "%s" — the routing table and the window disagree\n' \
    "$app" "$RESULT_CLASS" "$cls" >&2

  # 3 · window → first answer, asked IN the window over its own DevTools port
  if [ -z "$port" ]; then
    RESULT_WHY="no DevTools port for $app — name one in bin/desktop/app-lib.sh"
  else
    deadline=$(( $(date +%s) + timeout ))
    while [ "$(date +%s)" -le "$deadline" ]; do
      out="$(node "$HERE/devtools.cjs" ask "$port" 2>/dev/null || true)"
      case "$out" in *'"ok":true'*'"painted":true'*) t_answer="$(now_ms)"; break ;; esac
      sleep 0.2
    done
  fi

  RESULT_WINDOW_MS="$(secs "$t_click" "$t_window")"
  [ -n "${t_answer:-}" ] && RESULT_ANSWER_MS="$(secs "$t_window" "$t_answer")"

  # 4 · the watch: still up, and no not-responding dialog
  local t_end why=""
  t_end=$(( $(date +%s) + watch ))
  while [ "$(date +%s)" -le "$t_end" ]; do
    if [ -z "$(window_state "$cls" "$app")" ]; then
      RESULT_ALIVE=0; why="the window went away inside the ${watch}s watch"; break
    fi
    sleep 2
  done
  RESULT_DIALOGS=$(( $(dialogs_since $(( t_click / 1000 ))) + $(dialogs_live) ))

  # 5 · the verdict, and the reason it is that
  if [ -z "${t_answer:-}" ]; then
    last="$(node "$HERE/devtools.cjs" ask "$port" 2>/dev/null || true)"
    RESULT_WHY="no answer in ${timeout}s — ${last:-the DevTools door did not answer}"
  elif over "$RESULT_WINDOW_MS" "$RESULT_BW"; then
    RESULT_WHY="${why:+$why; }window ${RESULT_WINDOW_MS}s > budget ${RESULT_BW}s"
  elif over "$RESULT_ANSWER_MS" "$RESULT_BA"; then
    RESULT_WHY="${why:+$why; }answer ${RESULT_ANSWER_MS}s > budget ${RESULT_BA}s"
  elif [ "$RESULT_ALIVE" != 1 ]; then
    RESULT_WHY="$why"
  elif [ "$RESULT_DIALOGS" -gt 0 ]; then
    RESULT_WHY="${RESULT_DIALOGS} not-responding dialog(s) — journalctl -u browserkill-trace | grep hyprland-dialog"
  else
    RESULT_VERDICT="pass"
  fi
  return 0
}

# ── the registry, the ledger, the report ─────────────────────────────────────────────────────────────────
list_registry() {
  printf 'boot-stopwatch[%s]{app,class,devtools,budget_window_s,budget_answer_s}:\n' "${#APPS_ALL[@]}"
  local a
  for a in "${APPS_ALL[@]}"; do
    printf '  "%s","%s",%s,%s,%s\n' "$a" "$(app_class "$a")" "$(app_devtools_port "$a")" \
      "$(budget_window "$a")" "$(budget_answer "$a")"
  done
}

ledger_append() {  # one line per run; appended, never rewritten (Rule 06)
  mkdir -p "$STATE_DIR"
  printf '{"ts":"%s","app":"%s","mode":"%s","port":%s,"window_s":%s,"answer_s":%s,"budget_window_s":%s,"budget_answer_s":%s,"dialogs":%s,"alive":%s,"verdict":"%s","why":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "${RESULT_MODE:-cold}" "${RESULT_PORT:-0}" \
    "${RESULT_WINDOW_MS:-null}" "${RESULT_ANSWER_MS:-null}" "${RESULT_BW:-0}" "${RESULT_BA:-0}" \
    "${RESULT_DIALOGS:-0}" "${RESULT_ALIVE:-0}" "${RESULT_VERDICT:-fail}" \
    "$(clean "${RESULT_WHY:-}")" >> "$LEDGER" 2>/dev/null || true
}

# ── arguments ────────────────────────────────────────────────────────────────────────────────────────────
MODE="cold"; WATCH=60; TIMEOUT=60; YES=0; JSON=0; SMOKE=0; APP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --smoke) SMOKE=1 ;;
    --cold) MODE="cold" ;;
    --warm) MODE="warm" ;;
    --watch) shift; WATCH="${1:-60}" ;;
    --timeout) shift; TIMEOUT="${1:-60}" ;;
    --yes) YES=1 ;;
    --json) JSON=1 ;;
    --list) list_registry; exit 0 ;;
    -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) printf 'error: unknown flag %s\nhelp: boot-stopwatch.sh <app>|--smoke|--list [--cold|--warm] [--watch S] [--yes] [--json]\n' "$1" >&2; exit 2 ;;
    *) APP="$1" ;;
  esac
  shift
done
if [ "$SMOKE" = 0 ]; then
  [ -n "$APP" ] || { printf 'error: name an app, or --smoke, or --list\n' >&2; exit 2; }
  case " ${APPS_ALL[*]} " in *" $APP "*) ;; *) printf 'error: no app named %s (boot-stopwatch.sh --list)\n' "$APP" >&2; exit 2 ;; esac
fi

# The desk comes first: a cold boot restarts an app, and a live call owns the desk.
if [ "$MODE" = cold ]; then
  held="$(desk_held)"
  if [ -n "$held" ]; then
    printf 'refused: %s holds the microphone — the operator is in a call, so no app is restarted now\n' "$held" >&2
    printf 'hint: run it after the call (bin/desk/in-call.sh holder prints nothing when the desk is free)\n' >&2
    exit 3
  fi
fi

if [ "$SMOKE" = 1 ]; then set -- "${APPS_ALL[@]}"; else set -- "$APP"; fi

FAILED=0; REC="$(mktemp)"; trap 'rm -f "$REC"' EXIT
for app in "$@"; do
  cls="$(app_class "$app")"
  # An app the Allfather has open is not restarted on a worker's word.
  if [ "$MODE" = cold ] && [ -n "$(window_state "$cls" "$app")" ] && [ "$YES" != 1 ]; then
    printf 'refused: %s is open — tell the helm first, then say --yes\n' "$cls" >&2
    printf '  bin/agents/eindri-send.sh --from "agent boot-stopwatch" w39:pT "restarting %s for the boot stopwatch — say if it must stay open"\n' "$app" >&2
    printf '  boot-stopwatch.sh %s --cold --yes\n' "$app" >&2
    exit 4
  fi
  [ "$MODE" = cold ] && stop_app "$app"

  measure "$app" "$MODE" "$WATCH" "$TIMEOUT"
  ledger_append "$app"
  [ "$RESULT_VERDICT" = pass ] || FAILED=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$app" "${RESULT_CLASS:-$cls}" "${RESULT_PORT:-0}" "${RESULT_MODE:-$MODE}" "${RESULT_WINDOW_MS:--}" "${RESULT_ANSWER_MS:--}" \
    "${RESULT_BW:-0}" "${RESULT_BA:-0}" "${RESULT_DIALOGS:-0}" "$([ "${RESULT_ALIVE:-1}" = 1 ] && printf up || printf gone)" \
    "$RESULT_VERDICT" "$(clean "${RESULT_WHY:-}")" >> "$REC"
done

if [ "$JSON" = 1 ]; then
  python3 - "$REC" "$FAILED" <<'PY'
import json, sys
rows = []
for line in open(sys.argv[1]):
    f = line.rstrip("\n").split("\t")
    if len(f) < 12: continue
    num = lambda v: (float(v) if v not in ("", "null", "-") else None)
    rows.append({"app": f[0], "class": f[1], "devtools": int(f[2]), "mode": f[3],
                 "window_s": num(f[4]), "answer_s": num(f[5]),
                 "budget_window_s": float(f[6]), "budget_answer_s": float(f[7]),
                 "dialogs": int(f[8]), "alive": f[9] == "up", "verdict": f[10], "why": f[11]})
print(json.dumps({"apps": rows, "failed": int(sys.argv[2])}, separators=(",", ":")))
PY
else
  printf 'boot-stopwatch[%s]{app,class,devtools,mode,window_s,answer_s,budget_window_s,budget_answer_s,dialogs,alive,verdict,why}:\n' "$(wc -l < "$REC" | tr -d ' ')"
  while IFS=$'\t' read -r a c p m w an bw ba d al v why; do
    printf '  "%s","%s",%s,"%s","%s","%s",%s,%s,%s,"%s","%s","%s"\n' \
      "$a" "$c" "$p" "$m" "$( [ "$w" = - ] && printf '—' || printf '%s' "$w")" "$( [ "$an" = - ] && printf '—' || printf '%s' "$an")" \
      "$bw" "$ba" "$d" "$al" "$v" "$why"
  done < "$REC"
fi
exit "$FAILED"
