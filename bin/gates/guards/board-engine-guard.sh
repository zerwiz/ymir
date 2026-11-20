#!/usr/bin/env bash
# board-engine-guard.sh — a NEW file in Ymir may not carry one board engine's code (plan 335, the split).
#
# Ymir is public and is installed by people with GitHub, Trello or Jira and no Gimlé. So Ymir keeps the board
# CONTRACT (bin/boards/: the verbs, the card shape, the state groups, the adapters) and this house's own suite —
# Gimlé, and Plane behind it — lives in its own repository (zerwiz/gimle). On 2026-11-20 the Plane door, the desk,
# the whiteboard services and the Plane halves of bin/collab left with their history. This ward stops them
# growing back. A new file is refused when it names:
#
#   · Plane's API            /api/v1/workspaces/ · PLANE_API_TOKEN · PLANE_API_BASE · plane_reader · plane-selfhost
#   · the old Gimlé tree     bin/gimle/
#   · a Gimlé host           a name in the operator's own list (`config/gimle-hosts.txt` in the home, one per
#                            line) — the list stays in the home, and the ward prints which ENTRY matched, never
#                            the word (RULES/04)
#
# Existing files are not judged (RULES/02 and the fix notes must keep their record); only the spread is refused.
#
#   bin/gates/guards/board-engine-guard.sh                 the staged change; with nothing staged, what HEAD adds
#                                                          over origin/main (how guards.sh and CI call it)
#   bin/gates/guards/board-engine-guard.sh --range A..B    the files a range adds
#   bin/gates/guards/board-engine-guard.sh --repo <dir>    run against another tree
#
# Not judged: docs/fixes/ (append-only record) · RULES/ (append-only law) · this ward and its test.
# A single line may be waived in writing with `board-engine-ok:` and a reason on the same line.
#
# Exit 0 clean · 1 a new file names a board engine · 2 usage.
set -u

REPO="."
MODE=auto RANGE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)   REPO="${2:?--repo needs a directory}"; shift 2 ;;
    --range)  MODE=range; RANGE="${2:?--range needs A..B}"; shift 2 ;;
    --staged) MODE=staged; shift ;;
    check)    shift ;;   # guards.sh hands every ward `check`; the default mode is the right one
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { printf 'board-engine-guard: %s is not a git tree\n' "$REPO" >&2; exit 2; }

ENGINE='/api/v1/workspaces/|PLANE_API_(TOKEN|BASE)|plane_reader|plane-selfhost|bin/gimle/'

exempt() {
  case "$1" in
    docs/fixes/*|RULES/*) return 0 ;;
    bin/gates/guards/board-engine-guard.sh|bin/gates/tests/test_board_engine_guard.sh) return 0 ;;
  esac
  return 1
}

# the operator's Gimlé hosts, from the home — never written in this repository
HOSTS=()
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
home="${YMIR_HOME:-}"
if [ -z "$home" ] && [ -r "$here/../../vault/hoard-lib.sh" ]; then
  . "$here/../../vault/hoard-lib.sh" 2>/dev/null || true
  declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root home 2>/dev/null || true
fi
list="${YMIR_GIMLE_HOSTS_FILE:-${home:+$home/config/gimle-hosts.txt}}"
if [ -n "$list" ] && [ -r "$list" ]; then
  while IFS= read -r h; do
    h="${h%%#*}"; h="${h//[[:space:]]/}"
    [ -n "$h" ] && HOSTS+=("$h")
  done <"$list"
fi

if [ "$MODE" = auto ]; then
  if [ -n "$(git -C "$REPO" diff --cached --name-only --diff-filter=A 2>/dev/null)" ]; then
    MODE=staged
  else
    for b in origin/main origin/master; do
      git -C "$REPO" rev-parse -q --verify "$b" >/dev/null 2>&1 && { MODE=range; RANGE="$b..HEAD"; break; }
    done
    [ "$MODE" = auto ] && MODE=staged
  fi
fi

if [ "$MODE" = range ]; then
  files="$(git -C "$REPO" diff --name-only --diff-filter=A "$RANGE" 2>/dev/null)"
  show() { git -C "$REPO" show "${RANGE##*..}:$1" 2>/dev/null; }
else
  files="$(git -C "$REPO" diff --cached --name-only --diff-filter=A 2>/dev/null)"
  show() { git -C "$REPO" show ":$1" 2>/dev/null; }
fi

hits=0 n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  exempt "$f" && continue
  case "$f" in *.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip|*.gz|*.db|*.woff*|*.ttf|*.ico) continue ;; esac
  n=$((n + 1))
  body="$(show "$f" | tr -d '\000')"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in *board-engine-ok:*) continue ;; esac
    printf 'board-engine-guard: %s:%s names a board engine — %s\n' "$f" "${line%%:*}" \
      "$(printf '%s' "${line#*:}" | grep -oE "$ENGINE" | head -1)"
    hits=$((hits + 1))
  done < <(printf '%s\n' "$body" | grep -nE "$ENGINE")
  i=0
  for h in "${HOSTS[@]+"${HOSTS[@]}"}"; do
    i=$((i + 1))
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      case "$line" in *board-engine-ok:*) continue ;; esac
      printf 'board-engine-guard: %s:%s names a Gimlé host — entry %s of the home list\n' "$f" "${line%%:*}" "$i"
      hits=$((hits + 1))
    done < <(printf '%s\n' "$body" | grep -nF -- "$h")
  done
done <<<"$files"

if [ "$hits" -gt 0 ]; then
  printf '\nboard-engine-guard: BLOCKED — %s line(s) in new files carry a board engine into Ymir (plan 335).\n' "$hits" >&2
  printf '  Ymir speaks the board contract (bin/boards/, the mcp adapter); Plane and Gimlé live in zerwiz/gimle.\n' >&2
  printf '  Put the engine code there, and reach it here through the project'"'"'s board: block in the registry.\n' >&2
  printf '  A line that must stay: board-engine-ok: <why>\n' >&2
  exit 1
fi
printf 'board-engine-guard: clean — %s new file(s) judged, %s home host(s) armed\n' "$n" "${#HOSTS[@]}"
exit 0
