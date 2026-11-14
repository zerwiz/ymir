#!/usr/bin/env bash
# soak.sh — raise one app from the pin and soak it for leaks (plan 286 P1, P2, P5).
#
#   soak.sh <app> [flags]
#   soak.sh --list
#   soak.sh --pr-range <base>..<head>      # P5: soak the apps a change touches
#   soak.sh --status
#
# WHAT IT DOES. It raises the app from the pinned runtime (`~/ymir-runtime`, never a
# working tree — RULES/51) on that app's FIXED loopback DevTools port (9311-9316, plan
# 275 item 19), takes a baseline (RSS, JS heap after a forced GC, file descriptors,
# inotify watches, children, GPU memory), drives every page of the app N times through
# DevTools, lets it idle, samples every 30 s, and judges every number against the
# budgets in plan 286 section 5. One JSON row per measurement lands in
#   $YMIR_HOME/state/soak/<app>/<date>.jsonl
# so a leak is a file, not a memory of one. When a number grows past budget it takes a
# heap snapshot, a sampling heap profile and a 10 s CPU profile and NAMES the largest
# allocating call sites and the hottest functions — the method that found Sessrúmnir's
# walk over 198 worktrees.
#
# WHAT IT WILL NOT DO. It never restarts, drives or closes a window the Allfather has
# open: an app already running is measured where it sits only when it answers on its
# DevTools port, and otherwise the soak is a named skip. It raises its own instance in
# a throwaway profile and closes exactly what it raised. It refuses to start while
# `bin/desk/in-call.sh holder` names a call.
#
# Exit: 0 the soak passed · 1 a leak was found · 2 usage · 3 could not raise or attach.
#
# Examples:
#   bin/gates/soak.sh sessrumnir                    # the plan's own case
#   bin/gates/soak.sh hlidskjalf --cycles 20 --idle 1800
#   bin/gates/soak.sh sessrumnir --root ~/.local/share/ymir/releases/babae37aa7b8
#   bin/gates/soak.sh --pr-range origin/main..HEAD
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOAK_DIR="$SELF_DIR/soak"
DRIVER="$SOAK_DIR/cdp.mjs"
# The window class is defined in ONE place (bin/desktop/app-lib.sh, with the .desktop
# StartupWMClass and the electron app.setName slug); ask it, never a second table.
if [ -r "$SELF_DIR/../desktop/app-lib.sh" ]; then . "$SELF_DIR/../desktop/app-lib.sh"; fi
command -v app_class >/dev/null 2>&1 || app_class() { printf '%s' "ymir-${1-}"; }

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }

# ── the home, resolved once (never a hardcoded path) ────────────────────────────
hoard_root() {
  if [ -n "${YMIR_HOME:-}" ]; then printf '%s' "$YMIR_HOME"; return 0; fi
  local lib; lib="$(cd "$SELF_DIR/.." && pwd)/vault/hoard-lib.sh"
  if [ -r "$lib" ]; then ( . "$lib"; hoard_root ) 2>/dev/null && return 0; fi
  printf '%s' "$HOME/Documents/ymirhome"
}
HOME_DIR="$(hoard_root)"

# ── the pin: apps run from a release, never from a checkout ─────────────────────
pin_root() {
  local pin="${YMIR_RUNTIME_DIR:-}"
  if [ -z "$pin" ]; then
    local conf="$HOME_DIR/config/runtime.env"
    [ -r "$conf" ] && pin="$(sed -n 's/^[[:space:]]*YMIR_RUNTIME_DIR[[:space:]]*=[[:space:]]*//p' "$conf" | head -1 | tr -d "\"'")"
    pin="${pin//\$\{HOME\}/$HOME}"; pin="${pin//\$HOME/$HOME}"
  fi
  [ -n "$pin" ] || pin="$HOME/ymir-runtime"
  readlink -f "$pin" 2>/dev/null || printf '%s' "$pin"
}

