#!/usr/bin/env bash
# setup.sh — install Bilskirnir and seat its first agent FROM THE OPERATOR'S HOME.
#
#   apps/bilskirnir/setup.sh           install or refresh (install and Gróa's update both run this)
#   apps/bilskirnir/setup.sh --check   report what is current, change nothing (exit 1 when not)
#
# The app ships ONE name, its assistant's: Nanna, Ymir's own, as Rödd ships her. Every other name —
# the operator, the house, the fleet — lives in the Ymir home (RULES/44):
#   the assistant                Nanna, Ymir's own (shipped); a user's fleet.assistant in seats.yaml renames her
#   hodd/identity/operator.yaml  the Allfather's display name
# From those it renders the agent's soul (house/soul.md.tmpl) into the agent's own Hermes home under
# data/engines/<agent>/, writes the managed block of .env, and renames the first agent in the app's
# database when the roster changed. Nothing here is typed by hand.
#
# Settings (RULES/07), each with one documented default:
#   YMIR_HOME            the home                       (~/Documents/ymirhome)
#   YMIR_HOST            whose roster row to read       (hostname -s)
#   BILSKIRNIR_MODEL     the first agent's model        (qwen3.6-35b-a3b@q4_k_xl-mtp)
#   BILSKIRNIR_BASE_URL  the model's OpenAI endpoint    (http://127.0.0.1:8080/v1, the rail)
#   BILSKIRNIR_HERMES_PORT  the agent's gateway port    (8642)
#   YMIR_RUNTIME_DIR     the pinned runtime the Ymir MCP door runs from (~/ymir-runtime, else this tree)
#   BILSKIRNIR_MCP_GATEWAY  the record doors (well, skuld, bolthorn)  (http://127.0.0.1:8316)
#   BILSKIRNIR_SESSION_HOOK the house's Hermes session hook (~/.hermes/agent-hooks/ymir-session-hook.sh)
#   BILSKIRNIR_DESKTOP   seat the launcher entry and icon (1; 0 = none, as install --no-desktop passes)
#   XDG_DATA_HOME        where the launcher entry goes        (~/.local/share)
set -u
APP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK=0; [ "${1-}" = "--check" ] && CHECK=1
case "${1-}" in -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

YMIR_HOME="${YMIR_HOME:-$HOME/Documents/ymirhome}"
HOST="${YMIR_HOST:-$(hostname -s)}"
MODEL="${BILSKIRNIR_MODEL:-qwen3.6-35b-a3b@q4_k_xl-mtp}"
BASE_URL="${BILSKIRNIR_BASE_URL:-http://127.0.0.1:8080/v1}"
HPORT="${BILSKIRNIR_HERMES_PORT:-8642}"
RUNTIME="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"; [ -f "$RUNTIME/bin/mcp/ymir-mcp.py" ] || RUNTIME="$(dirname "$(dirname "$APP")")"
GATEWAY="${BILSKIRNIR_MCP_GATEWAY:-http://127.0.0.1:8316}"
HOUSE_HOOK="${BILSKIRNIR_SESSION_HOOK:-$HOME/.hermes/agent-hooks/ymir-session-hook.sh}"
say() { printf 'bilskirnir: %s\n' "$*"; }
fail=0

