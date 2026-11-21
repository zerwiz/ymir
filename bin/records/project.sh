#!/usr/bin/env bash
# project.sh — how is this project handled? One door to the `handling:` block of the project registry (plan 345).
#
#   project.sh <id>                    the row's handling block: visibility, plans, board, people, private_to,
#                                      delivery, deploy, secrets (names only) — every value with its source
#   project.sh <id> --field delivery   one field; dotted paths walk in (delivery.road, visibility.value)
#   project.sh <id> --field f --json   the same, as JSON
#   project.sh --list                  id · visibility · plans · who merges, one line per row
#   project.sh --audit [--quiet]       rows without visibility / plans / delivery, and every schema finding; exit 1 on any
#   project.sh --page                  the Markdown page for people (one table, a column per question)
#
#   --registry PATH   read another registry (a fixture, a second home); YMIR_PROJECTS_REGISTRY does the same
#
# The registry is the home's own (`$YMIR_HOME/hodd/identity/projects.yaml`), resolved by bin/vault/hoard-lib.sh,
# never assumed (RULES/07). The shape is config/projects.schema.json. A value nobody could measure reads
# `unmeasured`; a value only the operator may give reads `OWED`.
set -uo pipefail
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT="$(cd "$_DIR/../.." && pwd)"
case " $* " in *" --registry "*) ;; *)
  if [ -z "${YMIR_PROJECTS_REGISTRY:-}" ] && [ -z "${YMIR_HOME:-}" ] && [ -r "$_ROOT/bin/vault/hoard-lib.sh" ]; then
    . "$_ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
    if command -v ymir_home_root >/dev/null 2>&1; then _h=""; ymir_home_root _h; [ -n "$_h" ] && export YMIR_HOME="$_h"; fi
  fi
  if [ -z "${YMIR_PROJECTS_REGISTRY:-}" ] && [ -z "${YMIR_HOME:-}" ]; then
    case " $* " in *" -h "*|*" --help "*) ;; *)
      printf 'project.sh: the home could not be resolved (bin/vault/hoard-lib.sh, RULES/07); pass --registry PATH\n' >&2; exit 2 ;;
    esac
  fi ;;
esac
exec python3 "$_DIR/project_registry.py" "$@"
