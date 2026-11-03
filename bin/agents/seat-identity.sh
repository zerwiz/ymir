#!/usr/bin/env bash
# seat-identity.sh — print a seat's primary agent and its role file.
#
# Usage:
#   seat-identity.sh <host>                # the primary agent name
#   seat-identity.sh <host> --file         # the role file path
#   seat-identity.sh <host> --json         # machine-readable
#   seat-identity.sh --list                # every seat and its primary
#
# The roster lives in $YMIR_HOME/hodd/identity/seats.yaml.
# This door reads it; it does not hardcode a name (Rule 07).
set -euo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh"; do [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }; done; unset _c
fi
ymir_home_root YMIR_HOME 2>/dev/null || true
YMIR_HOME="${YMIR_HOME:?YMIR_HOME unresolved}"
ROSTER="${SEAT_ROSTER:-$YMIR_HOME/hodd/identity/seats.yaml}"
[ -r "$ROSTER" ] || { printf 'error: roster not readable: %s\n' "$ROSTER" >&2; exit 1; }

# Windows hostname does not support -s. Do not shorten a Windows computer name.
SELF="${YMIR_HOST:-}"
if [ -z "$SELF" ]; then
  SELF="$(hostname)"
  case "${OSTYPE:-}" in msys*|cygwin*) ;; *) SELF="${SELF%%.*}" ;; esac
fi
# Probe the interpreter, including its required module; Windows Store aliases
# may exist on PATH without being executable. An explicit override fails closed.
if [ -n "${YMIR_PYTHON:-}" ]; then
  "$YMIR_PYTHON" -c 'import yaml' || exit 1
else
  for candidate in python3 python; do
    if "$candidate" -c 'import yaml' >/dev/null 2>&1; then YMIR_PYTHON="$candidate"; break; fi
  done
  [ -n "${YMIR_PYTHON:-}" ] || { printf 'error: Python with PyYAML is required\n' >&2; exit 1; }
fi
python3(){ command "$YMIR_PYTHON" "$@"; }
export YMIR_PYTHON
HOST="${1-}"; MODE="name"
case "$HOST" in
  --list) MODE="list"; HOST="" ;;
  --file|--json|--install|--check|--render|--ensure) MODE="${HOST#--}"; HOST="${2:-$SELF}" ;;
  set) MODE="set"; HOST="${2:-$SELF}"; NEWNAME="${3-}"; NEWROLE="${4-}" ;;
  names|--names) MODE="names"; HOST="" ;;
esac

