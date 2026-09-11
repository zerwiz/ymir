#!/usr/bin/env bash
# smidja-bootstrap.sh — make the Smíðja visualizer ready on a fresh install.
#
# The visualizer reads `smidja/smidja_data/smidja.db`. On a fresh install that
# file does not exist yet, so the visualizer has nothing to show. This creates
# the DB (via the tracer's own schema — the single owner of the format) and
# seeds one bootstrap session, so the Sessions/Trace/Stats views are live from
# the very first install. Idempotent: an existing DB is left untouched.
#
# Usage:
#   bin/smidja-bootstrap.sh [--check] [--db <path>]
#   bin/smidja-bootstrap.sh --version
#
# Output: Galdr TOON. Exit 0 when the DB exists afterwards, 1 on failure.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB="${SMIDJA_DB:-$ROOT/smidja/smidja_data/smidja.db}"
CHECK=0

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --db) DB=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/smidja-bootstrap.sh [--check] [--db <path>]\n' "$1" >&2; exit 2 ;;
  esac
done

if [ "$CHECK" = 1 ]; then
  if [ -f "$DB" ]; then
    printf 'smidja-db[1]{state,db}:\n  "present","%s"\n' "$DB"
  else
    printf 'smidja-db[1]{state,db}:\n  "absent","%s"\n' "$DB"
  fi
  exit 0
fi

if [ -f "$DB" ]; then
  printf 'smidja-db[1]{state,db}:\n  "already present","%s"\n' "$DB"
  exit 0
fi

# Create the schema by instantiating the tracer — the format's single owner.
# Run through uv so the smidja deps (pydantic etc.) resolve without a system install.
PY=""
for c in python3; do command -v "$c" >/dev/null 2>&1 && PY="$c"; done
[ -n "$PY" ] || { printf 'error: python3 not found\n' >&2; exit 1; }

mkdir -p "$(dirname "$DB")" "$ROOT/smidja/smidja_data/sessions/bootstrap"

if command -v uv >/dev/null 2>&1; then
  ( cd "$ROOT" && SMIDJA_BS_DB="$DB" uv run --quiet \
      --with pydantic --with pyyaml --with python-dotenv --with rich -- \
      python3 -c '
import os, sys
from pathlib import Path
sys.path.insert(0, str(Path.cwd() / "smidja"))
from smidja_modules.tracer import Tracer
db = os.environ["SMIDJA_BS_DB"]
events = str(Path(db).parent / "sessions" / "bootstrap" / "events.jsonl")
t = Tracer(db, events)
t.session_start("bootstrap", "install", smidja_name="ymir-install")
t.session_finish("bootstrap", ok=True)
' )
else
  printf 'error: uv not found (needed to create the smidja schema)\nhelp: bin/prereq-ensure.sh uv\n' >&2
  exit 1
fi

if [ -f "$DB" ]; then
  printf 'smidja-db[1]{state,db}:\n  "created","%s"\n' "$DB"
  exit 0
fi
printf 'error: could not create the smidja db at %s\n' "$DB" >&2
exit 1
