#!/usr/bin/env bash
# bifrost-bridge.sh — raise/lower the model bridge (Bifrost: the bridge between
# realms). Pi's model provider points at a local OpenAI-compatible endpoint;
# this keeps that endpoint alive so a session never 401s.
#
# The provider is the operator's choice (YMIR_MODEL_PROVIDER):
#   opencode-go        OpenCode Zen Go gateway — needs a key (vault, env file, or pi's auth.json)
#   local-rail         the local llama.cpp rail on :8080 — the keyless second road
#   lmstudio           LM Studio on localhost — served ONLY when it is named
#   openai-compatible  any OpenAI-compatible server — optional key
#
# THE FALLBACK IS NEVER LM STUDIO (plan 275 item 22, measured 2026-11-14): with no
# OPENCODE_GO_API_KEY in the env file this door used to choose `lmstudio` — a provider the
# Allfather retired on 2026-10-24 ("no lm studio we not using that") — so bifrost answered
# every chat with `curl: (7) Failed to connect to 127.0.0.1:1234` behind a bare 500. The
# order is now: a NAMED provider wins; else opencode-go when a key is readable through the
# vault or pi's auth.json; else the local rail; else a loud refusal that names both roads.
# The decision itself lives in model-bridge.py (`--resolve-provider`), so this shell holds
# no second opinion about it.
#
# Usage: bin/bridge/bifrost-bridge.sh [--start|--stop|--status|--ensure|--providers|--resolve] [--port N] [--provider NAME]
#        bin/bridge/bifrost-bridge.sh --foreground  # stay in the foreground (a systemd unit
#                                            # supervises this process directly — no self-daemon)
#        bin/bridge/bifrost-bridge.sh --version
#
# `--ensure` is the idempotent raise a caller that NEEDS this provider uses: up with
# that provider → nothing to do; down → start; up with ANOTHER provider → restart it.
# A bridge that is up on the wrong provider is not up (measured 2026-11-10: the shared
# instance sat on `lmstudio` while every caller asked for opencode-go).
#
# One bridge per PORT is legal — the design door (Hnoss) keeps its own instance beside
# the shared one — so the pid and log files are port-scoped and `--stop` kills only the
# instance on the port it was given.
set -u

# --- portability shim: bin/fleet/ymir-platform.sh --------------------------------
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  for _ymir_c in "$(git rev-parse --show-toplevel 2>/dev/null)/bin/fleet/ymir-platform.sh"                  "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/fleet/ymir-platform.sh"; do
    [ -n "$_ymir_c" ] && [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_c
fi

VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# The operator's settings and secrets live in the home they chose, never in the
# code tree — a packaged install replaces its tree on upgrade, and a credential
# must never sit in a tree that ships (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$_yr/../vault/hoard-lib.sh" "$_yr/../../vault/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_local_env YMIR_ENV_FILE
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
BRIDGE="$ROOT/.agents/backend/model-bridge.py"
ENV_FILE="${BROKK_ENV_FILE:-$YMIR_ENV_FILE}"
PORT="${OPENCODE_GO_BRIDGE_PORT:-4603}"
PROVIDER="${YMIR_MODEL_PROVIDER:-}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="start"
FOREGROUND=0
while [ $# -gt 0 ]; do
  case "$1" in
    --start|"") ACTION=start; shift ;;
    --ensure) ACTION=ensure; shift ;;
    --providers) ACTION=providers; shift ;;
    --resolve) ACTION=resolve; shift ;;
    --stop|stop) ACTION=stop; shift ;;
    --status|status) ACTION=status; shift ;;
    --foreground) FOREGROUND=1; shift ;;
    --port) PORT=${2-}; shift 2 ;;
    --provider) PROVIDER=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/bridge/bifrost-bridge.sh [--start|--stop|--status|--ensure|--providers|--resolve|--port|--provider|--foreground]\n' "$1" >&2; exit 2 ;;
  esac
done

# Port-scoped state, computed AFTER the flags so `--port N` names the right files:
# two instances on two ports must not share one pid file, or `--stop`/`--ensure`
# acts on the wrong bridge. The default port keeps its historical names.
if [ "$PORT" = "4603" ]; then
  PID_FILE="$YMIR_STATE_DIR/model-bridge.pid"
  LOG_FILE="$YMIR_STATE_DIR/model-bridge.log"
else
  PID_FILE="$YMIR_STATE_DIR/model-bridge-$PORT.pid"
  LOG_FILE="$YMIR_STATE_DIR/model-bridge-$PORT.log"
fi