# ── 1. who: read the names from the home ────────────────────────────────────────
read_names() {
  python3 - "$YMIR_HOME" "$HOST" <<'PY'
import sys, os, yaml
home, host = sys.argv[1], sys.argv[2]
def load(p):
    try: return yaml.safe_load(open(os.path.join(home, 'hodd', 'identity', p))) or {}
    except Exception: return {}
seats, op = load('seats.yaml'), load('operator.yaml')
seat = (seats.get('seats') or {}).get(host) or {}
ma = seat.get('machine_agent') or {}
fleet = seats.get('fleet') or {}
# Who answers in the hall: NANNA, Ymir's own assistant — shipped with the app as Rödd ships her, the same
# in every house (2026-11-12, the Allfather: "It could be always Nanna, not in my roster"). A user who
# wants another name sets fleet.assistant in their own roster, and that wins. The roster's own names
# (the seat primary, the machine agent) belong to those seats and are not taken for the hall.
asst = fleet.get('assistant') or {}
if asst.get('name'):
    name, role = asst['name'], asst.get('role') or 'the one who answers'
else:
    name, role = 'Nanna', 'the one who answers'
print('\t'.join([
    name or 'unnamed',
    role,
    fleet.get('house') or 'unnamed',
    fleet.get('name') or 'unnamed',
    (op.get('allfather') or {}).get('display') or fleet.get('operator') or 'the Allfather (unnamed in the home)',
]))
PY
}
IFS=$'\t' read -r NAME ROLE HOUSE FLEET OPERATOR < <(read_names) || { say "cannot read the home at $YMIR_HOME"; exit 1; }
SLUG="$(printf '%s' "$NAME" | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
[ -n "$SLUG" ] || SLUG=first-agent
LABEL="$(printf '%s' "$ROLE" | sed -E 's/^the keeper of the hall.*/Keeper of the hall/; s/^(.)/\U\1/')"
ENGINE="$APP/data/engines/$SLUG"
say "the hall's assistant is $NAME ($LABEL); the house and the Allfather are read from the home"

# ── 2. the soul, rendered from the home ─────────────────────────────────────────
render_soul() {
  python3 - "$APP/house/soul.md.tmpl" "$NAME" "$ROLE" "$HOUSE" "$FLEET" "$OPERATOR" "$YMIR_HOME" <<'PY'
import sys
t = open(sys.argv[1]).read()
for k, v in zip(['name', 'role', 'house', 'fleet', 'operator', 'home'], sys.argv[2:]):
    t = t.replace('{{%s}}' % k, v)
sys.stdout.write(t)
PY
}
want_soul="$(render_soul)"
if [ "$CHECK" = 1 ]; then
  [ "$(cat "$ENGINE/SOUL.md" 2>/dev/null)" = "$want_soul" ] && say "soul current" || { say "soul stale or missing"; fail=1; }
else
  mkdir -p "$ENGINE"
  [ -L "$ENGINE/SOUL.md" ] && rm -f "$ENGINE/SOUL.md"
  printf '%s' "$want_soul" > "$ENGINE/SOUL.md"
  say "soul rendered into data/engines/$SLUG/SOUL.md"
fi

