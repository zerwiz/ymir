#!/usr/bin/env bash
# stt-wire.sh — point the meeting stack at the house's STT, in the only order that works.
#
#   stt-wire.sh check      # is every link of the chain true, right now?
#   stt-wire.sh wire       # do it (refuses to half-do it)
#
# THE CHAIN (plan 111 · S1, measured 2026-10-23):
#   1. whisper answers /inference on 127.0.0.1:10300
#   2. stt-shim answers /health and /v1/audio/transcriptions on 0.0.0.0:10310  (OpenAI contract)
#   3. a container on the compose network can reach the shim
#   4. TRANSCRIPTION_SERVICE_URL + TOKEN are set in the vexa env
#   5. TRANSCRIBE_ENABLED=true, and the meeting-api is restarted
# Refusal is the point: flipping 4–5 while 3 is false replaces a 503 with a spawn that is refused by the
# probe — two different lies. So `wire` checks 1–3 first and prints the exact remedy when one is missing.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VEXA="${VEXA_DIR:-$HOME/CodeP/vexa}"
ENV_FILE="$VEXA/deploy/compose/.env"
COMPOSE="$VEXA/deploy/compose/docker-compose.yml"
NET="${VEXA_NETWORK:-vexa-v012_vexa}"
API="${VEXA_API_CONTAINER:-vexa-v012-meeting-api-1}"
GW="$(docker inspect "$API" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$v.Gateway}} {{end}}' 2>/dev/null | awk '{print $1}')"
SHIM_PORT="${STT_SHIM_PORT:-10310}"
SHIM_URL="http://$GW:$SHIM_PORT"
ACTION="${1:-check}"

say() { printf '%s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*" >&2; }
ok() { printf '  ok    %s\n' "$*"; }

# 1 · whisper
if curl -s -m 4 -o /dev/null -X POST http://127.0.0.1:10300/inference -F file=@/dev/null 2>/dev/null \
   || curl -s -m 4 -o /dev/null http://127.0.0.1:10300/ 2>/dev/null; then ok "whisper answers on :10300"
else fail "whisper is not answering on :10300 — systemctl --user start snotra-whisper"; fi

# 2 · the shim
H="$(curl -s -m 4 "http://127.0.0.1:$SHIM_PORT/health" 2>/dev/null)"
case "$H" in *ok*) ok "the shim answers on :$SHIM_PORT";; *) fail "the shim is down — systemctl --user start stt-shim";; esac

# 3 · the container can reach it (the wall proven on 2026-10-23: ufw blocks the bridge → host path)
REACH="$(timeout 60 docker run --rm --network "$NET" curlimages/curl:latest -s -m 5 -o /dev/null \
          -w '%{http_code}' "$SHIM_URL/health" 2>/dev/null | tail -1)"
if [ "$REACH" = "200" ]; then ok "the compose network reaches $SHIM_URL"
else
  fail "the compose network cannot reach $SHIM_URL (curl $REACH)"
  say  "        the host firewall blocks the bridge — one scoped rule fixes it, and only this port:"
  say  "          sudo ufw allow from 172.20.0.0/16 to any port $SHIM_PORT proto tcp"
fi

# 4–5 · the environment and the restart
if [ ! -f "$ENV_FILE" ]; then say "  (no $ENV_FILE — nothing to wire)"; exit 3; fi
if [ "$ACTION" = "wire" ]; then
  [ "$REACH" = "200" ] || { say "stt-wire: refusing to flip the environment while the path is closed (see the rule above)"; exit 3; }
  python3 - "$ENV_FILE" "$SHIM_URL" <<'PY'
import sys, pathlib
path, url = pathlib.Path(sys.argv[1]), sys.argv[2]
vals = {"TRANSCRIPTION_SERVICE_URL": url, "TRANSCRIPTION_SERVICE_TOKEN": "local",
        "TRANSCRIBE_ENABLED": "true", "TRANSCRIPTION_MODEL": "whisper-1"}
lines = path.read_text().splitlines()
seen = set()
for i, line in enumerate(lines):
    for k, v in vals.items():
        if line.startswith(k + "="):
            lines[i] = f"{k}={v}"; seen.add(k)
for k, v in vals.items():
    if k not in seen:
        lines.append(f"{k}={v}")
path.write_text("\n".join(lines) + "\n")
print("stt-wire: env written:", ", ".join(sorted(vals)))
PY
  ( cd "$VEXA/deploy/compose" && docker compose up -d meeting-api >/dev/null 2>&1 ) || \
    docker restart "$API" >/dev/null 2>&1
  sleep 6
  docker exec "$API" printenv TRANSCRIPTION_SERVICE_URL 2>/dev/null | sed 's/^/  service url: /'
  say "stt-wire: wired — the NEXT bot spawn transcribes (existing meetings are not retroactive)"
fi