# ── the app registry: one place, no second table ─────────────────────────────────
# The DevTools ports are FIXED and loopback, in plan 275 item 19's range: an inspector
# must never have to guess which port a window opened on, and an app must never need a
# restart to become inspectable.
app_port() {
  case "${1-}" in
    hlidskjalf) printf '%s' "${YMIR_DEVTOOLS_PORT:-9311}" ;;
    smidja)     printf '%s' "${YMIR_DEVTOOLS_PORT:-9312}" ;;
    odrerir)    printf '%s' "${YMIR_DEVTOOLS_PORT:-9313}" ;;
    sessrumnir) printf '%s' "${YMIR_DEVTOOLS_PORT:-9314}" ;;
    bilskirnir) printf '%s' "${YMIR_DEVTOOLS_PORT:-9315}" ;;
    rodd)       printf '%s' "${YMIR_DEVTOOLS_PORT:-9316}" ;;
    *) return 1 ;;
  esac
}

# The pages each app presents, read from the app's own router. A page the app does not
# have is not invented here: an app with no hash routes is driven by reloading it, which
# is exactly the start-up path most leaks sit on (Sessrúmnir's did).
app_routes() {
  case "${1-}" in
    hlidskjalf) printf '%s' '#/skirnir,#/fleet,#/tasks,#/well,#/runes,#/reviews,#/processes,#/files,#/chat,#/forge,#/runtime,#/cron,#/sessions,#/worktrees,#/trace,#/decisions,#/stats,#/managandr,#/snotra,#/mail,#/profile' ;;
    odrerir)    printf '%s' '#/hall,#/near,#/tickets,#/plans' ;;
    smidja)     printf '%s' '#/,#/memory,#/decisions,#/stats,#/chat,#/settings' ;;
    sessrumnir|bilskirnir|rodd) printf '%s' '' ;;   # no hash router: drive by reload
    *) return 1 ;;
  esac
}

app_kind() {
  case "${1-}" in
    hlidskjalf|smidja|odrerir|sessrumnir|bilskirnir|rodd) printf '%s' electron ;;
    hlidskjalf-gate|hlidskjalf-spa|smidja-server|odrerir-server|bilskirnir-server) printf '%s' server ;;
    *) return 1 ;;
  esac
}

# A server's own door, its health path and the paths a soak asks it for.
server_port() {
  case "${1-}" in
    hlidskjalf-gate) printf '%s' 3889 ;;
    hlidskjalf-spa)  printf '%s' 3888 ;;
    smidja-server)   printf '%s' 8437 ;;
    odrerir-server)  printf '%s' 4322 ;;
    bilskirnir-server) printf '%s' 8787 ;;
    *) return 1 ;;
  esac
}
server_paths() {
  case "${1-}" in
    hlidskjalf-gate) printf '%s' '/api/agents,/api/tasks,/api/usage,/api/runes,/api/processes,/api/files?realm=work,/api/runtime,/api/streams' ;;
    hlidskjalf-spa)  printf '%s' '/,/assets/' ;;
    smidja-server)   printf '%s' '/api/runs,/api/stats' ;;
    odrerir-server)  printf '%s' '/api/board,/api/tickets' ;;
    bilskirnir-server) printf '%s' '/api/health' ;;
    *) return 1 ;;
  esac
}
server_raise_hint() {
  case "${1-}" in
    hlidskjalf-gate|hlidskjalf-spa) printf '%s' 'bash <root>/apps/hlidskjalf/scripts/start.sh' ;;
    smidja-server)   printf '%s' 'bash <root>/scripts/start.sh smidja' ;;
    odrerir-server)  printf '%s' 'bash <root>/apps/odrerir/scripts/start.sh' ;;
    bilskirnir-server) printf '%s' 'bash <root>/apps/bilskirnir/start.sh --headless' ;;
    *) printf '%s' '(no start script known)' ;;
  esac
}

# ── budgets (plan 286 §5), overridable from $YMIR_HOME/config/soak.yaml ─────────
budget() {  # <key> <default>
  local f="$HOME_DIR/config/soak.yaml" v=""
  if [ -r "$f" ]; then
    v="$(sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$f" | head -1 | sed 's/[[:space:]]*#.*$//' | tr -d "\"' ")"
  fi
  [ -n "$v" ] && printf '%s' "$v" || printf '%s' "$2"
}
B_RSS_IDLE="$(budget rss_idle_pct 5)"
B_RSS_CYCLE="$(budget rss_cycle_pct 10)"
B_HEAP_IDLE="$(budget heap_idle_mb 2)"
B_HEAP_CYCLE="$(budget heap_cycle_mb 5)"
B_FDS="$(budget fds_delta 2)"
# `flat` for watches means "does not grow with the work": a watcher that re-arms once when the
# window reloads adds a watch or two and then stops, and that is not a leak. Measured on
# Sessrúmnir (plan 286 P1): 2 watches over 20 reloads, the same 2 at 5 and at 20 — a re-arm,
# not a drip. A per-pass leak passes this budget on pass 3 and is caught by pass 20.
B_WATCHES="$(budget watches_delta 2)"
B_CHILDREN="$(budget children_delta 0)"
B_LONGTASK_IDLE="$(budget longtask_idle_ms 200)"
B_LONGTASK_CYCLE="$(budget longtask_cycle_ms 1000)"
B_DIALOGS="$(budget dialogs 0)"