if [ "$MODE" = names ]; then
  # The naming law is the source: a seat's primary must be a figure with a role file.
  for f in "$ROOT"/.agents/agents/*.md; do
    n="$(basename "$f" .md)"
    case "$n" in *-*) n="${n%%-*}" ;; esac
    printf '%s\n' "$n"
  done | sort -u
  exit 0
fi

if [ "$MODE" = set ]; then
  [ -n "${NEWNAME:-}" ] || { printf 'error: set needs <host> <name> [role]\n' >&2; exit 2; }
  # Collisions belong to the registry, not to this door: it knows every name
  # across subsystems, hosts, agents, skills and extensions.
  if [ -x "$ROOT/bin/agents/name-registry.sh" ] && [ -r "$YMIR_HOME/hodd/identity/names.yaml" ]; then
    if ! bash "$ROOT/bin/agents/name-registry.sh" check "$NEWNAME" --as seat-persona; then
      printf 'help: name-registry.sh list --kind agent\n' >&2; exit 3
    fi
  fi
  if ! bash "$0" --names | grep -qxF "$NEWNAME"; then
    if [ "${YMIR_ALLOW_UNKNOWN_NAME:-0}" != 1 ]; then
      printf 'refused\t"%s" is not a name in the naming law\n' "$NEWNAME" >&2
      printf 'help: seat-identity.sh --names   (or YMIR_ALLOW_UNKNOWN_NAME=1 to override)\n' >&2
      exit 3
    fi
  fi
  python3 - "$ROSTER" "$HOST" "$NEWNAME" "${NEWROLE:-}" <<'PY'
import sys
try: import yaml
except Exception: raise SystemExit("error: PyYAML is required")
roster,host,name,role=sys.argv[1:]
d=yaml.safe_load(open(roster)) or {}
seats=d.setdefault("seats",{})
cur=seats.get(host,{})
seats[host]={"primary":name,"role":role or cur.get("role",""),"status":"sealed",
             "why":cur.get("why","chosen by the operator")}
open(roster,'w').write(yaml.safe_dump(d,sort_keys=False))
print(f"sealed\t{host}\t{name}")
PY
  CARD="$YMIR_HOME/hodd/data/agent-cards/$HOST.json"
  if [ -f "$CARD" ]; then python3 - "$CARD" "$HOST" "$NEWNAME" <<'PY'
import json,sys
p,host,name=sys.argv[1:]
d=json.load(open(p)); d["name"]=f"{name}-{host}"; d["seat_primary"]=name
json.dump(d,open(p,"w"),indent=2)
PY
  fi
  bash "$0" --install "$HOST"; exit 0
fi

if [ "$MODE" = ensure ]; then
  if bash "$0" "$HOST" >/dev/null 2>&1; then bash "$0" --install "$HOST"; exit 0; fi
  if [ -n "${YMIR_SEAT_NAME:-}" ]; then
    python3 - "$ROSTER" "$HOST" "$YMIR_SEAT_NAME" <<'PY'
import sys,yaml
roster,host,name=sys.argv[1:]
try: d=yaml.safe_load(open(roster)) or {}
except Exception: d={}
d.setdefault("seats",{})[host]={"primary":name,"role":"","status":"sealed","why":"chosen at install"}
open(roster,'w').write(yaml.safe_dump(d,sort_keys=False))
PY
    bash "$0" --install "$HOST"; exit 0
  fi
  if [ -t 0 ]; then
    printf 'This host is %s. Name its primary agent: ' "$HOST" >&2
    read -r nm
    [ -n "$nm" ] || { printf 'error: no name given\n' >&2; exit 1; }
    exec bash "$0" set "$HOST" "$nm"
  fi
  printf 'error: no primary recorded for %s — run: seat-identity.sh set %s <name>\n' "$HOST" "$HOST" >&2
  exit 1
fi

if [ "$MODE" = install ] && [ "$HOST" != "$SELF" ]; then
  printf 'skipped\t%s is not this host\n' "$HOST"; exit 0
fi
if [ "$MODE" = install ] || [ "$MODE" = check ] || [ "$MODE" = render ]; then
  NAME="$(bash "$0" "$HOST" 2>/dev/null)" || { printf 'error: %s has no seat identity\n' "$HOST" >&2; exit 1; }
  ROLE="$(python3 -c 'import yaml,sys;d=yaml.safe_load(open(sys.argv[1]));print(d["seats"][sys.argv[2]].get("role",""))' "$ROSTER" "$HOST")"
  STATUS="$(python3 -c 'import yaml,sys;d=yaml.safe_load(open(sys.argv[1]));print(d["seats"][sys.argv[2]].get("status","proposed"))' "$ROSTER" "$HOST")"
  RF="$(bash "$0" --file "$HOST")"
  SEAT_FILE="$HOME/.pi/agent/extensions/.ymir-seat"
  RENDER="$HOME/.pi/agent/AGENTS.seat.md"
  case "$MODE" in
    install)
      mkdir -p "$(dirname "$SEAT_FILE")"
      printf 'host=%s\nprimary=%s\nrole=%s\nstatus=%s\nrole_file=%s\nroster=%s\n' "$HOST" "$NAME" "$ROLE" "$STATUS" "$RF" "$ROSTER" > "$SEAT_FILE"
      printf 'installed\t%s\t%s\t%s\n' "$SEAT_FILE" "$HOST" "$NAME" ;;
    render)
      cat > "$RENDER" <<EOF
<!-- generated by bin/agents/seat-identity.sh — do not edit -->
# This seat: $HOST

You are **$NAME** on **$HOST** — $ROLE. Your role file is \`$RF\`.
Seat names are proposed until the Allfather seals them in
\`hodd/identity/seats.md\`; the roster is \`$ROSTER\`.

# The shared contract

EOF
      cat "$ROOT/AGENTS.md" >> "$RENDER"
      printf 'rendered\t%s\n' "$RENDER" ;;
    check)
      [ -r "$SEAT_FILE" ] || { printf 'missing\t%s\n' "$SEAT_FILE"; exit 1; }
      want="$(printf 'host=%s\nprimary=%s\n' "$HOST" "$NAME")"
      have="$(printf 'host=%s\nprimary=%s\n' "$(sed -n 's/^host=//p' "$SEAT_FILE")" "$(sed -n 's/^primary=//p' "$SEAT_FILE")")"
      installed_rf="$(sed -n 's/^role_file=//p' "$SEAT_FILE")"
      if [ "$want" = "$have" ] && [ "$installed_rf" = "$RF" ] && [ -r "$installed_rf" ]; then printf 'ok\t%s\t%s\n' "$HOST" "$NAME"; else printf 'mismatch\t%s\t%s\n' "$SEAT_FILE" "$have"; exit 1; fi ;;
  esac
  exit 0
fi

export SEAT_CODE_ROOT="$ROOT"
case "${OSTYPE:-}" in
  msys*|cygwin*)
    SEAT_CODE_ROOT="$(cygpath -m "$ROOT")"
    export YMIR_HOME="$(cygpath -m "$YMIR_HOME")" ;;
esac
python3 - "$ROSTER" "$HOST" "$MODE" <<'PY'
import sys, json, os
try: import yaml
except Exception: yaml=None
roster,host,mode=sys.argv[1],sys.argv[2],sys.argv[3]
cfg=yaml.safe_load(open(roster).read()) if yaml else {}
seats=cfg.get("seats",{}) if isinstance(cfg,dict) else {}
if mode=="list":
    for s in sorted(seats):
        i=seats[s]; print(f"{s}\t{i.get('primary')}\t{i.get('status','proposed')}")
    sys.exit(0)
if host not in seats:
    print(f"error: no seat named {host!r} in {roster}", file=sys.stderr)
    sys.exit(1)
name=seats[host].get("primary")
if mode=="name": print(name)
elif mode=="file":
    # Private profiles override distro profiles. Never install a missing role.
    import pathlib
    root=pathlib.Path(os.environ["SEAT_CODE_ROOT"])
    private=pathlib.Path(os.environ["YMIR_HOME"])/".agents"/"agents"/(name+".md")
    aliases={"brokk":"brokk.md","sindri":"sindri-developer.md","muninn":"muninn-stow.md","mimir":"mimir-planner.md"}
    public=root/".agents"/"agents"/aliases.get(name,name+".md")
    selected=private if private.is_file() else public
    if not selected.is_file() or not os.access(selected, os.R_OK): raise SystemExit("error: no readable role profile for seat primary")
    print(selected.as_posix())
elif mode=="json":
    print(json.dumps({"host":host, **seats[host]}, indent=2))
PY
