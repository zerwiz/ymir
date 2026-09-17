#!/usr/bin/env bash
# design-check.sh — one identity, two renderers: they must agree.
#
# The design language is the landing page's cloth (stone · bone · bronze ·
# blood). It is carried in TWO places, on purpose:
#
#   midgard/design-system/tokens.css     the CSS variables every web surface imports
#   apps/sessrumnir/…/themes/fensalir.json   the seven SEEDS the seat derives ~40
#                                            tokens from (the reference form)
#
# Two carriers of one identity drift the moment someone edits one. This is the
# guard: the same value must appear in both, or the build says so.
#
# Usage:
#   bin/design-check.sh          # compare, TOON, exit 0/1
#   bin/design-check.sh --fix-hint
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Where an app lives: apps/<surface> in a clone, node_modules/@zerwiz/<pkg> in an
# npm install — both shapes, one resolver (bin/app-lib.sh).
if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  _ya="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yac in "$_ya/app-lib.sh" "$(dirname "$_ya")/bin/app-lib.sh"; do
    [ -r "$_yac" ] && { . "$_yac"; YMIR_APP_LIB_LOADED=1; break; }
  done
  unset _ya _yac
fi
app_dir sessrumnir APP_SESSRUMNIR || APP_SESSRUMNIR=""

TOKENS="$ROOT/midgard/design-system/tokens.css"
SEEDS="$APP_SESSRUMNIR/src/renderer/src/themes/fensalir.json"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

[ -r "$TOKENS" ] || { printf 'error: tokens not found: %s\n' "${TOKENS#"$ROOT"/}" >&2; exit 1; }
# The seat's cloth lives in the Sessrúmnir app repo (the apps split moved it out
# of the monorepo; `step_apps` clones it). In a fresh clone or a worktree it is
# absent until that step runs — so an absent seat is a clean SKIP, not a failure.
# Two carriers can only be compared when both are present; demanding the app's
# file would fail every worktree for a reason that is not drift.
if [ ! -r "$SEEDS" ]; then
  printf 'design[1]{state,reason}:\n'
  printf '  "SKIP","the seat'"'"'s cloth is app-provided (%s) — run bin/ymir-install.sh step_apps"\n' "${SEEDS#"$ROOT"/}"
  exit 0
fi

# the pairs that MUST agree: CSS token <-> seed
python3 - "$TOKENS" "$SEEDS" <<'PY'
import json, re, sys

tokens_path, seeds_path = sys.argv[1], sys.argv[2]
css = open(tokens_path).read()
seeds = json.load(open(seeds_path))["seeds"]

def token(name):
    m = re.search(r"--%s:\s*([^;]+);" % re.escape(name), css)
    return m.group(1).strip() if m else None

PAIRS = [
    ("ymir-bg-0",     "app",     "the ground"),
    ("ymir-bg-1",     "surface", "the panel"),
    ("ymir-text-0",   "text",    "the bone"),
    ("ymir-cyan-1",   "accent",  "the bronze"),
    ("ymir-ok",       "success", "the metal proved true"),
    ("ymir-warn",     "warning", "hot, heed it"),
    ("ymir-danger",   "error",   "the wound"),
]

bad = []
print("design[%d]{css_token,seed,value,agreement}:" % len(PAIRS))
for tok, seed, label in PAIRS:
    a, b = token(tok), (seeds.get(seed) or "").lower()
    ok = a is not None and a.lower() == b
    if not ok:
        bad.append((tok, seed, a, b))
    print('  "%s","%s","%s","%s"' % (tok, seed, a or "-", "ok" if ok else "MISMATCH (seed %s)" % (b or "-")))

if bad:
    print("error: the two carriers of the cloth disagree", file=sys.stderr)
    for tok, seed, a, b in bad:
        print("  --%s = %s   ≠   seeds.%s = %s" % (tok, a, seed, b), file=sys.stderr)
    print("help: change the value in midgard/design-system/tokens.css AND fensalir.json, or neither", file=sys.stderr)
    sys.exit(1)
print("design-check: the cloth is one — %d pairs agree" % len(PAIRS))
PY