# The door may be bound to a wider interface than loopback (a containerised client on
# another network), so "listening" asks both the loopback and the named bind address.
listening() {
  local h
  for h in 127.0.0.1 "${YMIR_MODEL_BIND:-127.0.0.1}"; do
    (exec 3<>"/dev/tcp/$h/$PORT") 2>/dev/null && return 0
  done
  return 1
}

# The instances that hold THIS port. `[m]` keeps pgrep from matching its own caller.
pids_on_port() {
  local p
  for p in $(pgrep -f '[m]odel-bridge\.py' 2>/dev/null); do
    case "$(ps -o args= -p "$p" 2>/dev/null)" in
      *"--port $PORT "*) printf '%s\n' "$p" ;;
    esac
  done
}

# The provider the instance on THIS port is actually serving — read from the live
# process, never from the flag the caller happened to pass (that is how a green
# status hid a bridge serving the wrong provider).
running_provider() {
  local p line prov
  for p in $(pids_on_port); do
    line="$(ps -o args= -p "$p" 2>/dev/null)"
    prov="$(printf '%s' "$line" | sed -n 's/.*--provider[ =]\+\([A-Za-z0-9_.-]*\).*/\1/p')"
    [ -n "$prov" ] && { printf '%s' "$prov"; return 0; }
  done
  return 0
}

stop_port() {
  local pid stopped=0
  if [ -r "$PID_FILE" ]; then
    pid=$(tr -d '[:space:]' <"$PID_FILE")
    kill "$pid" 2>/dev/null && stopped=1
    rm -f "$PID_FILE"
  fi
  for pid in $(pids_on_port); do kill "$pid" 2>/dev/null && stopped=1; done
  # A restart must not race the dying process: wait for the port to actually close,
  # or the "new" instance is really the old one and the provider check is a lie.
  local i=0
  while listening && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done
  printf '%s' "$stopped"
}

# Read a key from the env file without sourcing it.
env_value() {
  local name="$1"
  [ -r "$ENV_FILE" ] || return 1
  sed -nE "s/^[[:space:]]*${name}[[:space:]]*=[[:space:]]*(.*)$/\1/p" "$ENV_FILE" \
    | tail -1 | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/'
}

# WHICH provider, and WHY — asked of the bridge, never decided here (plan 275 item 22).
# RESOLVED_PROVIDER is empty when there is no road at all, and RESOLVED_WHY always says
# what was looked for, so a refusal can name it instead of guessing.
RESOLVED_PROVIDER=""
RESOLVED_WHY=""
RESOLVED_BASE=""
RESOLVED_KEY=""
resolve_expected() {
  [ -e "$BRIDGE" ] || return 1
  local out row
  out="$(python3 "$BRIDGE" --resolve-provider --env "$ENV_FILE" ${PROVIDER:+--provider "$PROVIDER"} 2>/dev/null)" || true
  row="$(printf '%s\n' "$out" | sed -n 's/^  "//p' | head -1)"
  [ -n "$row" ] || return 1
  RESOLVED_PROVIDER="$(printf '%s' "$row" | cut -d'"' -f1)"
  RESOLVED_WHY="$(printf '%s' "$row" | cut -d'"' -f3)"
  RESOLVED_BASE="$(printf '%s' "$row" | cut -d'"' -f5)"
  RESOLVED_KEY="$(printf '%s' "$row" | cut -d'"' -f7)"
  [ "$RESOLVED_PROVIDER" = NONE ] && RESOLVED_PROVIDER=""
  return 0
}

# start/ensure/serve: resolve the provider BEFORE any action, so a named provider, a
# keyless rail and a retirement all take the same road.
if [ "$ACTION" = start ] || [ "$ACTION" = ensure ] || [ "$ACTION" = resolve ]; then
  [ -e "$BRIDGE" ] || { printf 'error: bridge script not found: %s\nhelp: expected .agents/backend/model-bridge.py\n' "$BRIDGE" >&2; exit 1; }
  resolve_expected || true
  if [ -z "$PROVIDER" ] && [ -n "$RESOLVED_PROVIDER" ]; then PROVIDER="$RESOLVED_PROVIDER"; fi
  if [ -z "$PROVIDER" ]; then
    printf 'error: no provider to serve — no key for opencode-go, and the local rail does not answer\n' >&2
    printf 'why:   %s\n' "${RESOLVED_WHY:-the bridge could not be asked}" >&2
    printf 'help:  raise the rail on :8080, put OPENCODE_GO_API_KEY in the vault (bin/vault/hodd.sh emit secrets/platform.env),\n' >&2
    printf '       or name one: --provider opencode-go|local-rail|lmstudio|openai-compatible\n' >&2
    printf 'note:  lmstudio is served only when it is NAMED; it is not a fallback (plan 275 item 22)\n' >&2
    exit 1
  fi
fi