# ── flags ───────────────────────────────────────────────────────────────────────
APP=""; ROOT=""; CYCLES="$(budget cycles 20)"; IDLE="$(budget idle_seconds 1800)"; SAMPLE="$(budget sample_seconds 30)"
SETTLE="$(budget settle_ms 900)"; KEEP=0; ATTACH=0; JSON=0; QUICK=0; PR_RANGE=""; LIST=0; STATUS=0
ARTIFACTS=1; SNAPSHOT="${YMIR_SOAK_SNAPSHOT:-on-breach}"; VERBOSE=0
SAID_CYCLES=0; SAID_IDLE=0; SAID_SAMPLE=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --list)    LIST=1 ;;
    --status)  STATUS=1 ;;
    --root)    ROOT="${2-}"; shift ;;
    --cycles)  CYCLES="${2-}"; SAID_CYCLES=1; shift ;;
    --idle)    IDLE="${2-}"; shift ;;
    --sample)  SAMPLE="${2-}"; SAID_SAMPLE=1; shift ;;
    --settle)  SETTLE="${2-}"; shift ;;
    --quick)   QUICK=1 ;;
    --keep-open) KEEP=1 ;;
    --attach)  ATTACH=1 ;;
    --json)    JSON=1 ;;
    --no-artifacts) ARTIFACTS=0 ;;
    --snapshot) SNAPSHOT="${2-}"; shift ;;
    --pr-range) PR_RANGE="${2-}"; shift ;;
    -v|--verbose) VERBOSE=1 ;;
    --) shift; break ;;
    -*) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
    *)  [ -z "$APP" ] && APP="$1" || { printf 'error: one app at a time (got %s and %s)\n' "$APP" "$1" >&2; exit 2; } ;;
  esac
  shift
done

[ -n "$ROOT" ] || ROOT="$(pin_root)"
[ -d "$ROOT" ] || { printf 'error: no runtime at %s — run bin/engine/ymir-install.sh, or pass --root\n' "$ROOT" >&2; exit 2; }
[ -r "$DRIVER" ] || { printf 'error: the driver is missing at %s\n' "$DRIVER" >&2; exit 2; }

if [ "$QUICK" = 1 ]; then
  # The gate's short soak (P5): the same measurements over a window a push can wait for.
  # A flag the caller gave wins over the short window — a gate may lengthen it, never
  # silently get something other than what it asked for.
  [ "$SAID_CYCLES" = 1 ] || CYCLES="${QUICK_CYCLES:-5}"
  [ "$SAID_IDLE" = 1 ]   || IDLE="${QUICK_IDLE:-90}"
  [ "$SAID_SAMPLE" = 1 ] || SAMPLE="${QUICK_SAMPLE:-15}"
fi

if [ "$LIST" = 1 ]; then
  printf 'soak_apps[11]{app,kind,door,pages}\n'
  for a in hlidskjalf smidja odrerir sessrumnir bilskirnir rodd; do
    r="$(app_routes "$a")"; n=0; [ -n "$r" ] && n="$(printf '%s' "$r" | tr ',' '\n' | grep -c .)"
    [ "$n" = 0 ] && pages='reload' || pages="$n"
    printf '  "%s","electron","%s","%s"\n' "$a" "$(app_port "$a")" "$pages"
  done
  for a in hlidskjalf-gate hlidskjalf-spa smidja-server odrerir-server bilskirnir-server; do
    printf '  "%s","server","%s","http"\n' "$a" "$(server_port "$a")"
  done
  exit 0
fi

