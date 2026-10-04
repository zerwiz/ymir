#!/usr/bin/env bash
# wyrd-db.sh — the database layer (W0040). Applies the platform schema and reports
# its state via psql. The input is `midgard/infrastructure/db/schema.sql`; files
# stay the raw record, this is the queryable mirror. Galdr-style TOON.
#
# Usage:
#   wyrd-db.sh status
#   wyrd-db.sh apply
#   wyrd-db.sh psql [args...]
#   wyrd-db.sh --version
#
# Env: DATABASE_URL (postgres://user:pass@host:port/db). Absent → uses psql defaults.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEMA="$ROOT/midgard/infrastructure/db/schema.sql"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
command -v psql >/dev/null 2>&1 || { printf 'error: psql not installed\nhelp: install the postgres client\n' >&2; exit 1; }
[ -f "$SCHEMA" ] || { printf 'error: schema missing: %s\n' "$SCHEMA" >&2; exit 1; }
PSQL=(psql -v ON_ERROR_STOP=1)
[ -n "${DATABASE_URL:-}" ] && PSQL=("${PSQL[@]}" "$DATABASE_URL")

CMD="${1-}"; shift || true
case "$CMD" in
  apply)
    if "${PSQL[@]}" -q -f "$SCHEMA" >/dev/null 2>&1; then
      printf 'wyrd[1]{schema,status}:\n  "midgard/infrastructure/db/schema.sql","applied"\n'
    else
      printf 'error: schema apply failed\nhelp: check DATABASE_URL and that Postgres is reachable (docker-compose up postgres)\n' >&2
      exit 1
    fi
    ;;
  status)
    n=$("${PSQL[@]}" -tAc "select count(*) from information_schema.tables where table_schema='public'" 2>/dev/null) || { printf 'wyrd[1]{db,status}:\n  "%s","unreachable"\n' "${DATABASE_URL:-psql-default}"; exit 1; }
    printf 'wyrd[1]{db,tables,status}:\n  "%s",%s,"up"\n' "${DATABASE_URL:-psql-default}" "$n"
    ;;
  psql)
    exec "${PSQL[@]}" "$@"
    ;;
  *) printf 'error: unknown command %s\nhelp: bin/wyrd-db.sh [status|apply|psql|--version]\n' "$CMD" >&2; exit 2 ;;
esac
