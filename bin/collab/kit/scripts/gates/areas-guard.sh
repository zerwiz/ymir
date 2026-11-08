#!/usr/bin/env bash
# areas-guard — a change to an area nobody holds is refused, and the AREA is named, never the author.
#
# Called from pre-push with the range being pushed:
#   bash scripts/gates/areas-guard.sh <base-sha> <head-sha>
#
# WHAT IT REFUSES. A pushed range that changes a path inside an area's `may_write` while that area is
# `unheld` (or whose declaration is broken). The refusal names the area, the file, and the one command
# that fixes it, because a gate that prints a summary is worth less than one that prints a line.
#
# WHAT IT DELIBERATELY DOES NOT DO. It does not judge whether the evidence is good — that is a
# keeper's honesty and a reviewer's craft, not a script's. It does not require every area to be held:
# `unheld` is legal, and a repository with an empty shelf is a SKIP that says so (a skip is a pass,
# a silent green is a lie).
#
# Exit: 0 nothing to refuse (or skipped) · 1 a refusal · 2 usage.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2
base="${1:-}"; head="${2:-HEAD}"

if [ "${YMIR_SKIP_AREAS_GUARD:-0}" = "1" ]; then
  printf 'areas-guard: skipped at the operator\x27s word (YMIR_SKIP_AREAS_GUARD=1)\n'
  exit 0
fi

# never adopted → a clean skip, printed
shopt -s nullglob
decls=("$ROOT"/areas/*.yaml)
shopt -u nullglob
if [ "${#decls[@]}" -eq 0 ]; then
  printf 'areas-guard: no areas/ declarations in this repository — skipped (this is a skip, not a pass)\n'
  printf '             adopt it:  bash scripts/areas.sh init\n'
  exit 0
fi
[ -n "$base" ] || { printf 'areas-guard: no base revision to compare — skipped\n'; exit 0; }
command -v python3 >/dev/null 2>&1 || { printf 'areas-guard: no python3 — skipped, and it cannot check\n' >&2; exit 0; }

changed="$(git diff --name-only "$base..$head" 2>/dev/null || true)"
[ -n "$changed" ] || { printf 'areas-guard: nothing changed in this range\n'; exit 0; }

map="$("$ROOT/scripts/areas.sh" paths 2>/dev/null || true)"
if [ -z "$map" ]; then
  printf 'areas-guard: no area claims a folder yet — nothing to refuse\n'
  exit 0
fi

refusals=""
while IFS=$'\t' read -r area state prefix; do
  [ -n "${area:-}" ] || continue
  if [ "$state" = "broken" ]; then
    refusals="${refusals}    ${area}: the declaration cannot be read — fix areas/${area}.yaml\n"
    continue
  fi
  case "$state" in
    held|waived|na) continue ;;
  esac
  [ -n "${prefix:-}" ] || continue
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
      "$prefix"*)
        refusals="${refusals}    ${area} (${state}): ${path}\n" ;;
    esac
  done <<< "$changed"
done <<< "$map"

if [ -n "$refusals" ]; then
  printf 'areas-guard refused: this push changes work in an area nobody holds.\n\n' >&2
  printf '  area (state): file changed\n' >&2
  printf "%b" "$refusals" >&2
  printf '\nA claim with no keeper is a wish, and a change with no keeper is unowned work.\n' >&2
  printf '  take it:   bash scripts/areas.sh claim <area> --keeper "<who>" --path "<prefix>" --evidence "<artefact>"\n' >&2
  printf '  waive it:  bash scripts/areas.sh waive <area> --by "<who>" --why "<text>" --until YYYY-MM-DD\n' >&2
  printf '  or say why this push is not that area\x27s work, in the commit message, then push with --no-verify\n' >&2
  exit 1
fi

printf 'areas-guard: every changed area is held, waived or na\n'
exit 0
