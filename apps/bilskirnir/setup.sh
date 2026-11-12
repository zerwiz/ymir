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
#   BILSKIRNIR_MODEL     the first agent's model        (unset: what Settings > Models chose, else what the agent
#                                                        already has, else the first allowed model the detector finds)
#   BILSKIRNIR_BASE_URL  that model's OpenAI endpoint   (unset: the endpoint of the provider that lists it)
#   BILSKIRNIR_LOCAL_PORTS  local servers to look for   (ollama:11434,lmstudio:1234,llamacpp:8080,vllm:8000)
#   BILSKIRNIR_HERMES_PORT  the agent's gateway port    (8642)
#   YMIR_RUNTIME_DIR     the pinned runtime the Ymir MCP door runs from (~/ymir-runtime, else this tree)
#   BILSKIRNIR_MCP_GATEWAY  the record doors (well, skuld, bolthorn)  (http://127.0.0.1:8316)
#   BILSKIRNIR_SESSION_HOOK the house's Hermes session hook (~/.hermes/agent-hooks/ymir-session-hook.sh)
#   BILSKIRNIR_DESKTOP   seat the launcher entry and icon (1; 0 = none, as install --no-desktop passes)
#   XDG_DATA_HOME        where the launcher entry goes        (~/.local/share)
#   BILSKIRNIR_DESK      the agents' computer: local = the hall's own desk (house/desk.sh), orgo = Orgo  (local)
#   BILSKIRNIR_DESK_HOST where the desk's loopback ports are (the agent's Chrome DevTools)   (127.0.0.1)
#   BILSKIRNIR_VOICE     the voice road: house | xai     (house — see server/src/voice-house.ts for its parts)
set -u
APP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# the hall's state lives in one home per user, never in this checkout (plan 275 S5)
[ "${1:-}" = "--check" ] || bash "$APP/scripts/data-home.sh" || { echo "bilskirnir: the data home could not be linked — see scripts/data-home.sh" >&2; exit 1; }
CHECK=0; [ "${1-}" = "--check" ] && CHECK=1
case "${1-}" in -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

YMIR_HOME="${YMIR_HOME:-$HOME/Documents/ymirhome}"
HOST="${YMIR_HOST:-$(hostname -s)}"
HPORT="${BILSKIRNIR_HERMES_PORT:-8642}"
RUNTIME="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"; [ -f "$RUNTIME/bin/mcp/ymir-mcp.py" ] || RUNTIME="$(dirname "$(dirname "$APP")")"
GATEWAY="${BILSKIRNIR_MCP_GATEWAY:-http://127.0.0.1:8316}"
HOUSE_HOOK="${BILSKIRNIR_SESSION_HOOK:-$HOME/.hermes/agent-hooks/ymir-session-hook.sh}"
DESK="${BILSKIRNIR_DESK:-local}"
DESK_HOST="${BILSKIRNIR_DESK_HOST:-127.0.0.1}"
say() { printf 'bilskirnir: %s\n' "$*"; }
fail=0

# ── 1. who: read the names from the home ────────────────────────────────────────
# One renderer for every agent's house parts — house/house.py, shared with server/src/engine.ts (every bot
# made in the app is dressed by the same file). It reads the names from the home (RULES/44).
read_names() { python3 "$APP/house/house.py" names; }
IFS=$'\t' read -r NAME ROLE HOUSE FLEET OPERATOR < <(read_names) || { say "cannot read the home at $YMIR_HOME"; exit 1; }
SLUG="$(printf '%s' "$NAME" | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
[ -n "$SLUG" ] || SLUG=first-agent
LABEL="$(printf '%s' "$ROLE" | sed -E 's/^the keeper of the hall.*/Keeper of the hall/; s/^(.)/\U\1/')"
ENGINE="$APP/data/engines/$SLUG"
say "the hall's assistant is $NAME ($LABEL); the house and the Allfather are read from the home"

