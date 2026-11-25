#!/usr/bin/env bash
# huginn-web.sh — Huginn's eyes on the web: Firecrawl, SearXNG and the headless browser (plan 373).
#
# Huginn is the raven who flies out and brings back what he sees, so the three web tools are his:
#   firecrawl  search / scrape / map / crawl   a compose stack, project `firecrawl`, loopback :3002
#   searxng    the search engine Firecrawl uses  one container, joined to the stack's network
#   browser    Playwright MCP on chrome-headless-shell, started by the harness on demand
#
#   huginn-web.sh status [--json]   one row per tool: up | down | missing, where, road (local|borrowed|none)
#   huginn-web.sh up                raise the stack from its MAIN checkout, join SearXNG, wait, prove one search
#   huginn-web.sh down              lower the stack (volumes stay); SearXNG is left running
#
# Config (RULES/07: one documented default each; never an address in this file's callers):
#   YMIR_FIRECRAWL_URL            where Firecrawl answers            (default http://127.0.0.1:3002)
#   YMIR_FIRECRAWL_BORROW_URL     another machine's Firecrawl to borrow when the local one is down (default none)
#   YMIR_FIRECRAWL_DIR            the stack's main checkout          (default ~/firecrawl)
#   YMIR_FIRECRAWL_PROJECT        compose project name               (default firecrawl)
#   YMIR_SEARXNG_CONTAINER        the SearXNG container              (default ymir-searxng)
#   YMIR_SEARXNG_URL              where SearXNG answers              (default http://127.0.0.1:8899)
# The same keys may sit in $YMIR_HOME/config/huginn.env (KEY=value lines; read, never sourced).
# A seat with no stack and no borrow address reports `down`/`none` and names the one command to run.
#
# The container law (~/CLAUDE.md 2026-11-20): look before raising, raise only from a main checkout (never a
# worktree or /tmp), restart: unless-stopped and an owner label (the stack's override file carries both;
# `up` refuses a stack whose override does not), loopback only, and no build below 50 GiB free on /.
# Exit: 0 ready · 1 a tool is down or a step failed · 2 usage.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cfg() {  # cfg KEY default — env first, then the home's huginn.env, then the default
  local k="$1" d="$2" v="${!1:-}" f line
  if [ -z "$v" ]; then
    f="${YMIR_HOME:-$HOME/Documents/ymirhome}/config/huginn.env"
    [ -r "$f" ] && line="$(grep -E "^[[:space:]]*$k=" "$f" | tail -1)" && v="$(printf '%s' "${line#*=}" | sed -E "s/^[\"']//; s/[\"']\$//")"
  fi
  printf '%s' "${v:-$d}"
}
FC_URL="$(cfg YMIR_FIRECRAWL_URL http://127.0.0.1:3002)"
FC_BORROW="$(cfg YMIR_FIRECRAWL_BORROW_URL '')"
FC_DIR="$(cfg YMIR_FIRECRAWL_DIR "$HOME/firecrawl")"
FC_PROJECT="$(cfg YMIR_FIRECRAWL_PROJECT firecrawl)"
SX_NAME="$(cfg YMIR_SEARXNG_CONTAINER ymir-searxng)"
SX_URL="$(cfg YMIR_SEARXNG_URL http://127.0.0.1:8899)"
NETWORK="${FC_PROJECT}_backend"

have() { command -v "$1" >/dev/null 2>&1; }
alive() { curl -s -m 4 -o /dev/null -w '%{http_code}' "$1" 2>/dev/null | grep -qE '^[2345]'; }  # any HTTP answer
is_loop() { case "$1" in http://127.*|http://localhost*|http://\[::1\]*) return 0 ;; esac; return 1; }

firecrawl_row() {  # prints: state where road
  if alive "$FC_URL"; then
    is_loop "$FC_URL" && printf 'up %s local' "$FC_URL" || printf 'up %s borrowed' "$FC_URL"
  elif [ -n "$FC_BORROW" ] && alive "$FC_BORROW"; then
    printf 'up %s borrowed' "$FC_BORROW"
  else
    printf 'down %s none' "$FC_URL"
  fi
}
searxng_row() {
  if alive "$SX_URL"; then printf 'up %s local' "$SX_URL"
  elif have docker && docker inspect "$SX_NAME" >/dev/null 2>&1; then printf 'down %s local' "$SX_URL"
  else printf 'missing %s none' "$SX_URL"; fi
}
browser_row() {
  local out; out="$(bash "$HERE/../seat/playwright-mcp-launch.sh" --check 2>/dev/null | sed -n 2p)"
  case "$out" in
    *'"ready"'*) printf 'up %s local' "on demand (headless shell)" ;;
    *) printf 'missing %s none' "no chrome-headless-shell: npx playwright install chromium-headless-shell" ;;
  esac
}

cmd_status() {
  local json=0; [ "${1-}" = "--json" ] && json=1
  local fc sx br bad=0 t s w r
  fc="$(firecrawl_row)"; sx="$(searxng_row)"; br="$(browser_row)"
  if [ "$json" = 1 ]; then
    printf '{'; local first=1
    for t in firecrawl searxng browser; do
      case $t in firecrawl) set -- $fc ;; searxng) set -- $sx ;; browser) set -- $br ;; esac
      s="$1"; r="${@: -1}"; w="${*:2:$(($#-2))}"
      [ $first = 1 ] || printf ','; first=0
      printf '"%s":{"state":"%s","where":"%s","road":"%s"}' "$t" "$s" "$w" "$r"
    done; printf '}\n'
  else
    printf 'huginn_web[3]{tool,state,where,road}:\n'
    for t in firecrawl searxng browser; do
      case $t in firecrawl) set -- $fc ;; searxng) set -- $sx ;; browser) set -- $br ;; esac
      s="$1"; r="${@: -1}"; w="${*:2:$(($#-2))}"
      printf '  "%s","%s","%s","%s"\n' "$t" "$s" "$w" "$r"
    done
  fi
  case "$fc" in up*) ;; *) bad=1; [ "$json" = 1 ] || printf 'help: Firecrawl is down — bin/fleet/huginn-web.sh up\n' ;; esac
  case "$sx" in up*) ;; *) bad=1; [ "$json" = 1 ] || printf 'help: SearXNG is not answering — Firecrawl cannot search until it does\n' ;; esac
  return $bad
}

