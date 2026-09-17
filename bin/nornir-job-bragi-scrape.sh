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
# Firecrawl is BYOK: FIRECRAWL_API_KEY comes from the home's platform.env
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
hoard_data_dir _DATA

SOURCES="${BROKK_SCRAPE_SOURCES:-$_HOME/config/scrape-sources.yaml}"
OUT_DIR="${BROKK_SCRAPE_OUT:-$_HOME/workspaces/marketing/scraped}"
mkdir -p "$OUT_DIR"

# Firecrawl key: from the home's secrets, by path — never inline.
FIRECRAWL_API_KEY="${FIRECRAWL_API_KEY:-}"
if [ -z "$FIRECRAWL_API_KEY" ] && [ -x "$ROOT/bin/hodd.sh" ]; then
  FIRECRAWL_API_KEY="$("$ROOT/bin/hodd.sh" emit secrets/platform.env 2>/dev/null | grep -m1 '^FIRECRAWL_API_KEY=' | cut -d= -f2-)"
fi

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

if [ -z "$FIRECRAWL_API_KEY" ]; then
  failed=$failed; skipped=1
  printf 'bragi-scrape: FIRECRAWL_API_KEY absent — sources listed, nothing scraped\n'
  # still record the rune honestly
else
  while IFS='|' read -r name url kind; do
    [ -n "$name" ] || continue
    out="$OUT_DIR/$TODAY-$name.md"
    if python3 - "$url" "$kind" "$out" "$FIRECRAWL_API_KEY" <<'PY'
import os, sys
url, kind, out, key = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    from firecrawl import FirecrawlApp
except ImportError:
    sys.exit(2)  # engine not installed
app = FirecrawlApp(api_key=key)
try:
    doc = app.scrape_url(url, params={"formats": ["markdown"]}) if kind == "scrape" \
        else app.search(url, params={"formats": ["markdown"]})
    text = doc.get("markdown", "") if isinstance(doc, dict) else str(doc)
    with open(out, "w") as f:
        f.write("<!-- source: %s ; kind: %s ; fetched: %s -->\n\n%s\n" % (url, kind, __import__("datetime").datetime.utcnow().isoformat() + "Z", text))
    sys.exit(0)
except Exception as exc:
    print("scrape error: %s" % exc, file=sys.stderr)
    sys.exit(1)
PY
    then ok=$((ok+1))
    elif [ $? -eq 2 ]; then skipped=$((skipped+1))
    else failed=$((failed+1)); fi
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