if [ "$STATUS" = 1 ]; then
  printf 'soak_status[6]{key,value}\n'
  printf '  "root","%s"\n' "$ROOT"
  printf '  "home","%s"\n' "$HOME_DIR"
  printf '  "ledger","%s"\n' "$HOME_DIR/state/soak"
  printf '  "budgets","rss %s%% idle / %s%% cycles · heap %s MB / %s MB · fds flat(%s) · watches flat · children flat · longtask %s ms / %s ms"\n' \
    "$B_RSS_IDLE" "$B_RSS_CYCLE" "$B_HEAP_IDLE" "$B_HEAP_CYCLE" "$B_FDS" "$B_LONGTASK_IDLE" "$B_LONGTASK_CYCLE"
  desk="$(bash "$SELF_DIR/../desk/in-call.sh" holder 2>/dev/null | tr -d '\n')"
  printf '  "desk","%s"\n' "${desk:-free}"
  printf '  "running","%s"\n' "$(for a in hlidskjalf smidja odrerir sessrumnir bilskirnir rodd; do
      p="$(app_port "$a" 2>/dev/null)"; curl -fsS --max-time 0.4 "http://127.0.0.1:$p/json/version" >/dev/null 2>&1 && printf '%s ' "$a"; done)"
  exit 0
fi