case "$ACTION" in
  providers)
    # What this bridge can carry — the list a caller with no door for its provider
    # reads to refuse in words instead of guessing a URL.
    python3 "$BRIDGE" --providers
    exit 0 ;;
  resolve)
    # What this door would serve, and why — the same answer start/ensure act on.
    printf 'bridge[4]{port,provider,why,base_url}:\n  %s,"%s","%s","%s"\n' \
      "$PORT" "$PROVIDER" "$RESOLVED_WHY" "$RESOLVED_BASE"
    exit 0 ;;
  status)
    resolve_expected || true
    if listening; then
      printf 'bridge[2]{port,status,provider}:\n  %s,"up","%s"\n' "$PORT" "$(running_provider)"
    else
      printf 'bridge[4]{port,status,provider,why}:'
      printf '\n  %s,"down","%s","%s"\n' "$PORT" "${PROVIDER:-$RESOLVED_PROVIDER}" "$RESOLVED_WHY"
    fi
    exit 0 ;;
  stop)
    was="down"; listening && was="up"
    stop_port >/dev/null
    if [ "$was" = up ]; then printf 'bridge: stopped\n'; else printf 'bridge: already stopped\n'; fi
    exit 0 ;;
  ensure)
    if listening; then
      have="$(running_provider)"
      if [ -z "$PROVIDER" ] || [ "$have" = "$PROVIDER" ]; then
        printf 'bridge[1]{port,status,provider}:\n  %s,"already up","%s"\n' "$PORT" "${have:-unknown}"
        exit 0
      fi
      # Up on the WRONG provider is not up: the caller asked for one that answers.
      stop_port >/dev/null
      printf 'bridge[3]{port,was,now}:\n  %s,"%s","%s"\n' "$PORT" "${have:-unknown}" "$PROVIDER"
    fi
    ACTION=start ;;
esac

if listening; then
  have="$(running_provider)"
  if [ -n "$PROVIDER" ] && [ "$have" != "$PROVIDER" ]; then
    printf 'error: the bridge on :%s is serving "%s", not "%s"\nhelp: bin/bridge/bifrost-bridge.sh --stop --port %s, then --ensure --provider %s\n' \
      "$PORT" "${have:-unknown}" "$PROVIDER" "$PORT" "$PROVIDER" >&2
    exit 1
  fi
  pids_on_port >"$PID_FILE" 2>/dev/null || true
  printf 'bridge[2]{port,status,provider}:\n  %s,"already up","%s"\n' "$PORT" "${have:-unknown}"
  exit 0
fi
[ -e "$BRIDGE" ] || { printf 'error: bridge script not found: %s\nhelp: expected .agents/backend/model-bridge.py\n' "$BRIDGE"; exit 1; }

# A missing env file is fine for keyless providers; the bridge reads what it can.
mkdir -p "$YMIR_STATE_DIR"
if [ "$FOREGROUND" = 1 ]; then
  # A systemd unit owns this process: no self-daemon, no pid file, no port
  # poll — the bridge is the unit, and the unit's truth is the process's.
  exec python3 "$BRIDGE" --port "$PORT" --env "$ENV_FILE" --provider "$PROVIDER"
fi
nohup python3 "$BRIDGE" --port "$PORT" --env "$ENV_FILE" --provider "$PROVIDER" >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
sleep 2
if listening; then
  have="$(running_provider)"
  if [ "$have" != "$PROVIDER" ]; then
    printf 'error: :%s answers but serves "%s", not "%s"; see %s\n' \
      "$PORT" "${have:-unknown}" "$PROVIDER" "${LOG_FILE#"$ROOT"/}" >&2
    exit 1
  fi
  printf 'bridge[1]{port,status,provider}:\n  %s,"started","%s"\n' "$PORT" "$PROVIDER"
else
  printf 'error: bridge failed to start (provider=%s); see %s\n' "$PROVIDER" "${LOG_FILE#"$ROOT"/}" >&2
  case "$PROVIDER" in
    opencode-go) printf 'help: put OPENCODE_GO_API_KEY in the vault (bin/vault/hodd.sh emit secrets/platform.env) or in pi auth.json, or run with --provider local-rail\n' >&2 ;;
    local-rail)  printf 'help: is the rail serving on :8080? Or set YMIR_RAIL_BASE_URL / YMIR_MODEL_PROVIDER\n' >&2 ;;
    lmstudio)    printf 'help: lmstudio is NAMED, never chosen — is LM Studio serving on 127.0.0.1:1234?\n' >&2 ;;
    *)           printf 'help: check YMIR_MODEL_BASE_URL and the provider in %s\n' "${ENV_FILE#"$ROOT"/}" >&2 ;;
  esac
  exit 1
fi
