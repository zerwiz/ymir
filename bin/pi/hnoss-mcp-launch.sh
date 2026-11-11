#!/usr/bin/env bash
# hnoss-mcp-launch.sh — the door that seats the Hnoss (OpenDesign) MCP bridge on the
# model provider **pi itself uses**.
#
# WHY THIS EXISTS (measured 2026-11-10). `open-design-mcp` reaches a model through BYOK:
# it composes the design prompt and POSTs it to the daemon's `/api/proxy/<provider>/stream`,
# which forwards it to `BYOK_BASE_URL`. The hand-written launcher that stood before this
# one read `defaultProvider` from pi's settings and looked the provider up in
# `models.json`; when the Allfather's provider was a pi **built-in** (`opencode-go` is one,
# and is therefore absent from models.json) it fell back to the local rail
# `http://127.0.0.1:8080/v1` and paired it with `deepseek-v4.1-flash` — a door and a model
# that cannot answer each other. Every design generation was therefore dead, silently.
#
# The road now, in one line: **pi resolves the provider, model and key; Bifrost is the
# door** (`bin/bridge/bifrost-bridge.sh`) — the shipped loopback bridge that already
# carries the `x-opencode-session` header the Zen gateway demands
# (`400 MissingSessionID` without it) and that the BYOK client cannot add for itself.
#
#   * a provider in `models.json` (the rails) is reachable directly — its own baseUrl;
#   * a provider built INTO pi (opencode-go, and any future one) is reached through
#     Bifrost, which owns that gateway's URL and headers;
#   * a provider neither in the registry nor served by Bifrost is a **loud refusal**,
#     never a silent fallback to a model the caller never asked for.
#
# Usage:
#   hnoss-mcp-launch.sh            # exec the MCP bridge with the resolved door
#   hnoss-mcp-launch.sh --print    # raise the door, print it (never the key) and exit
#   hnoss-mcp-launch.sh --resolve  # resolve only: no bridge raised, no network, no key
#                                  # needed — what a STATUS check may run
#
# Env (all optional, one documented default each):
#   PI_AGENT_DIR / PI_DIR          pi's home                (default ~/.pi/agent)
#   YMIR_HNOSS_PROVIDER            override the provider    (default pi's defaultProvider)
#   YMIR_HNOSS_MODEL               override the model       (default pi's defaultModel)
#   YMIR_HNOSS_BRIDGE_PORT         Hnoss's own bridge port  (default 4613)
#   YMIR_HNOSS_BYOK_PROVIDER       the daemon's proxy route (default openai)
#   OD_DAEMON_URL                  the OpenDesign daemon    (default http://127.0.0.1:7456)
#   OD_ENV_FILE                    where OD_API_TOKEN lives (default ~/opendesign/deploy/.env)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# The operator's settings live in the home they chose, never in the tree (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../bin/vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
hoard_state_dir YMIR_STATE_DIR 2>/dev/null || YMIR_STATE_DIR="${YMIR_STATE_DIR:-$ROOT/state}"

PI_DIR="${PI_AGENT_DIR:-${PI_DIR:-$HOME/.pi/agent}}"
BRIDGE="$ROOT/bin/bridge/bifrost-bridge.sh"
BRIDGE_PORT="${YMIR_HNOSS_BRIDGE_PORT:-4613}"
OD_DAEMON_URL="${OD_DAEMON_URL:-http://127.0.0.1:7456}"
OD_ENV_FILE="${OD_ENV_FILE:-$HOME/opendesign/deploy/.env}"
BYOK_PROVIDER="${YMIR_HNOSS_BYOK_PROVIDER:-openai}"
PRINT_ONLY=0
RESOLVE_ONLY=0
for a in "$@"; do
  [ "$a" = "--print" ] && PRINT_ONLY=1
  [ "$a" = "--resolve" ] && { RESOLVE_ONLY=1; PRINT_ONLY=1; }
done

say() { printf '[hnoss] %s\n' "$*" >&2; }
die() { printf '[hnoss] REFUSED: %s\n' "$*" >&2; exit 1; }