# ── P5: which apps does this change touch? ──────────────────────────────────────
if [ -n "$PR_RANGE" ]; then
  base="${PR_RANGE%%..*}"; head="${PR_RANGE##*..}"
  repo="${YMIR_SOAK_REPO:-$(cd "$SELF_DIR/.." && pwd)}"   # a test plants its own repo
  changed="$(git -C "$repo" diff --name-only "$base" "$head" 2>/dev/null)"
  [ -n "$changed" ] || { printf 'soak_pr[1]{gate,status,detail}:\n  "soak","SKIP","no changed files could be listed for %s"\n' "$PR_RANGE"; exit 0; }
  apps=""
  while IFS= read -r f; do
    case "$f" in
      apps/sessrumnir/*)  apps="$apps sessrumnir" ;;
      apps/bilskirnir/*)  apps="$apps bilskirnir" ;;
      apps/rodd/*)        apps="$apps rodd" ;;
      apps/odrerir/*)     apps="$apps odrerir odrerir-server" ;;
      apps/smidja-factory/apps/visualizer/*) apps="$apps smidja smidja-server" ;;
      apps/hlidskjalf/*)  apps="$apps hlidskjalf hlidskjalf-gate hlidskjalf-spa" ;;
    esac
  done <<<"$changed"
  apps="$(printf '%s\n' $apps | sort -u | tr '\n' ' ')"
  if [ -z "${apps// /}" ]; then
    printf 'soak_pr[1]{gate,status,detail}:\n  "soak","SKIP","no app changed in %s"\n' "$PR_RANGE"; exit 0
  fi
  fails=0
  printf 'soak_pr[%s]{app,verdict,detail}:\n' "$(printf '%s\n' $apps | grep -c .)"
  for a in $apps; do
    out="$(bash "$0" "$a" --quick --json 2>&1)"; rc=$?
    case "$rc" in
      0) printf '  "%s","PASS","short soak within budget"\n' "$a" ;;
      3) printf '  "%s","SKIP","could not be raised here — see the reason in the row"\n' "$a" ;;
      4) printf '  "%s","SKIP","the desk is in a call — no app is restarted while it is"\n' "$a" ;;
      *) printf '  "%s","FAIL","a leak: %s"\n' "$a" "$(printf '%s\n' "$out" | grep -o '"leaks":\[[^]]*\]' | head -1)"; fails=1 ;;
    esac
  done
  [ "$fails" = 1 ] && exit 1 || exit 0
fi

[ -n "$APP" ] || { usage >&2; exit 2; }
KIND="$(app_kind "$APP")" || { printf 'error: unknown app %s (soak.sh --list)\n' "$APP" >&2; exit 2; }

# ── the ledger ──────────────────────────────────────────────────────────────────
LEDGER_DIR="$HOME_DIR/state/soak/$APP"
mkdir -p "$LEDGER_DIR/artifacts" || { printf 'error: cannot write %s\n' "$LEDGER_DIR" >&2; exit 2; }
[ -f "$LEDGER_DIR/.gitignore" ] || printf 'artifacts/\n*.heapsnapshot\n' >"$LEDGER_DIR/.gitignore"
LEDGER="$LEDGER_DIR/$(date -u +%Y-%m-%d).jsonl"
RUN="$(date +%s)-$$"   # this soak's rows, so a judge never mixes two runs
LOCK="$LEDGER_DIR/.soak.lock"

# One soak per app at a time: two soaks on one window measure each other.
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  printf 'soak[2]{app,status,detail}:\n  "%s","SKIP","another soak is running (pid %s)"\n' "$APP" "$(cat "$LOCK")"
  exit 3
fi
printf '%s\n' "$$" >"$LOCK"
cleanup_lock() { rm -f "$LOCK"; }
trap cleanup_lock EXIT

# ── the desk guard: no app is raised while a call is held ───────────────────────
desk="$(bash "$SELF_DIR/../desk/in-call.sh" holder 2>/dev/null | tr -d '\n')"
if [ -n "$desk" ]; then
  printf 'soak[2]{app,status,detail}:\n  "%s","SKIP","the desk is in a call (%s) — no app restarts while it is"\n' "$APP" "$desk"
  printf '{"ts":"%s","app":"%s","kind":"skip","reason":"desk call","held_by":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$APP" "$desk" >>"$LEDGER"
  exit 4
fi

row() { printf '%s\n' "$1" >>"$LEDGER"; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
say() { [ "$JSON" = 1 ] || printf '%s\n' "$*"; }

START_EPOCH="$(date +%s)"
row "{\"ts\":\"$(now)\",\"app\":\"$APP\",\"kind\":\"raise\",\"reply_to\":\"\",\"root\":\"$ROOT\",\"cycles\":$CYCLES,\"idle_seconds\":$IDLE,\"sample_seconds\":$SAMPLE}"

# ── servers: measured where they run (a process and its HTTP door) ──────────────
if [ "$KIND" = server ]; then
  PORT="$(server_port "$APP")"
  PID=""
  if ss -tlnp 2>/dev/null | grep -q "127.0.0.1:$PORT \|0.0.0.0:$PORT "; then
    PID="$(ss -tlnp 2>/dev/null | awk -v p=":$PORT" '$4 ~ p {print $0}' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)"
  fi
  if [ -z "$PID" ]; then
    printf 'soak[2]{app,status,detail}\n  "%s","SKIP","nothing answers on :%s — raise it with: %s"\n' "$APP" "$PORT" "$(server_raise_hint "$APP" | sed "s#<root>#$ROOT#")"
    printf '{"ts":"%s","app":"%s","kind":"skip","reason":"not listening","port":%s}\n' "$(now)" "$APP" "$PORT" >>"$LEDGER"
    exit 3
  fi
  row "{\"run\":\"$RUN\",\"ts\":\"$(now)\",\"app\":\"$APP\",\"kind\":\"attach\",\"pid\":$PID,\"port\":$PORT,\"how\":\"already listening\"}"
  base="$(node "$DRIVER" --measure-pid "$PID" --cpu-state "$LEDGER_DIR/.cpu-state.json" 2>/dev/null)"
  row "$(printf '%s' "$base" | sed "s/^{/{\"run\":\"$RUN\",\"ts\":\"$(now)\",\"app\":\"$APP\",\"kind\":\"baseline\",/")"
  say "baseline: $base"
  # Drive: every declared path, N times, as a browser would.
  n=0; fails=0
  for pass in $(seq 1 "$CYCLES"); do
    IFS=',' read -r -a paths <<<"$(server_paths "$APP")"
    for p in "${paths[@]}"; do
      code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "http://127.0.0.1:$PORT$p" 2>/dev/null || printf 000)"
      [ "$code" = 000 ] && fails=$((fails+1))
      n=$((n+1))
    done
    row "{\"run\":\"$RUN\",\"ts\":\"$(now)\",\"app\":\"$APP\",\"kind\":\"cycle\",\"pass\":$pass,\"requests\":$n,\"failed\":$fails,\"pid\":$PID}"
  done
  aft="$(node "$DRIVER" --measure-pid "$PID" --cpu-state "$LEDGER_DIR/.cpu-state.json" 2>/dev/null)"
  row "$(printf '%s' "$aft" | sed "s/^{/{\"run\":\"$RUN\",\"ts\":\"$(now)\",\"app\":\"$APP\",\"kind\":\"after_cycles\",/")"
  say "after $n requests: $aft"
  end=$(( $(date +%s) + IDLE ))
  while [ "$(date +%s)" -lt "$end" ]; do
    sleep "$SAMPLE" || break
    s="$(node "$DRIVER" --measure-pid "$PID" --cpu-state "$LEDGER_DIR/.cpu-state.json" 2>/dev/null)"
    row "$(printf '%s' "$s" | sed "s/^{/{\"run\":\"$RUN\",\"ts\":\"$(now)\",\"app\":\"$APP\",\"kind\":\"sample\",/")"
  done
  verdict="$(node "$DRIVER" --judge-only --pid "$PID" --ledger "$LEDGER" --app "$APP" --run "$RUN" \
      --b-rss-idle "$B_RSS_IDLE" --b-rss-cycle "$B_RSS_CYCLE" --b-fds "$B_FDS" \
      --b-children "$B_CHILDREN" --b-heap-idle "$B_HEAP_IDLE" --b-heap-cycle "$B_HEAP_CYCLE" 2>&1)"; rc=$?
  say "$verdict"
  [ "$rc" = 0 ] && exit 0 || exit 1
fi

# ── an Electron app ────────────────────────────────────────────────────────────
PORT="$(app_port "$APP")"
ROUTES="$(app_routes "$APP")"
CLASS="ymir-$APP"

listening_pid() {  # the pid that holds the DevTools port (the app's main process)
  ss -tlnp 2>/dev/null | awk -v p=":$PORT" '$4 ~ p' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2
}
port_up() { curl -fsS --max-time 0.6 "http://127.0.0.1:$PORT/json/version" >/dev/null 2>&1; }

RAISED=0; PID=""
if port_up; then
  PID="$(listening_pid)"
  # Someone else's window is already inspectable: measure it where it sits, never
  # restart it and never close it afterwards.
  ATTACH=1
  row "{\"run\":\"$RUN\",\"ts\":\"$(now)\",\"app\":\"$APP\",\"kind\":\"attach\",\"pid\":${PID:-0},\"port\":$PORT,\"how\":\"already answering on its DevTools port\"}"
  say "attached: $APP already answers on :$PORT (pid ${PID:-unknown}) — it will NOT be closed"
else
  if [ "$ATTACH" = 1 ]; then
    printf 'soak[2]{app,status,detail}\n  "%s","SKIP","--attach was asked for and nothing answers on :%s"\n' "$APP" "$PORT"
    exit 3
  fi
  APP_BIN="$ROOT/bin/desktop/ymir-app"
  [ -x "$APP_BIN" ] || { printf 'soak[2]{app,status,detail}\n  "%s","SKIP","the pin has no ymir-app at %s"\n' "$APP" "$APP_BIN"; exit 3; }
  # The operator's own window is open. A second instance would fight its single-instance lock and
  # merely raise HIS window (measured: Electron focuses the running instance and quits), so the
  # only honest move is to say so — unless this runtime's launcher can be given a throwaway
  # profile (YMIR_APP_USER_DATA_DIR, seated in eindri/leak-soak and not yet in every release).
  mark="$(app_class "$APP")"
  running="$(pgrep -f "electron/dist/electron.*--user-data-dir=.*$mark" 2>/dev/null | head -1)"
  if [ -n "$running" ]; then
    if ! grep -qs 'YMIR_APP_USER_DATA_DIR' "$ROOT/scripts/electron.sh" "$ROOT/bin/desktop/sessrumnir-launch.sh" 2>/dev/null; then
      printf 'soak[2]{app,status,detail}\n  "%s","SKIP","%s is already open (pid %s) and this runtime (%s) cannot give a soak its own profile — restarting or driving the operator'"'"'s window is not the soak'"'"'s to do; the launcher override is in eindri/leak-soak and lands with the release"\n' \
        "$APP" "$APP" "$running" "$(basename "$ROOT")"
      row "{\"run\":\"$RUN\",\"ts\":\"$(now)\",\"app\":\"$APP\",\"kind\":\"skip\",\"reason\":\"already open, no throwaway profile in this runtime\",\"pid\":$running,\"port\":$PORT}"
      exit 3
    fi
  fi
  PROFILE="$LEDGER_DIR/profile"
  mkdir -p "$PROFILE"
  say "raising $APP from $ROOT on DevTools :$PORT"
  # A throwaway profile: a second instance must never fight the operator's window for
  # a single-instance lock, and every scratch file it writes dies with the profile.
  nohup env \
    YMIR_RUNTIME_DIR="$ROOT" \
    YMIR_DEVTOOLS_PORT="$PORT" \
    YMIR_APP_USER_DATA_DIR="$PROFILE" \
    YMIR_APP_FOLLOW=0 \
    YMIR_APP_SOAK=1 \
    "$APP_BIN" "$APP" >>"$LEDGER_DIR/raise.log" 2>&1 < /dev/null &
  launch_pid=$!
  i=0
  while [ $i -lt 120 ]; do port_up && break; sleep 0.5; i=$((i+1)); done
  if ! port_up; then
    printf 'soak[2]{app,status,detail}\n  "%s","FAIL","raised but no DevTools on :%s in 60 s — see %s"\n' "$APP" "$PORT" "$LEDGER_DIR/raise.log"
    row "{\"ts\":\"$(now)\",\"app\":\"$APP\",\"kind\":\"raise_failed\",\"port\":$PORT}"
    pkill -f "ymir-app $APP" >/dev/null 2>&1 || true
    exit 3
  fi
  RAISED=1
  PID="$(listening_pid)"
  row "{\"run\":\"$RUN\",\"ts\":\"$(now)\",\"app\":\"$APP\",\"kind\":\"raised\",\"pid\":${PID:-0},\"launch_pid\":$launch_pid,\"port\":$PORT,\"profile\":\"$PROFILE\"}"
fi

close_raised() {
  [ "$RAISED" = 1 ] && [ "$KEEP" = 0 ] || return 0
  say "closing $APP (raised by this soak)"
  # Only the tree this soak raised — by pid, deepest first. A pattern kill would take out
  # another hand's smoke test of the same app, and this house runs several at once.
  killed=0
  if [ -n "${PID:-}" ]; then
    killed="$(node "$DRIVER" --kill-tree "$PID" 2>/dev/null | sed -n 's/.*"killed":\([0-9]*\).*/\1/p')"
  fi
  row "{\"run\":\"$RUN\",\"ts\":\"$(now)\",\"app\":\"$APP\",\"kind\":\"closed\",\"pid\":${PID:-0},\"processes\":${killed:-0},\"how\":\"terminated by the soak\"}"
  # The launcher that exec'd the app exits on its own; the throwaway profile is kept (it is
  # small, and a profile that outlives its run is evidence, not litter).
}
trap 'close_raised; cleanup_lock' EXIT INT TERM

