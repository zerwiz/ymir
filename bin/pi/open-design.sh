#!/usr/bin/env bash
# open-design.sh — the Allfather's door to OpenDesign (Hnoss) on this seat.
#
# OpenDesign is the open-source, local-first design engine (nexu-io/open-design,
# Apache-2.0): your coding agent becomes the design engine — prototypes, landing
# pages, decks, images, video — written as real files.
#
# On THIS seat it runs as a container (`ghcr.io/nexu-io/od:latest`, or `od:local`)
# publishing port 7456. This script is the only sanctioned way to start, stop,
# and interrogate it. Never `docker restart open-design` by hand while a project
# is generating — that kills the run.
#
# Usage:
#   bin/open-design.sh start|stop|status|health|logs|projects|new|rm|open
#
# House law: config is never hardcoded (Rule 07). Everything resolves from env with
# one documented default.

set -uo pipefail

DEPLOY_DIR="${OD_DEPLOY_DIR:-$HOME/opendesign/deploy}"
COMPOSE_FILE="${OD_COMPOSE_FILE:-docker-compose.allfather.yml}"
PORT="${OPEN_DESIGN_PORT:-7456}"
CONTAINER="${OD_CONTAINER:-open-design}"
BASE="http://127.0.0.1:${PORT}"

compose() {
  docker compose -f "${DEPLOY_DIR}/${COMPOSE_FILE}" "$@"
}

api() { curl -s -m "${OD_API_TIMEOUT:-10}" "$@"; }

cmd_start() {
  if cmd_status >/dev/null 2>&1; then
    echo "open-design already up on ${PORT}"; return 0
  fi
  echo "raising open-design on :${PORT} …"
  compose up -d
  # Docker is healthy before the daemon answers; wait for the real door.
  for _ in $(seq 1 30); do
    if api "${BASE}/api/health" | grep -q '"ok":true'; then
      echo "open-design is up → ${BASE}"; return 0
    fi
    sleep 1
  done
  echo "open-design did not answer on :${PORT}; see: bin/open-design.sh logs" >&2
  return 1
}

cmd_stop()   { compose down; }
cmd_health() { api "${BASE}/api/health"; echo; }
cmd_logs()   { docker logs --tail "${OD_LOG_LINES:-80}" -f "${CONTAINER}"; }

cmd_status() {
  local up; up="$(docker ps --filter "name=^${CONTAINER}$" --format '{{.Status}}' 2>/dev/null)"
  [ -n "${up}" ] || return 1
  echo "container: ${CONTAINER}  ${up}"
  local h; h="$(api "${BASE}/api/health" || true)"
  [ -n "${h}" ] && echo "health:    ${h}"
  return 0
}

cmd_projects() { api "${BASE}/api/projects"; echo; }

cmd_new() {
  [ -n "${1:-}" ] || { echo "usage: bin/open-design.sh new <id> [name]" >&2; return 2; }
  local id="$1" name="${2:-$1}"
  api -X POST "${BASE}/api/projects" -H 'Content-Type: application/json' \
    -d "$(printf '{"id":"%s","name":"%s","kind":"prototype","fidelity":"high"}' "${id}" "${name}")"
  echo
}

cmd_rm() {
  [ -n "${1:-}" ] || { echo "usage: bin/open-design.sh rm <id>" >&2; return 2; }
  api -X DELETE "${BASE}/api/projects/${1}"; echo
}

cmd_open() { xdg-open "${BASE}" >/dev/null 2>&1 || sensible-browser "${BASE}" >/dev/null 2>&1 || echo "${BASE}"; }

case "${1:-status}" in
  start|stop|status|health|logs|projects|new|rm|open)
    "cmd_${1}" "${2:-}" "${3:-}" ;;
  *)
    sed -n '2,30p' "$0"; exit 2 ;;
esac