#!/usr/bin/env bash
# app-functional-guard.sh — AN UPDATE THAT LEAVES AN APP UNRUNNABLE IS NOT AN UPDATE.
#
# This ward exists because of one day: commit 068f0872 inserted a row into the
# watchtower and ate the `return {` that opened the object. The gate API stopped
# parsing — not at request time, at LOAD time — so every /api/* answered 500 with
# zero bytes, the SPA said "Unexpected end of JSON input", the well read DOWN while
# its bridge stood healthy on :4602, and the stats read empty. Nothing failed the
# build, because nothing asked the app whether it could even be read.
#
# Three checks, seconds, no window and no server process:
#   1. PARSES — every app's server entry is transpiled in memory. A syntax error is
#      a dead app, and it costs nothing to find out.
#   2. ROUTE PARITY — every `/api/...` the UI calls exists on the server. Þráðr asked
#      for /api/terminal/status, which was never implemented, so that panel showed
#      "terminal status 404" instead of a terminal — an interface promising a door.
#   3. --live — against a running gate, no route answers 5xx.
#
# Usage:
#   app-functional-guard.sh check          # parse + route parity (no server needed)
#   app-functional-guard.sh check --live   # also probe a running gate for 5xx
#   app-functional-guard.sh --version
#
# Exit: 0 clean · 1 a finding · 2 usage. No bun → a clean SKIP, never a FAIL (Rule 25).
set -u

VERSION="1.0.0"
_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
ROOT="$(_root)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check) shift ;;
  "") ;;
  *) printf 'error: unknown action %s\nhelp: app-functional-guard.sh [check] [--live]\n' "${1-}" >&2; exit 2 ;;
esac
LIVE=0
for a in "$@"; do
  case "$a" in
    --live) LIVE=1 ;;
    *) printf 'error: unknown option %s\nhelp: app-functional-guard.sh [check] [--live]\n' "$a" >&2; exit 2 ;;
  esac
done

findings=0
printf 'app-functional-guard[3]{check,status,finding}:\n'

# ── 1. every app server entry parses ─────────────────────────────────────────
if ! command -v bun >/dev/null 2>&1; then
  printf '  "parses","SKIP","bun is not installed — a clean skip, never a false pass"\n'
else
  mapfile -t servers < <(find "$ROOT/apps" -maxdepth 3 -path '*/server/index.ts' 2>/dev/null | sort)
  if [ "${#servers[@]}" -eq 0 ]; then
    printf '  "parses","FAIL","no app server entry found under apps/*/server/index.ts"\n'
    findings=$((findings + 1))
  fi
  for s in "${servers[@]}"; do
    rel="${s#"$ROOT"/}"
    msg="$(bun -e '
      const p = process.argv[process.argv.length - 1];
      const t = await Bun.file(p).text();
      try { new Bun.Transpiler({ loader: "ts" }).transformSync(t); console.log("ok"); }
      catch (e) { console.log(String(e.message).replace(/\s+/g, " ").slice(0, 96)); }
    ' -- "$s" 2>/dev/null | tail -1)"
    if [ "$msg" = "ok" ]; then
      printf '  "parses","PASS","%s"\n' "$rel"
    else
      printf '  "parses","FAIL","%s — %s"\n' "$rel" "$msg"
      findings=$((findings + 1))
    fi
  done
fi

# ── 2. every UI call has a server route ──────────────────────────────────────
parity="$(python3 - "$ROOT" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
ui_dir, srv = root/'apps/hlidskjalf/src', root/'apps/hlidskjalf/server/index.ts'
if not ui_dir.is_dir() or not srv.is_file():
    print("SKIP|the app's UI or server is not in this tree")
    raise SystemExit(0)
text = srv.read_text()
routes = set(re.findall(r"p === '(/api/[a-z0-9/_-]+)'", text))
prefixes = [r.rstrip('/') for r in re.findall(r"p\.startsWith\('(/api/[a-z0-9/_-]+)'\)", text)]
calls = set()
for f in ui_dir.rglob('*'):
    if f.suffix not in {'.ts', '.tsx', '.js', '.jsx'}:
        continue
    try:
        t = f.read_text()
    except Exception:
        continue
    calls |= set(re.findall(r"['\"`](/api/[a-z0-9/_-]+)['\"`]", t))
missing = sorted(c for c in calls
                 if c not in routes and not any(c.startswith(p + '/') or c == p for p in prefixes))
if missing:
    for m in missing:
        print(f"FAIL|{m} — the UI calls this route and the server does not answer it")
else:
    print(f"PASS|{len(calls)} UI call(s), every one answered by the server")
PY
)"
while IFS='|' read -r st why; do
  [ -n "$st" ] || continue
  printf '  "routes","%s","%s"\n' "$st" "$why"
  [ "$st" = "FAIL" ] && findings=$((findings + 1))
done <<<"$parity"

# ── 3. --live: a running gate answers without a 5xx ──────────────────────────
if [ "$LIVE" = 1 ]; then
  port="${HLIDSKJALF_API_PORT:-3889}"
  code="$(curl -s -m 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/api/health" 2>/dev/null)"
  case "$code" in
    200|401) printf '  "live","PASS","gate on :%s answers %s"\n' "$port" "$code" ;;
    000)     printf '  "live","SKIP","no gate listening on :%s — start it with scripts/start.sh"\n' "$port" ;;
    *)       printf '  "live","FAIL","gate on :%s answered %s (a 5xx is a dead app)"\n' "$port" "$code"
             findings=$((findings + 1)) ;;
  esac
else
  printf '  "live","SKIP","not asked (pass --live to probe a running gate)"\n'
fi

if [ "$findings" -eq 0 ]; then
  exit 0
fi
printf 'app-functional-guard: %s finding(s)\nhelp: fix the app before shipping it — a syntax error or a missing route is a dead control plane, and the user finds it first\n' "$findings" >&2
exit 1
