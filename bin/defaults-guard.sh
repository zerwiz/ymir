#!/usr/bin/env bash
# defaults-guard.sh — ONE PLACE KNOWS WHERE THINGS LIVE.
#
# A lock, not a wish. Ten scripts once carried their own home default; the tenth was
# found by hand a week later, which is the whole argument for this ward. There is one
# resolver (`bin/hoard-lib.sh`) and one default, and no other file may restate them.
#
# It reads CODE, not prose: a runbook may quote a path, an executable may not guess
# one. A line may be waived in writing with `allow-home-default:` and a reason, which
# turns an accident into a decision.
#
# Usage:
#   defaults-guard.sh check [path...]   # the ward (default: bin/ and .agents/)
#   defaults-guard.sh --version
#
# Exit: 0 clean · 1 a finding · 2 usage.
set -u

VERSION="1.0.0"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check) shift ;;
  "") set -- check ;;
  *) printf 'error: unknown action %s\nhelp: defaults-guard.sh [check] [path...]\n' "${1-}" >&2; exit 2 ;;
esac

# The ONE definition site. Everything else must call it.
ALLOWLIST="bin/hoard-lib.sh bin/defaults-guard.sh"

# A home guessed, a second root, or a synced-home name. Written as parts so this
# ward does not fire on itself.
PAT="\\\$HOME/Doc""uments/|/home/[A-Za-z0-9_.-]+/Doc""uments/|Doc""uments/ymirhome|/opt/ym""ir|/home/bu""n"

TARGETS=("$@")
[ "${#TARGETS[@]}" -gt 0 ] || TARGETS=("$ROOT/bin" "$ROOT/.agents")

findings=0
printf 'defaults-guard[3]{finding,file,line,text}:\n'
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file="${hit%%:*}"; rest="${hit#*:}"; line="${rest%%:*}"
  rel="${file#"$ROOT"/}"
  skip=0
  for a in $ALLOWLIST; do [ "$rel" = "$a" ] && skip=1; done
  [ "$skip" = 1 ] && continue
  text="${rest#*:}"
  case "$text" in *allow-home-default:*) continue ;; esac
  printf '  "a home guessed","%s","%s","%s"\n' "$rel" "$line" "$(printf '%s' "$text" | cut -c1-72)"
  findings=$((findings + 1))
done < <(grep -rnE "$PAT" "${TARGETS[@]}" 2>/dev/null \
           --include='*.sh' --include='*.bash' --include='*.py' --include='*.js' \
           --include='*.mjs' --include='*.cjs' --include='*.ts' \
           --exclude-dir=node_modules --exclude-dir=.git || true)

if [ "$findings" -eq 0 ]; then
  printf '  "none","","","every path resolves through the one resolver"\n'
  exit 0
fi
printf 'defaults-guard: %s finding(s)\nhelp: call the resolver (bin/hoard-lib.sh); never restate where things live\n' "$findings" >&2
exit 1
