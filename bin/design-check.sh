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
TOKENS="$ROOT/midgard/design-system/tokens.css"
SEEDS="$ROOT/apps/sessrumnir/src/renderer/src/themes/fensalir.json"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

[ -r "$TOKENS" ] || { printf 'error: tokens not found: %s\n' "${TOKENS#"$ROOT"/}" >&2; exit 1; }
[ -r "$SEEDS" ]  || { printf 'error: the seat'"'"'s cloth not found: %s\n' "${SEEDS#"$ROOT"/}" >&2; exit 1; }

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
