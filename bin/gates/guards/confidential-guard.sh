#!/usr/bin/env bash
# confidential-guard.sh — while a confidential session is live, nothing outside the
# vault may be committed (Rule 16).
#
# A confidential session confines work to the vault. This ward is the wall: if the
# session marker is live, it refuses to commit any staged file whose path is not
# inside the vault mount. Installed as a pre-commit hook in the repo and the home, so
# no tool can write vault work out by committing it.
#
#   confidential-guard.sh            # scan the staged change (pre-commit)
#   confidential-guard.sh --all      # scan every tracked file
#
# Exit: 0 no session, or every file is inside the vault · 1 a file is outside · 2 usage.
set -u
VERSION="1.0.0"

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}
ROOT="$(_root)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check|--all|"") ;;
  *) printf 'error: unknown action %s\nhelp: confidential-guard.sh [check|--all]\n' "${1-}" >&2; exit 2 ;;
esac

_home=""
[ -r "$ROOT/bin/vault/hoard-lib.sh" ] && . "$ROOT/bin/vault/hoard-lib.sh"
command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root _home
STATE="${YMIR_STATE_DIR:-${_home:-$HOME}/state}"
MARKER="$STATE/confidential.session"

printf 'confidential-guard[3]{finding,file,mount}:\n'
[ -f "$MARKER" ] || { printf '  "none","","no confidential session is live"\n'; exit 0; }
mount="$(sed -n 's/^mount=//p' "$MARKER" | head -1)"
[ -n "$mount" ] || { printf '  "none","","no confidential session is live"\n'; exit 0; }

cwd="$(pwd -P)"
if [ "${1-}" = "--all" ]; then files="$(git ls-files 2>/dev/null)"; else files="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)"; fi

found=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in /*) abs="$f" ;; *) abs="$cwd/$f" ;; esac
  case "$abs" in "$mount"/*) continue ;; esac
  printf '  "a file outside the vault is staged in a confidential session","%s","%s"\n' "$f" "$mount"
  found=$((found + 1))
done <<< "$files"

if [ "$found" -eq 0 ]; then
  printf '  "none","","a confidential session is live; every staged file is inside the vault"\n'
  exit 0
fi
printf 'confidential-guard: %s file(s) outside the vault are staged while a confidential session is live\nhelp: vault work stays in the vault (Rule 16) — commit it there, or close the session with: bin/vault/confidential.sh stop\n' "$found" >&2
exit 1