# ── 2. the soul, rendered from the home ─────────────────────────────────────────
# Her soul keeps the user's own words (plan 275): the house's part sits in a managed block refreshed in place, the
# same road every other agent takes. A soul that is still the untouched full render carries nothing of the user's.
render_soul() {
  local ex="$ENGINE/SOUL.md" full
  full="$(python3 "$APP/house/house.py" soul --full --name "$NAME" --role "$ROLE")"
  if [ -f "$ex" ] && [ "$(cat "$ex")" != "$full" ]; then
    python3 "$APP/house/house.py" soul --name "$NAME" --role "$ROLE" --existing "$ex"
  else
    python3 "$APP/house/house.py" soul --name "$NAME" --role "$ROLE"
  fi
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

# ── 3. the desk: the agents' own computer (a container on this machine) ─────────
# One Linux desktop, one screen per agent, loopback only (house/desk.sh). The first agent's screen is
# display :99, so her Chrome's DevTools answer on port 9299 (9200 + display, server/box/hqlib.py).
DESK_UP=0
if [ "$DESK" = local ]; then
  if ! command -v "${DOCKER:-docker}" >/dev/null 2>&1; then
    say "desk skipped: no container engine (${DOCKER:-docker}) on this machine — the agents have no computer here"
  elif [ "$CHECK" = 1 ]; then
    line="$(bash "$APP/house/desk.sh" status)" && { DESK_UP=1; say "desk up ($line)"; } || { say "desk not up ($line) — run: apps/bilskirnir/house/desk.sh up"; fail=1; }
  else
    line="$(bash "$APP/house/desk.sh" up 2>&1 | tail -1)" && { DESK_UP=1; say "desk up ($line)"; } || { say "desk did not come up: $line"; fail=1; }
  fi
else
  say "desk: Orgo (BILSKIRNIR_DESK=$DESK) — ORGO_API_KEY and ORGO_COMPUTER_ID in .env"
fi

# ── 4. the agent's own Hermes home: model and gateway (never ~/.hermes) ─────────
# The model comes from the detector (server/src/models/detect.ts): what the user already has — keys in the
# environment, pi's and OpenCode's configs, Hermes' own, local servers — judged by the operator's allow-list when
# one exists (bin/model/model-allow.sh). BILSKIRNIR_MODEL / BILSKIRNIR_BASE_URL still win. Nothing here needs pi.
model_block() {
  command -v node >/dev/null 2>&1 || return 9
  local args=(--model-block --agent primary --config "$ENGINE/config.yaml")
  [ -n "${BILSKIRNIR_MODEL:-}" ] && args+=(--model "$BILSKIRNIR_MODEL")
  [ -n "${BILSKIRNIR_BASE_URL:-}" ] && args+=(--base-url "$BILSKIRNIR_BASE_URL")
  node "$APP/server/src/models/detect.ts" "${args[@]}" 2> "$RUN_TMP"
}
RUN_TMP="$(mktemp)"; trap 'rm -f "$RUN_TMP"' EXIT
BLOCK="$(model_block)"; BRC=$?
case "$BRC" in
  0) why="$(grep -v -e ExperimentalWarning -e 'trace-warnings' "$RUN_TMP" | tail -1)" ;;
  3) why="no model found yet — open Settings > Models in the hall and use one you already have, or set BILSKIRNIR_MODEL"; BLOCK="" ;;
  *) why="the model detector could not run (needs node 22.18 or newer) — set BILSKIRNIR_MODEL and BILSKIRNIR_BASE_URL"; BLOCK="" ;;
