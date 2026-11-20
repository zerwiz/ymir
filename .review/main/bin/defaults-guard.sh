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
  # A COMMENT is not a default. A runbook, a usage line or a header may quote a path;
  # only something that executes can guess one.
  trim="${text#"${text%%[![:space:]]*}"}"
  case "$trim" in '#'*) continue ;; esac
  printf '  "a home guessed","%s","%s","%s"\n' "$rel" "$line" "$(printf '%s' "$text" | cut -c1-72)"
  findings=$((findings + 1))
done < <(grep -rnE "$PAT" "${TARGETS[@]}" 2>/dev/null \
           --include='*.sh' --include='*.bash' --include='*.py' --include='*.js' \
           --include='*.mjs' --include='*.cjs' --include='*.ts' \
           --exclude-dir=node_modules --exclude-dir=.git || true)

if [ "$findings" -eq 0 ]; then
  printf '  "none","","","every path resolves through the one resolver"\n'
fi

# ── the second class: a script that USES the home and never RESOLVES it ───────
# The literal rule above is structurally blind to this, and that blindness cost ten
# scripts on 2026-09-24: converged to be free of any default, and left unable to run,
# because a file can be entirely literal-free and still not know where anything is.
# The resolver must actually be CALLED.
printf '\ndefaults-guard[2]{finding,file,why}:\n'
unresolved=0
while IFS= read -r f; do
  grep -qE '\$\{?YMIR_HOME' "$f" 2>/dev/null || continue
  grep -q 'ymir_home_root' "$f" 2>/dev/null && continue
  # A REAL assignment resolves it by hand and is allowed (the migrations set the old name
  # on purpose). A SELF-assignment is a no-op from the literal pass and is not an answer.
  if grep -qE '^[[:space:]]*(export[[:space:]]+)?YMIR_HOME=' "$f" 2>/dev/null \
     && ! grep -qE '^[[:space:]]*(export[[:space:]]+)?YMIR_HOME="\$\{YMIR_HOME\}"[[:space:]]*$' "$f" 2>/dev/null; then
    continue
  fi
  printf '  "uses the home, never resolves it","%s","call ymir_home_root (bin/hoard-lib.sh), or assign the home deliberately"\n' "${f#"$ROOT"/}"
  unresolved=$((unresolved + 1))
done < <(find "$ROOT/bin" "$ROOT/.agents" -type f \( -name '*.sh' -o -name '*.bash' \) \
           -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | sort)

if [ "$unresolved" -eq 0 ]; then
  printf '  "none","",""\n'
fi

if [ "$findings" -eq 0 ] && [ "$unresolved" -eq 0 ]; then
  exit 0
fi
printf 'defaults-guard: %s default(s), %s unresolved\nhelp: call the resolver (bin/hoard-lib.sh); never restate where things live, and never use the home without resolving it\n' \
  "$findings" "$unresolved" >&2
exit 1
