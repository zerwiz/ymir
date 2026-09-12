#!/usr/bin/env bash
# hodd.sh — the Allfather's private hoard: path, init, ls, load, tenant.
#
#   bin/hodd.sh path                 # the Hoard root
#   bin/hodd.sh init                 # create the layout
#   bin/hodd.sh ls                   # what the Hoard holds (names, not contents)
#   bin/hodd.sh load secrets/platform.env   # source a hoard env (quoted, safely)
#   eval "$(bin/hodd.sh emit secrets/platform.env)"   # set them in YOUR shell
#   bin/hodd.sh tenant josef         # source a tenant's .env (that tenant only)
#
# Secrets are REFERENCED by path (YMIR_HOARD, default <repo>/hodd) — never inlined.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOARD="${YMIR_HOARD:-$ROOT/hodd}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-path}"; shift || true

# Source a KEY=value file with proper quoting, so values containing spaces
# survive (a plain `source` silently drops those lines).
load_env() {
  local f=$1 tmp
  [ -r "$f" ] || { printf 'error: not readable: %s\n' "$f" >&2; return 1; }
  tmp="$(mktemp)"
  python3 - "$f" >"$tmp" <<'PY'
import re, shlex, sys
for line in open(sys.argv[1]):
    m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$', line.rstrip("\n"))
    if m:
        print(f"export {m.group(1)}={shlex.quote(m.group(2))}")
PY
  set -a; . "$tmp"; set +a
  rm -f "$tmp"
  printf 'hodd[1]{action,file}:\n  "load","%s"\n' "$f"
}

case "$ACTION" in
  path)  printf '%s\n' "$HOARD" ;;
  init)
    mkdir -p "$HOARD"/{secrets,docs,tenants,identity} || exit 1
    printf 'hodd[1]{action,path}:\n  "init","%s"\n' "$HOARD" ;;
  ls)
    printf 'hodd[4]{section,path,files}:\n'
    for d in secrets docs tenants identity; do
      n="$(find "$HOARD/$d" -type f 2>/dev/null | wc -l | tr -d ' ')"
      printf '  "%s","%s",%s\n' "$d" "$HOARD/$d" "$n"
    done ;;
  load)
    f="${1:-}"; [ -n "$f" ] || { printf 'error: load needs a path under the Hoard\n' >&2; exit 2; }
    case "$f" in /*) ;; *) f="$HOARD/$f" ;; esac
    load_env "$f" ;;
  emit)
    # Print `export KEY=value` lines (quoting-safe) for the CALLER to eval, so
    # `eval "$(bin/hodd.sh emit <file>)"` sets the vars in the invoking shell.
    f="${1:-}"; [ -n "$f" ] || { printf 'error: emit needs a path under the Hoard\n' >&2; exit 2; }
    case "$f" in /*) ;; *) f="$HOARD/$f" ;; esac
    [ -r "$f" ] || { printf 'error: not readable: %s\n' "$f" >&2; exit 1; }
    python3 - "$f" <<'PY'
import re, shlex, sys
for line in open(sys.argv[1]):
    m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$', line.rstrip("\n"))
    if m:
        print(f"export {m.group(1)}={shlex.quote(m.group(2))}")
PY
    ;;
  tenant)
    t="${1:-}"; [ -n "$t" ] || { printf 'error: tenant needs a name\n' >&2; exit 2; }
    load_env "$HOARD/tenants/$t/.env" ;;
  *) printf 'error: unknown action %s\nhelp: bin/hodd.sh [path|init|ls|load|emit|tenant]\n' "$ACTION" >&2; exit 2 ;;
esac