esac
MODEL="$(printf '%s' "$BLOCK" | sed -n 's/^  default: "\(.*\)"$/\1/p')"
if [ "$CHECK" = 0 ]; then
  umask 077
  { printf '# Rendered by apps/bilskirnir/setup.sh — the first agent'"'"'s own Hermes home. The house refreshes its own parts on every setup; what you add is kept.\n'
    [ -n "$BLOCK" ] && printf '%s\n' "$BLOCK"
    # The house parts — Ymir's MCP doors, the house hands, the toolsets, the browser pinned to her own
    # screen when she has a desk, the Sága session hook — from the one renderer every agent shares.
    if [ "$DESK_UP" = 1 ]; then python3 "$APP/house/house.py" parts --browser "http://$DESK_HOST:9299"
    else python3 "$APP/house/house.py" parts; fi
  } > "$ENGINE/config.yaml.rendered"
  # an update refreshes the house's parts and keeps what the user added (plan 275): merged, never overwritten
  if [ -f "$ENGINE/config.yaml" ]; then
    python3 "$APP/house/house.py" merge --existing "$ENGINE/config.yaml" --rendered "$ENGINE/config.yaml.rendered" > "$ENGINE/config.yaml.next" \
      && mv "$ENGINE/config.yaml.next" "$ENGINE/config.yaml"
  else
    mv "$ENGINE/config.yaml.rendered" "$ENGINE/config.yaml"
  fi
  rm -f "$ENGINE/config.yaml.rendered" "$ENGINE/config.yaml.next"
  # the hook runs only with the operator's consent, given once for the machine's Hermes — carried here
  [ -f "$HOME/.hermes/shell-hooks-allowlist.json" ] && cp "$HOME/.hermes/shell-hooks-allowlist.json" "$ENGINE/shell-hooks-allowlist.json"
  [ -f "$ENGINE/.env" ] || printf 'API_SERVER_ENABLED=true\nAPI_SERVER_KEY=%s\nAPI_SERVER_PORT=%s\nAPI_SERVER_HOST=127.0.0.1\n' \
    "$(head -c 24 /dev/urandom | base64 | tr -d '/+=')" "$HPORT" > "$ENGINE/.env"
  say "agent home: data/engines/$SLUG (${MODEL:-no model yet})"
  say "model: $why"
else
  if [ -n "$MODEL" ]; then
    grep -q "default: \"$MODEL\"" "$ENGINE/config.yaml" 2>/dev/null && grep -q "ymir-mcp.py" "$ENGINE/config.yaml" && say "agent home current (model $MODEL and Ymir's MCP doors)" || { say "agent home missing or on another model"; fail=1; }
  else
    grep -q "ymir-mcp.py" "$ENGINE/config.yaml" 2>/dev/null && say "agent home current (no model chosen yet: $why)" || { say "agent home missing"; fail=1; }
  fi
  if [ "$DESK_UP" = 1 ]; then
    grep -q "cdp_url: \"http://$DESK_HOST:9299\"" "$ENGINE/config.yaml" 2>/dev/null && say "agent's browser drives her desk" || { say "agent's browser is not pinned to her desk — re-run setup.sh"; fail=1; }
  fi
fi

# ── 5. the app's .env: one managed block, the rest is the operator's ────────────
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

# ── 6. the code's dependencies, from the lock files ─────────────────────────────
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

# ── 7. the database follows the roster ──────────────────────────────────────────
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
# The same template the house's desktop layer renders (bin/desktop/desktop-place.sh entries), so the two
# writers can never disagree: electron/ymir-bilskirnir.desktop.in with __YMIR_ROOT__ = the pin, and the
# bronze Ymir mark seated in the icon theme at every size the launcher asks for. Only where a desktop
# exists (Rule 25: probe, never assume) — a server host gets a clean skip.
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DESK="$DATA_HOME/applications/ymir-bilskirnir.desktop"
REPO="$(dirname "$(dirname "$APP")")"
# The launcher runs the PINNED runtime, never the tree setup ran from (plan 269, RULES/02 §7): on
# 2026-11-12 this entry pointed into an errand worktree. One resolver, the arm pin's; the default
# ~/ymir-runtime applies once install has seated it.
PINROOT=""
[ -r "$REPO/bin/pi/arm-pin-lib.sh" ] && . "$REPO/bin/pi/arm-pin-lib.sh" && arm_pin_dir PINROOT
[ -n "$PINROOT" ] || PINROOT="$HOME/ymir-runtime"
want_desk="$(sed -e "s|__YMIR_ROOT__|$PINROOT|g" -e "s|__YMIR_APP__|${YMIR_SHORTCUT_BIN:-$HOME/.local/bin}/ymir-app|g" "$APP/electron/ymir-bilskirnir.desktop.in" 2>/dev/null)"
if [ "${BILSKIRNIR_DESKTOP:-1}" = 0 ]; then
  say "launcher entry skipped (BILSKIRNIR_DESKTOP=0)"
