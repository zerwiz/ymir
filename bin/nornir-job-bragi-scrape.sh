#!/usr/bin/env bash
# nornir-job-bragi-scrape.sh — Bragi, on the loom: the scheduled scrape round.
#
# Reads a list of sources from the USER'S home (never the tree) and scrapes
# each with Firecrawl into clean markdown, landed in the marketing workspace.
# The source list is the operator's:  $YMIR_HOME/config/scrape-sources.yaml
#
#   format:
#     sources:
#       - name: monster-stack
#         url: https://example.com/docs
#         kind: scrape|search        # default scrape
#         note: why this source matters
#
# Firecrawl: a SELF-HOSTED engine needs a URL, not a key. The fleet runs it on
# its own iron (heimdall/whynot, :3002). A cloud key is still honoured, but the
# key is not the only road. (Was: BYOK only — FIRECRAWL_API_KEY from platform.env
# (bin/hodd.sh emit), never inline. A missing key is reported, not faked — the
# job is honest about what it could not do.
#
# Stateless: read sources → scrape → write markdown under the marketing
# workspace → carve one Rune → exit.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# The home the operator chose — one answer, never drift (Rule 04/07).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_root _HOME
hoard_settings_dir _SETTINGS
hoard_data_dir _DATA

# The source list is the OPERATOR'S settings, beside agents.yaml and cron.yaml —
# $YMIR_HOME/config/. It once resolved to _HOME/config ($YMIR_HOME/hodd/config),
# a shelf that does not exist, so the job said "no sources" while the file sat in
# the settings dir the header always named.
SOURCES="${BROKK_SCRAPE_SOURCES:-$_SETTINGS/scrape-sources.yaml}"
OUT_DIR="${BROKK_SCRAPE_OUT:-$_HOME/workspaces/marketing/scraped}"
mkdir -p "$OUT_DIR"

# Firecrawl key: from the home's secrets, by path — never inline.
FIRECRAWL_API_KEY="${FIRECRAWL_API_KEY:-}"
if [ -z "$FIRECRAWL_API_KEY" ] && [ -x "$ROOT/bin/hodd.sh" ]; then
  FIRECRAWL_API_KEY="$("$ROOT/bin/hodd.sh" emit secrets/platform.env 2>/dev/null | grep -m1 '^FIRECRAWL_API_KEY=' | cut -d= -f2-)"
fi
# The base URL: env -> the home's local env -> one documented default (the
# self-hosted engine on this machine). Rule 07: never a literal deep in logic.
FIRECRAWL_API_URL="${FIRECRAWL_API_URL:-}"
if [ -z "$FIRECRAWL_API_URL" ] && [ -x "$ROOT/bin/hodd.sh" ]; then
  FIRECRAWL_API_URL="$("$ROOT/bin/hodd.sh" emit secrets/platform.env 2>/dev/null | grep -m1 '^FIRECRAWL_API_URL=' | cut -d= -f2-)"
fi
FIRECRAWL_API_URL="${FIRECRAWL_API_URL:-http://localhost:3002}"

[ -r "$SOURCES" ] || {
  printf 'bragi-scrape: no sources at %s — nothing scheduled to scrape (exit 0)\n' "$SOURCES"
  exit 0
}

command -v python3 >/dev/null 2>&1 || { printf 'error: python3 required for Firecrawl SDK\n'; exit 1; }

# Parse the YAML sources (name/url/kind) and scrape each with the SDK.
TODAY="$(date -u +%Y-%m-%d)"
ok=0; failed=0; skipped=0
rows="$(python3 - "$SOURCES" <<'PY'
import sys, re
txt = open(sys.argv[1]).read()
items = []
for m in re.finditer(r'^\s*-\s+name:\s*(\S+)\s*$', txt, re.M):
    start = m.end()
    name = m.group(1)
    url = kind = ""
    for line in txt[start:].splitlines():
        line = line.strip()
        if line.startswith("- name:") : break
        if line.startswith("url:") and not url: url = line[4:].strip()
        if line.startswith("kind:") and not kind: kind = line[5:].strip()
    items.append((name, url, kind or "scrape"))
for i in items: print("|".join(i))
PY
)"

if ! curl -s -m 5 -o /dev/null "$FIRECRAWL_API_URL/" 2>/dev/null; then
  skipped=$(printf '%s\n' "$rows" | grep -c .)
  printf 'bragi-scrape: no Firecrawl at %s — sources listed, nothing scraped\n' "$FIRECRAWL_API_URL"
  printf 'help: start the self-hosted engine (docker compose up -d in ~/firecrawl)\n'
else
  while IFS='|' read -r name url kind; do
    [ -n "$name" ] || continue
    out="$OUT_DIR/$TODAY-$name.md"
    # curl, not the SDK: no pip dependency, and the self-hosted engine answers
    # the same /v2/scrape shape as the cloud service.
    # scrape takes a URL; search takes a QUERY — different endpoints, and a
    # query passed to /scrape is rejected with "Invalid URL".
    if [ "$kind" = "search" ]; then
      endpoint="/v2/search"
      body="$(python3 -c 'import json,sys;print(json.dumps({"query":sys.argv[1],"limit":5}))' "$url")"
    else
      endpoint="/v2/scrape"
      body="$(python3 -c 'import json,sys;print(json.dumps({"url":sys.argv[1],"formats":["markdown"]}))' "$url")"
    fi
    if curl -s -m 120 -X POST "$FIRECRAWL_API_URL$endpoint" \
         -H 'Content-Type: application/json' -d "$body" \
         | python3 -c '
import json,sys,datetime
try:
    d=json.load(sys.stdin)
except Exception as e:
    print("bad answer: %s" % e, file=sys.stderr); sys.exit(1)
if not d.get("success"):
    print("scrape refused: %s" % str(d)[:200], file=sys.stderr); sys.exit(1)
data=d.get("data")
if isinstance(data, list):
    md="\n\n---\n\n".join(("## %s\n%s" % (r.get("title",""), r.get("markdown") or r.get("description") or r.get("url",""))) for r in data)
elif isinstance(data, dict):
    md=data.get("markdown","")
else:
    md=""
out,url,kind=sys.argv[1],sys.argv[2],sys.argv[3]
open(out,"w").write("<!-- source: %s ; kind: %s ; fetched: %s -->\n\n%s\n" % (url,kind,datetime.datetime.utcnow().isoformat()+"Z",md))
' "$out" "$url" "$kind"
    then ok=$((ok+1)); else failed=$((failed+1)); fi
  done <<< "$rows"
fi

printf 'bragi-scrape: sources=%s ok=%s failed=%s skipped=%s out=%s\n' \
  "$(printf '%s\n' "$rows" | grep -c .)" "$ok" "$failed" "$skipped" "$OUT_DIR"

# Carve the Rune — the ledger lives in the hoard.
# shellcheck source=bin/runes-append.sh
. "$ROOT/bin/runes-append.sh"
runes_append "bragi" "scrape.round" --realm "${BROKK_REALM:-}" \
  --message "scrape round: ok=$ok failed=$failed skipped=$skipped -> $OUT_DIR" >/dev/null \
  || printf 'bragi-scrape: rune append failed (non-fatal)\n'
[ "$failed" = 0 ] && exit 0 || exit 1