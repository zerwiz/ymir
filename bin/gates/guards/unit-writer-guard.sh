#!/usr/bin/env bash
# unit-writer-guard.sh — no script writes a systemd user unit without handing it to the register (plan 272, fault 12).
#
# Plan 269 made `bin/engine/units.sh` (the register, config/units.yaml) the ONE writer of units. A script that still
# renders its own unit — `cat > …/systemd/user/x.service`, `cp … systemd/user/`, `tee …/systemd/user/…` — must settle
# the result through it (`unit_settle`, from bin/engine/unit-settle-lib.sh, or a call to units.sh itself), or an old or
# stray checkout re-points a pinned unit and nothing says so: on a collaborator's seat an old `garmr.sh` did exactly
# that to `garmr-brain`.
#
# A script that must write a unit with no register entry (it is not a Ymir tree unit) is named in
# config/unit-writers-allow.txt, one `path<TAB>reason` per line; an entry with no reason is ignored.
#
#   unit-writer-guard.sh [check]
# Exit: 0 every writer settles through the register (or is allowed, with a reason) · 1 one does not.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
case "${1:-check}" in
  check) ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'error: unknown command %s\nhelp: unit-writer-guard.sh [check]\n' "$1" >&2; exit 2 ;;
esac
ALLOW="$ROOT/config/unit-writers-allow.txt"
allowed() {  # <path> → 0 when allowed with a reason
  [ -r "$ALLOW" ] || return 1
  awk -F'\t' -v p="$1" '$1==p && length($2)>0 {found=1} END{exit found?0:1}' "$ALLOW"
}
bad=0; n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in bin/gates/*|bin/engine/unit-settle-lib.sh|bin/engine/units.*|docs/*|*.md) continue ;; esac
  # a write to a unit path: a redirect, a cp/install/tee, or a sed output redirected there
  grep -qE '(>|>>|tee( -a)?|cp( -f| -p)*|install( -m [0-7]+)?)[^|;&#]*systemd/user/[A-Za-z0-9_.${}@-]+\.(service|timer|path|socket)' "$ROOT/$f" 2>/dev/null || continue
  n=$((n+1))
  if grep -qE 'unit_settle|engine/units\.sh|units\.sh write' "$ROOT/$f" 2>/dev/null; then continue; fi
  if allowed "$f"; then continue; fi
  printf 'unit-writer[1]{file,finding}:\n  "%s","writes a systemd user unit and does not settle it through the register (unit_settle / units.sh) — an old checkout can re-point it"\n' "$f"
  bad=1
done < <(git -C "$ROOT" ls-files -- '*.sh' 2>/dev/null)
if [ "$bad" = 0 ]; then
  printf 'unit-writer-guard[1]{state,writers}:\n  "clean","%s script(s) write units and each settles through the register or is allowed with a reason"\n' "$n"
fi
exit "$bad"