elif [ ! -e "$PINROOT/apps/bilskirnir/start.sh" ]; then
  say "launcher entry skipped — the pinned runtime ($PINROOT) does not carry Bilskirnir yet (bin/engine/runtime-deploy.sh moves it)"
elif [ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && [ ! -d "$DATA_HOME/applications" ]; then
  say "no desktop on this host — no launcher entry"
elif [ "$CHECK" = 1 ]; then
  if [ "$(cat "$DESK" 2>/dev/null)" = "$want_desk" ] && [ -f "$DATA_HOME/icons/hicolor/256x256/apps/ymir-bilskirnir.png" ]; then
    say "launcher entry current (Bilskirnir, the bronze mark)"
  else
    say "launcher entry missing or stale — re-run setup.sh"; fail=1
  fi
else
  mkdir -p "$(dirname "$DESK")" "$DATA_HOME/icons/hicolor"
  printf '%s\n' "$want_desk" > "$DESK"
  cp -r "$APP/electron/icons/hicolor/." "$DATA_HOME/icons/hicolor/"
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$(dirname "$DESK")" >/dev/null 2>&1
  command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t -f "$DATA_HOME/icons/hicolor" >/dev/null 2>&1
  say "launcher entry seated (Bilskirnir, the bronze mark)"
fi

# ── 8. the voice: the house's own ear and mouth (BILSKIRNIR_VOICE=house, the default) ──
# Reported, never raised: Rödd's engine is the voice door's to raise (bin/voice/voice-door.sh host), and
# Kokoro's unit wakes on the first preview. A missing ear (whisper) fails the check, because dictation is the
# composer's own button; a lowered engine or a sleeping Kokoro is said, not failed, since they wake on demand.
ROAD="$(printf '%s' "${BILSKIRNIR_VOICE:-house}" | tr 'A-Z' 'a-z')"
if [ "$ROAD" = "xai" ]; then
  say "voice road: xai (xAI's cloud) — needs XAI_API_KEY in .env"
else
  WCLI="${BILSKIRNIR_WHISPER_CLI:-$HOME/whisper.cpp.src/build/bin/whisper-cli}"
  WMODEL="${BILSKIRNIR_WHISPER_MODEL:-$HOME/whisper.cpp/models/ggml-small.en.bin}"
  KOKORO="${BILSKIRNIR_KOKORO_URL:-http://127.0.0.1:8765}"
  RT="${BILSKIRNIR_REALTIME_URL:-ws://127.0.0.1:${YMIR_VOICE_PORT:-8890}/v1/realtime}"
  RT_HTTP="$(printf '%s' "$RT" | sed -E 's#^ws#http#; s#/v1/realtime.*$##')"
  say "voice road: house (whisper in, Rödd's engine, Kokoro out — nothing reaches xAI)"
  if [ -x "$WCLI" ] && [ -f "$WMODEL" ] && command -v "${BILSKIRNIR_FFMPEG:-ffmpeg}" >/dev/null 2>&1; then
    say "voice ear: whisper.cpp ready ($(basename "$WMODEL"))"
  else
    say "voice ear: missing — dictation needs whisper-cli ($WCLI), its model ($WMODEL) and ffmpeg"; fail=1
  fi
  if curl -fsS -m 2 "$KOKORO/health" >/dev/null 2>&1; then say "voice mouth: Kokoro answers at $KOKORO"
  else say "voice mouth: Kokoro asleep at $KOKORO (the unit ${BILSKIRNIR_KOKORO_UNIT:-kokoro-serve.service} wakes on the first preview)"; fi
  if pool="$(curl -fsS -m 2 "$RT_HTTP/v1/pool" 2>/dev/null)"; then
    say "voice call: Rödd's engine answers ($(printf '%s' "$pool" | python3 -c 'import sys,json; j=json.load(sys.stdin); print(f"{j.get(\"size\",0)-j.get(\"in_use\",0)} of {j.get(\"size\",0)} seats free")' 2>/dev/null || echo up))"
  else
    say "voice call: Rödd's engine is not raised — voice chat waits for: bin/voice/voice-door.sh host"
  fi
fi

[ "$fail" = 0 ] && { say "ready"; exit 0; } || { say "not ready"; exit 1; }