say "soaking $APP: $CYCLES passes over each page, ${IDLE}s idle, sampled every ${SAMPLE}s"
set +e
node "$DRIVER" \
  --app "$APP" --port "$PORT" --pid "${PID:-0}" --ledger "$LEDGER" \
  --routes "$ROUTES" --cycles "$CYCLES" --idle "$IDLE" --sample "$SAMPLE" --settle "$SETTLE" \
  --artifacts-dir "$LEDGER_DIR/artifacts" --snapshot "$SNAPSHOT" --no-artifacts "$((1-ARTIFACTS))" --run "$RUN" \
  --b-rss-idle "$B_RSS_IDLE" --b-rss-cycle "$B_RSS_CYCLE" --b-heap-idle "$B_HEAP_IDLE" \
  --b-heap-cycle "$B_HEAP_CYCLE" --b-fds "$B_FDS" --b-watches "$B_WATCHES" \
  --b-children "$B_CHILDREN" --b-longtask-idle "$B_LONGTASK_IDLE" \
  --b-longtask-cycle "$B_LONGTASK_CYCLE" --b-dialogs "$B_DIALOGS" \
  $( [ "$VERBOSE" = 1 ] && printf '%s' '--verbose' ) \
  $( [ "$JSON" = 1 ] && printf '%s' '--json' )
rc=$?
set -e

# Keep the artifacts shelf small: the last three snapshots per app are enough to read a
# leak, and a heap snapshot is tens of megabytes in the operator's private repo.
if [ "$ARTIFACTS" = 1 ]; then
  ls -1t "$LEDGER_DIR/artifacts"/*.heapsnapshot 2>/dev/null | tail -n +4 | while read -r old; do rm -f "$old"; done
fi
close_raised
trap - EXIT
cleanup_lock
say "ledger: $LEDGER"

case "$rc" in
  0) exit 0 ;;
  1) exit 1 ;;
  *) exit 3 ;;
esac