# ── what pi says it will serve ────────────────────────────────────────────────
# Read, never assumed: the provider, the model, and whether the provider is one the
# registry names (a rail) or one built into pi.
read -r PROVIDER MODEL DOOR_KIND DOOR_BASE < <(python3 - "$PI_DIR" \
    "${YMIR_HNOSS_PROVIDER:-}" "${YMIR_HNOSS_MODEL:-}" <<'PY'
import json, os, sys
pdir, prov, model = sys.argv[1], sys.argv[2], sys.argv[3]
def load(name):
    try:
        with open(os.path.join(pdir, name)) as f:
            return json.load(f)
    except Exception:
        return {}
settings = load("settings.json")
prov = prov or (settings.get("defaultProvider") or "")
model = model or (settings.get("defaultModel") or "")
registry = load("models.json").get("providers") or {}
entry = registry.get(prov) or {}
base = entry.get("baseUrl") or entry.get("url") or ""
kind = "direct" if base else ("bridge" if prov else "none")
# A bare model id: the gateways reject the `provider/` prefix, and BYOK_MODEL is an id.
if "/" in model and model.split("/", 1)[0] == prov:
    model = model.split("/", 1)[1]
print(prov or "-", model or "-", kind, base or "-")
PY
)
[ "$PROVIDER" = "-" ] && die "pi names no default provider (PI_AGENT_DIR=$PI_DIR) — nothing to seat Hnoss on"
[ "$MODEL" = "-" ] && die "pi names no default model — Hnoss would generate with no brain"
[ "$DOOR_KIND" = "none" ] && die "pi's provider '$PROVIDER' is not in the registry and cannot be resolved"

# ── the key: pi's own credential door, never a copy in a file ─────────────────
resolve_key() {
  local key=""
  # `pi auth` always answers from pi's OWN home; when a caller points this door at a
  # different pi home, that home's files are the truth and a bare `pi` would answer
  # from someone else's login.
  if [ "$PI_DIR" = "$HOME/.pi/agent" ] && command -v pi >/dev/null 2>&1; then
    key="$(pi auth print-api-key --provider "$PROVIDER" 2>/dev/null | head -1 || true)"
  fi
  if [ -z "$key" ] && [ -r "$PI_DIR/auth.json" ]; then
    key="$(python3 - "$PI_DIR/auth.json" "$PROVIDER" <<'PY' 2>/dev/null || true
import json, sys
try:
    d = json.load(open(sys.argv[1])).get(sys.argv[2]) or {}
except Exception:
    d = {}
print(d.get("key") or d.get("apiKey") or "")
PY
)"
  fi
  if [ -z "$key" ] && [ -r "$PI_DIR/models.json" ]; then
    key="$(python3 - "$PI_DIR/models.json" "$PROVIDER" <<'PY' 2>/dev/null || true
import json, sys
try:
    p = (json.load(open(sys.argv[1])).get("providers") or {}).get(sys.argv[2]) or {}
except Exception:
    p = {}
print(p.get("apiKey") or "")
PY
)"
  fi
  printf '%s' "$key"
}

# ── where the DAEMON must look for the door ───────────────────────────────────
# The MCP bridge runs on the host; the daemon may run natively, in a host-network
# container (loopback is then the host's own), or in a bridge-network container
# (loopback is its own namespace, and it reaches the host as host.docker.internal).
daemon_container() {
  command -v docker >/dev/null 2>&1 || return 0
  local n
  n="$(docker ps --filter 'name=open-design' --format '{{.Names}}' 2>/dev/null | head -1)"
  [ -n "$n" ] && printf '%s' "$n"
}
daemon_door() {  # prints "<host> <bind>"
  local c mode gw
  c="$(daemon_container)"
  if [ -z "$c" ]; then printf '127.0.0.1 127.0.0.1'; return 0; fi
  mode="$(docker inspect "$c" --format '{{.HostConfig.NetworkMode}}' 2>/dev/null || true)"
  case "$mode" in
    host|"") printf '127.0.0.1 127.0.0.1'; return 0 ;;
  esac
  gw="$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || true)"
  printf 'host.docker.internal %s' "${gw:-127.0.0.1}"
}

read -r DOOR_HOST BRIDGE_BIND <<EOF
$(daemon_door)
EOF

KEY="$(resolve_key)"

