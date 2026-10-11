#!/usr/bin/env bash
# cron-guard.sh — the shipped tree must satisfy its own schedule.
#
# The Nornir scheduler runs every job from the REPO root (`home=$ROOT`), so in a
# cron line `bin/x.sh` ALWAYS means `<repo>/bin/x.sh`. Schedules differ per user
# and per seat — times, roles, which jobs — but the COMMANDS must resolve to a
# script that SHIPS in this repo. A line naming a script that lives only in the
# operator's home (or nowhere) is a job no other seat, and no fresh user, can run.
# This ward refuses it, and it is the same law the cron header already states
# ("every path must be a REPO-relative command (bin/…)").
#
#   cron-guard.sh            # check the effective cron and the shipped example
#   cron-guard.sh --all      # same
#   cron-guard.sh --version
#
# Exit: 0 every referenced script ships · 1 a reference is missing · 2 usage.
set -u
VERSION="1.0.0"

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}
ROOT="$(_root)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check|--all) ;;
  "") ;;
  *) printf 'error: unknown action %s\nhelp: cron-guard.sh [check|--all]\n' "${1-}" >&2; exit 2 ;;
esac

# The effective cron is the operator's (home) when it exists, plus the shipped
# example. The home is resolved through hoard-lib (Rule 07), never guessed.
_home=""
[ -r "$ROOT/bin/vault/hoard-lib.sh" ] && . "$ROOT/bin/vault/hoard-lib.sh"
command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root _home

CRONS=()
if [ -n "${YMIR_CRON_FILE:-}" ]; then CRONS+=("$YMIR_CRON_FILE"); fi
[ -n "$_home" ] && [ -f "$_home/config/cron.yaml" ] && CRONS+=("$_home/config/cron.yaml")
[ -f "$ROOT/config/cron.yaml" ] && CRONS+=("$ROOT/config/cron.yaml")
[ -f "$ROOT/config/cron.yaml.example" ] && CRONS+=("$ROOT/config/cron.yaml.example")

missing=0; seen=""
printf 'cron-guard[3]{finding,source,script}:\n'
for f in ${CRONS[@]+"${CRONS[@]}"}; do
  [ -r "$f" ] || continue
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case " $seen " in *" $ref "*) continue ;; esac
    seen="$seen $ref"
    [ -e "$ROOT/$ref" ] && continue
    case "$f" in "$ROOT"/*) src="${f#"$ROOT"/}" ;; *) src="$f" ;; esac
    printf '  "a cron job names a script that does not ship","%s","%s"\n' "$src" "$ref"
    missing=$((missing + 1))
  done < <(grep -vE '^[[:space:]]*#' "$f" 2>/dev/null | grep -oE 'bin/[A-Za-z0-9_./-]+\.sh' | sort -u)
done
if [ "$missing" -eq 0 ]; then
  printf '  "none","","every referenced script ships in the repo"\n'
  exit 0
fi
printf 'cron-guard: %s referenced script(s) do not ship in the repo\nhelp: jobs run from the REPO root, so bin/… always means the repo — a script kept only in a home cannot resolve; move it into the repo (bin/…) or reference it absolutely where the runner allows it\n' "$missing" >&2
exit 1
