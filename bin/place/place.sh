#!/usr/bin/env bash
# place.sh — team PLACES: a wall, not a permission (Rule 18; plan 77 Part 10).
#
# A teammate is a MEMBER OF PLACES, not a user with permissions on a server. Outside their
# places a member sees NOTHING — no files, no names, no listings, no counts. So a place is
# not a folder with an ACL; it is a bounded space with its OWN storage root, its own tools,
# and its own members.
#
# A place IS a realm (Svartalfaheim), so it inherits the realm boundary law, which is
# already sacred: never touch another realm without explicit approval.
#
#   place.sh create <name> [--member <id>]… [--owner <id>]   # mint a place
#   place.sh list                                            # the operator's view: every place
#   place.sh show <name>                                     # one place: members, tools, class
#   place.sh members <name>                                  # who belongs
#   place.sh check [<name>]                                  # PROVE the wall: roots are inside, no escapes
#
# Configuration is resolved from the operator's home (Rule 07). A place never contains a
# path into the hoard, and the hoard is never listed from a place.
set -u

VERSION="0.1.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; [ -n "${1-}" ] && exit 0 || exit 0 ;;
esac
ACTION="${1-}"; shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -d .pi ] || [ ! -d RULES ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi
HOME_ROOT="${YMIR_HOME:-}"; command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_ROOT
HOME_ROOT="${HOME_ROOT:-$HOME/Documents/ymirhome}"
# places are REALMS — they live where realms live
PLACES_DIR="${YMIR_PLACES_DIR:-$HOME_ROOT/svartalfaheim}"

die() { printf 'place: %s\n' "$*" >&2; exit 1; }
valid_name() { case "$1" in ''|*/*|.|..) return 1 ;; esac; case "$1" in *[!a-z0-9_-]*) return 1 ;; esac; return 0; }
place_dir() { printf '%s/%s' "$PLACES_DIR" "$1"; }

case "$ACTION" in
  create)
    NAME="${1-}"; shift || true
    valid_name "$NAME" || die "a place name is lowercase letters, digits, '-' or '_' (got '${NAME}')"
    D="$(place_dir "$NAME")"
    [ -e "$D" ] && die "place '$NAME' already exists at $D"
    OWNER=""; MEMBERS=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --owner) OWNER="${2-}"; shift 2 ;;
        --member) MEMBERS="$MEMBERS${MEMBERS:+ }${2-}"; shift 2 ;;
        *) die "unknown flag '$1'" ;;
      esac
    done
    mkdir -p "$D/files" "$D/record" "$D/room" "$D/board"
    # the wall: the place's OWN roots. Nothing here points out, and nothing outside points in
    # as a mutable path — a place never contains a path into the hoard.
    {
      printf '# A team PLACE (Rule 18; plan 77 Part 10). It is a REALM: members only, seen by nobody else.\n'
      printf 'name: "%s"\n' "$NAME"
      printf 'class: "team"\n'
      printf 'owner: "%s"\n' "${OWNER:-}"
      printf 'members:\n'
      if [ -n "$MEMBERS" ]; then for m in $MEMBERS; do printf '  - "%s"\n' "$m"; done; else printf '  []\n'; fi
      printf 'tools:\n  room: "%s"\n  board: "%s"\n  files: "%s"\n  record: "%s"\n' "$D/room" "$D/board" "$D/files" "$D/record"
      printf 'note: "outside their places a member sees nothing — not even a list"\n'
    } > "$D/place.yaml"
    printf 'place[4]{fact,value}:\n'
    printf '  "created","%s"\n' "$NAME"
    printf '  "root","%s"\n' "$D"
    printf '  "class","team (a realm — Rule 18)"\n'
    printf '  "members","%s"\n' "${MEMBERS:-none yet}"
    ;;
  list)
    # the OPERATOR's view — the operator may see every place; a member's view is built from
    # membership alone (never a directory listing of the whole tree).
    n=0
    printf 'places['
    if [ -d "$PLACES_DIR" ]; then
      for d in "$PLACES_DIR"/*/; do [ -f "$d/place.yaml" ] && n=$((n + 1)); done
    fi
    printf '%s]{place,members,owner}:\n' "$n"
    if [ "$n" = 0 ]; then printf '  "none","",""\n'; else
      for d in "$PLACES_DIR"/*/; do
        [ -f "$d/place.yaml" ] || continue
        python3 - "$d/place.yaml" <<'PY'
import sys, re
txt = open(sys.argv[1]).read()
name = re.search(r'^name:\s*"?(.*?)"?\s*$', txt, re.M)
owner = re.search(r'^owner:\s*"?(.*?)"?\s*$', txt, re.M)
mems = re.findall(r'^\s+-\s+"(.*?)"\s*$', txt, re.M)
print('  "%s","%s","%s"' % ((name.group(1) if name else '?'), len([m for m in mems if m]), (owner.group(1) if owner else '')))
PY
      done
    fi
    ;;
  show|members)
    NAME="${1-}"; valid_name "$NAME" || die "which place?"
    D="$(place_dir "$NAME")"; [ -f "$D/place.yaml" ] || die "no place '$NAME'"
    if [ "$ACTION" = show ]; then printf 'place-show[2]{fact,value}:\n  "name","%s"\n  "root","%s"\n' "$NAME" "$D"; fi
    python3 - "$D/place.yaml" <<'PY'
import sys, re
txt = open(sys.argv[1]).read()
mems = [m for m in re.findall(r'^\s+-\s+"(.*?)"\s*$', txt, re.M) if m]
print('members[%d]{id}:' % len(mems))
for m in mems:
    print('  "%s"' % m)
if not mems:
    print('  "none yet"')
PY
    ;;
  check)
    # PROVE the wall. The failure this catches: a place whose storage is a symlink out, or a
    # path that reaches the hoard — the exact thing "never our private files" forbids.
    NAME="${1-}"; bad=0
    scan() {
      local d="$1"
      for p in "$d"/*; do
        [ -e "$p" ] || continue
        if [ -L "$p" ]; then
          local t; t="$(readlink -f "$p" 2>/dev/null || true)"
          case "$t" in
            "$d"/*|"$PLACES_DIR"/*) : ;;
            *) printf '  "escape","%s -> %s"\n' "$p" "$t"; bad=$((bad + 1)) ;;
          esac
        fi
        [ -d "$p" ] && [ ! -L "$p" ] && scan "$p"
      done
    }
    dirs=(); if [ -n "$NAME" ]; then dirs=("$(place_dir "$NAME")"); else for d in "$PLACES_DIR"/*/; do [ -f "$d/place.yaml" ] && dirs+=("$d"); done; fi
    for d in "${dirs[@]}"; do [ -d "$d" ] || continue; scan "$d"; done
    printf 'place-wall[3]{fact,result}:\n'
    printf '  "checked","%s"\n' "${NAME:-every place}"
    printf '  "escapes","%s"\n' "$bad"
    printf '  "verdict","%s"\n' "$([ "$bad" = 0 ] && echo 'the wall holds — no path leaves its place' || echo 'ESCAPES FOUND — a member could see outside')"
    [ "$bad" = 0 ] || exit 1
    ;;
  *) die "unknown action '${ACTION}' — create | list | show | members | check" ;;
esac