case "$DOOR_KIND" in
  direct)
    BYOK_BASE_URL="$DOOR_BASE"
    say "door: ${DOOR_BASE} (registry) · provider ${PROVIDER} · model ${MODEL}"
    ;;
  bridge)
    [ -x "$BRIDGE" ] || die "no bridge to carry '$PROVIDER' — expected $BRIDGE"
    # Name the credential the bridge resolves for this provider, then raise it on the
    # interface the daemon can see. A bridge up on another provider is restarted.
    [ -n "$KEY" ] && export YMIR_MODEL_API_KEY="$KEY"
    case "$PROVIDER" in
      opencode-go) [ -n "$KEY" ] && export OPENCODE_GO_API_KEY="$KEY" ;;
    esac
    [ "$BRIDGE_BIND" != "127.0.0.1" ] && export YMIR_MODEL_BIND="$BRIDGE_BIND"
    if [ "$RESOLVE_ONLY" = 1 ]; then
      # A status check must not raise a service, and a test must not need the network.
      if ! bash "$BRIDGE" --providers 2>/dev/null | grep -qx "$PROVIDER"; then
        die "no door here for '$PROVIDER' — the bridge carries $(bash "$BRIDGE" --providers 2>/dev/null | tr '\n' ' ')"
      fi
      BYOK_BASE_URL="http://${DOOR_HOST}:${BRIDGE_PORT}/v1"
      say "door: ${BYOK_BASE_URL} (bifrost, resolved only) · provider ${PROVIDER} · model ${MODEL}"
      RESOLVED=1
    fi
    if [ "${RESOLVED:-0}" = 1 ]; then :; elif ! out="$("$BRIDGE" --ensure --port "$BRIDGE_PORT" --provider "$PROVIDER" 2>&1)"; then
      die "the Bifrost bridge refused '$PROVIDER' — $out
help: the bridge serves $(bash "$BRIDGE" --providers 2>/dev/null | tr '\n' ' ' || printf 'a fixed list')
      a pi provider outside that list has no door here; do not fall back to the rail"
    fi
    if [ "${RESOLVED:-0}" != 1 ]; then
      [ "$PRINT_ONLY" = 1 ] && printf '%s\n' "$out" >&2
      BYOK_BASE_URL="http://${DOOR_HOST}:${BRIDGE_PORT}/v1"
      say "door: ${BYOK_BASE_URL} (bifrost) · provider ${PROVIDER} · model ${MODEL}"
    fi
    ;;
  *) die "unknown door for '$PROVIDER'" ;;
esac

[ -n "$KEY" ] || [ "$RESOLVE_ONLY" = 1 ] || die "no credential for '$PROVIDER' — pi has none (pi auth login $PROVIDER)"

# The daemon must be able to reach that door. When it shares our network the check is
# local; when it is a bridge-network container, the check is made FROM INSIDE it — a
# door that only the host can see is the same silent pairing this launcher replaced.
if [ "$DOOR_HOST" != "127.0.0.1" ] && [ "$RESOLVE_ONLY" = 0 ]; then
  c="$(daemon_container)"
  if ! docker exec "$c" node -e "fetch('${BYOK_BASE_URL}/models').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" 2>/dev/null; then
    die "the daemon container '$c' cannot reach ${BYOK_BASE_URL} — bind the bridge where it can
      (YMIR_MODEL_BIND, default was ${BRIDGE_BIND}) and re-open the door"
  fi
fi

# ── the token the daemon still carries, by reference ──────────────────────────
if [ -r "$OD_ENV_FILE" ]; then
  TOKEN="$(sed -nE 's/^[[:space:]]*OD_API_TOKEN[[:space:]]*=[[:space:]]*(.*)$/\1/p' "$OD_ENV_FILE" | tail -1 | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')"
  [ -n "${TOKEN:-}" ] && export OD_API_TOKEN="$TOKEN"
fi

export OD_DAEMON_URL
export BYOK_BASE_URL BYOK_API_KEY="$KEY" BYOK_MODEL="$MODEL" BYOK_PROVIDER

if [ "$PRINT_ONLY" = 1 ]; then
  printf 'hnoss_door[6]{provider,model,door,byok_provider,daemon,key}:\n'
  printf '  "%s","%s","%s","%s","%s","%s"\n' \
    "$PROVIDER" "$MODEL" "$BYOK_BASE_URL" "$BYOK_PROVIDER" "$OD_DAEMON_URL" \
    "$([ -n "$KEY" ] && printf resolved || printf absent)"
  exit 0
fi

command -v open-design-mcp >/dev/null 2>&1 || die "open-design-mcp is not on PATH — npm i -g open-design-mcp"
exec open-design-mcp "$@"