prove_search() {
  local out
  out="$(curl -s -m 60 -X POST "$FC_URL/v1/search" -H 'Content-Type: application/json' -d '{"query":"ymir","limit":1}' 2>/dev/null)"
  printf '%s' "$out" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(1)
sys.exit(0 if d.get("success") and d.get("data") else 1)' 2>/dev/null
}

cmd_up() {
  have docker || { echo 'huginn up: docker is not installed here — set YMIR_FIRECRAWL_BORROW_URL to borrow another machine'"'"'s Firecrawl' >&2; return 1; }
  # look before you raise
  if alive "$FC_URL" && is_loop "$FC_URL"; then
    echo "huginn up: Firecrawl already answers at $FC_URL — not raising a second copy"
  else
    is_loop "$FC_URL" || { echo "huginn up: YMIR_FIRECRAWL_URL ($FC_URL) is not on this machine — nothing to raise here" >&2; return 1; }
    [ -f "$FC_DIR/docker-compose.yaml" ] || { echo "huginn up: no Firecrawl checkout at $FC_DIR (YMIR_FIRECRAWL_DIR)" >&2; return 1; }
    case "$(cd "$FC_DIR" && pwd -P)" in
      */.yggdrasil/*|/tmp/*|/var/tmp/*|*/scratchpad/*) echo "huginn up: $FC_DIR is a worktree or scratch path; a stack is raised only from the main checkout" >&2; return 1 ;;
    esac
    grep -q 'ymir.owner' "$FC_DIR"/docker-compose.override.y*ml 2>/dev/null \
      || { echo "huginn up: $FC_DIR has no override giving the containers 'restart: unless-stopped' and a ymir.owner label (container law)" >&2; return 1; }
    local free; free="$(df -BG --output=avail / | tail -1 | tr -dc '0-9')"
    # A cold start races RabbitMQ's healthcheck (measured: the first `up` after a `down` reports it
    # unhealthy, and it is healthy a minute later), so the raise is tried up to three times.
    local try=0 log=""
    until log="$( cd "$FC_DIR" && docker compose -p "$FC_PROJECT" up -d --no-build 2>&1 )"; do
      try=$((try+1))
      if [ $try -ge 3 ]; then
        echo "huginn up: compose could not start the stack after 3 tries: $(printf '%s\n' "$log" | tail -1)" >&2
        printf '%s' "$log" | grep -qiE 'pull access|no such image|not found' && { [ "${free:-0}" -lt 50 ] \
          && echo "huginn up: images are missing and / has only ${free} GiB free (law: 50) — not building" >&2 \
          || echo "huginn up: images are missing — build once by hand: cd $FC_DIR && docker compose -p $FC_PROJECT build" >&2; }
        return 1
      fi
      sleep 25
    done
  fi
  # SearXNG joins the stack's network (lost whenever it is recreated, so it is done every time)
  if docker inspect "$SX_NAME" >/dev/null 2>&1; then
    docker network inspect "$NETWORK" >/dev/null 2>&1 || { echo "huginn up: network $NETWORK is missing" >&2; return 1; }
    docker inspect "$SX_NAME" --format '{{json .NetworkSettings.Networks}}' | grep -q "\"$NETWORK\"" \
      || docker network connect "$NETWORK" "$SX_NAME" >/dev/null 2>&1 || { echo "huginn up: could not join $SX_NAME to $NETWORK" >&2; return 1; }
  else
    echo "huginn up: no SearXNG container named $SX_NAME — Firecrawl will scrape but not search" >&2
  fi
  local i=0; until alive "$FC_URL"; do i=$((i+1)); [ $i -gt 30 ] && { echo "huginn up: $FC_URL did not answer in 60 s" >&2; return 1; }; sleep 2; done
  if prove_search; then echo "huginn up: ready — Firecrawl answers at $FC_URL and one search returned a result"
  else echo "huginn up: Firecrawl answers at $FC_URL but a search returned nothing — is SearXNG healthy?" >&2; return 1; fi
}

cmd_down() {
  have docker || { echo 'huginn down: docker is not installed here' >&2; return 1; }
  [ -f "$FC_DIR/docker-compose.yaml" ] || { echo "huginn down: no Firecrawl checkout at $FC_DIR" >&2; return 1; }
  docker inspect "$SX_NAME" >/dev/null 2>&1 && docker network disconnect "$NETWORK" "$SX_NAME" >/dev/null 2>&1
  ( cd "$FC_DIR" && docker compose -p "$FC_PROJECT" down ) >/dev/null 2>&1 \
    && echo "huginn down: the $FC_PROJECT stack is lowered (volumes kept; $SX_NAME left running)" \
    || { echo "huginn down: compose refused" >&2; return 1; }
}

case "${1-}" in
  status|"") shift || true; cmd_status "$@" ;;
  up) cmd_up ;;
  down) cmd_down ;;
  -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "huginn-web: unknown command '$1' (status|up|down)" >&2; exit 2 ;;
esac