# ── 3. the agent's own Hermes home: model and gateway (never ~/.hermes) ─────────
rail_key() { python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.pi/agent/auth.json')))['llama-swap']['key'])" 2>/dev/null; }
if [ "$CHECK" = 0 ]; then
  umask 077
  KEY="$(rail_key)"
  { printf '# Rendered by apps/bilskirnir/setup.sh — the first agent'"'"'s own Hermes home. Do not edit; re-run setup.\n'
    printf 'model:\n  default: "%s"\n  provider: "custom"\n  base_url: "%s"\n' "$MODEL" "$BASE_URL"
    [ -n "$KEY" ] && printf '  api_key: "%s"\n' "$KEY"
    # Ymir's MCP doors — the same ones every root agent has (RULES/51): the house door (todo, the daily
    # log, the Gná arm, plans, the hall) from the pinned runtime, and the gateway's record doors.
    printf 'mcp_servers:\n'
    printf '  ymir:\n    command: python3\n    args: ["%s/bin/mcp/ymir-mcp.py"]\n    enabled: true\n' "$RUNTIME"
    for d in well skuld bolthorn; do printf '  %s:\n    url: "%s/mcp/%s"\n    enabled: true\n' "$d" "$GATEWAY" "$d"; done
    # The house's hands — Rödd's toolbox (mail read-only, calendar, home search, todo, Trello, seats,
    # the arm, drafts) — through one MCP door, so the agent holds exactly the hands Nanna holds.
    printf '  house:\n    command: python3\n    args: ["%s/house/hands-mcp.py"]\n    enabled: true\n' "$APP"
    # No browser toolset: its helpers are not in this isolated runtime, and a missing tool is a loop
    # (2026-11-12: she retried it seven times). The desktop comes with the agent's own computer.
    printf 'platform_toolsets:\n  api_server: [web, terminal, file, skills, todo, cronjob, vision]\n' 
    # The house's session hook: the Sága brief at session start, delivered into the first turn.
    if [ -x "$HOUSE_HOOK" ]; then
      printf 'hooks:\n  on_session_start:\n  - command: %s\n    timeout: 180\n  pre_llm_call:\n  - command: %s\n    timeout: 60\n' "$HOUSE_HOOK" "$HOUSE_HOOK"
    fi
  } > "$ENGINE/config.yaml"
  # the hook runs only with the operator's consent, given once for the machine's Hermes — carried here
  [ -f "$HOME/.hermes/shell-hooks-allowlist.json" ] && cp "$HOME/.hermes/shell-hooks-allowlist.json" "$ENGINE/shell-hooks-allowlist.json"
  [ -f "$ENGINE/.env" ] || printf 'API_SERVER_ENABLED=true\nAPI_SERVER_KEY=%s\nAPI_SERVER_PORT=%s\nAPI_SERVER_HOST=127.0.0.1\n' \
    "$(head -c 24 /dev/urandom | base64 | tr -d '/+=')" "$HPORT" > "$ENGINE/.env"
  [ -n "$KEY" ] || say "no rail key found in ~/.pi/agent/auth.json — the agent will not reach the model until one is"
  say "agent home: data/engines/$SLUG (model $MODEL)"
else
  grep -q "default: \"$MODEL\"" "$ENGINE/config.yaml" 2>/dev/null && grep -q "ymir-mcp.py" "$ENGINE/config.yaml" && say "agent home current (model and Ymir's MCP doors)" || { say "agent home missing or on another model"; fail=1; }
fi

# ── 4. the app's .env: one managed block, the rest is the operator's ────────────
managed() {
  printf '# >>> managed by setup.sh (from the home) — re-run setup.sh, do not edit\n'
  printf 'PRIMARY_BOT_NAME=%s\nPRIMARY_BOT_LABEL=%s\nHERMES_HOME_PRIMARY=%s\nHERMES_URL=http://127.0.0.1:%s\n' "$NAME" "$LABEL" "$ENGINE" "$HPORT"
  printf '# <<< managed by setup.sh\n'
}
ENVF="$APP/.env"
if [ "$CHECK" = 0 ]; then
  if [ ! -f "$ENVF" ]; then
    umask 077
    { printf 'PORT=8787\nAPP_URL=http://localhost:5173\nSERVER_URL=http://localhost:8787\n'
      printf 'SESSION_SECRET=%s\n' "$(head -c 32 /dev/urandom | base64 | tr -d '/+=')"
      printf '# Local use: no sign-in, loopback only. Hosting elsewhere needs a login (plan 259).\nDEV_LOGIN=0\nHOST=127.0.0.1\nLOCAL_OPERATOR=allfather@localhost\nALLOWED_EMAILS=allfather@localhost\n'
      printf 'HERMES_BIN=hermes\nHQ_LOCAL=0\nMAX_BOTS=4\nORGO_API_KEY=unset\nORGO_COMPUTER_ID=\nCOMPOSIO_API_KEY=unset\nXAI_API_KEY=unset\n'
    } > "$ENVF"
  fi
  # drop the old hand-set lines and the previous managed block, then append the fresh one
  python3 - "$ENVF" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
s = re.sub(r'# >>> managed by setup\.sh.*?# <<< managed by setup\.sh\n?', '', s, flags=re.S)
s = '\n'.join(l for l in s.splitlines() if not re.match(r'(PRIMARY_BOT_NAME|PRIMARY_BOT_LABEL|HERMES_HOME_PRIMARY|HERMES_URL)=', l))
open(p, 'w').write(s.rstrip('\n') + '\n')
PY
  managed >> "$ENVF"
  say ".env managed block written"
else
  grep -q "^PRIMARY_BOT_NAME=$NAME\$" "$ENVF" 2>/dev/null && say ".env current" || { say ".env stale or missing"; fail=1; }
fi

# ── 5. the code's dependencies, from the lock files ─────────────────────────────
# Reinstall only when the lock file changed: `npm ci` empties node_modules first, which pulls the floor
# out from under a running app (2026-11-12: the hall answered "Bad Gateway" mid-conversation).
LOCK_SUM="$(sha256sum "$APP/package-lock.json" | cut -c1-16)"; STAMP="$APP/node_modules/.bilskirnir-lock"
if [ "$CHECK" = 0 ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$LOCK_SUM" ] && [ -d "$APP/node_modules/@novnc" ]; then
  say "dependencies current (lock unchanged)"
elif [ "$CHECK" = 0 ]; then
  ( cd "$APP" && npm ci --ignore-scripts --no-audit --no-fund >/dev/null 2>&1 \
      && (cd node_modules/better-sqlite3 && npx --yes node-gyp rebuild >/dev/null 2>&1) \
      && (cd node_modules/esbuild && node install.js >/dev/null 2>&1) ) \
    && printf '%s' "$LOCK_SUM" > "$STAMP" && say "dependencies installed" || { say "npm install failed — run: cd apps/bilskirnir && npm ci"; fail=1; }
else
  [ -d "$APP/node_modules/@novnc" ] && [ -d "$APP/node_modules/hono" ] && say "dependencies present" || { say "dependencies missing"; fail=1; }
fi

# ── 6. the database follows the roster ──────────────────────────────────────────
DB="$APP/data/grokbot.db"
if [ "$CHECK" = 0 ] && [ -f "$DB" ]; then
  python3 - "$DB" "$NAME" "$LABEL" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.execute("UPDATE bots SET name=?, label=? WHERE is_primary=1 AND (name<>? OR label<>?)", (sys.argv[2], sys.argv[3], sys.argv[2], sys.argv[3]))
# the first seed said "the keeper of this machine's hall" — the Allfather: "we should not say for this machine"
c.execute("UPDATE bots SET description=? WHERE is_primary=1 AND description=?", ("The one who answers in the hall. Your first word goes to her; she watches the house and calls on the other agents.", "The keeper of this machine's hall. Your first word goes to her; she watches the house and calls on the other agents."))
c.commit()
PY
  say "the first agent in the app is $NAME"
fi

# ── 7. the launcher entry: the hall opens like the other apps, from the menu ────
# Only where a desktop exists (Rule 25: probe, never assume); a server host gets a clean skip.
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DESK="$DATA_HOME/applications/ymir-bilskirnir.desktop"
ICON_DST="$DATA_HOME/icons/hicolor/512x512/apps/ymir-bilskirnir.png"
want_desk="$(sed "s#__APP__#$APP#g" "$APP/electron/bilskirnir.desktop.in" 2>/dev/null)"
if [ "${BILSKIRNIR_DESKTOP:-1}" = 0 ]; then
  say "launcher entry skipped (BILSKIRNIR_DESKTOP=0)"
elif [ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && [ ! -d "$DATA_HOME/applications" ]; then
  say "no desktop on this host — no launcher entry"
elif [ "$CHECK" = 1 ]; then
  [ "$(cat "$DESK" 2>/dev/null)" = "$want_desk" ] && say "launcher entry current" || say "launcher entry missing or stale (not required)"
else
  mkdir -p "$(dirname "$DESK")" "$(dirname "$ICON_DST")"
  printf '%s\n' "$want_desk" > "$DESK"
  cp "$APP/electron/icon.png" "$ICON_DST"
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$(dirname "$DESK")" >/dev/null 2>&1
  say "launcher entry seated (Ymir · Bilskirnir)"
fi

[ "$fail" = 0 ] && { say "ready"; exit 0; } || { say "not ready"; exit 1; }
