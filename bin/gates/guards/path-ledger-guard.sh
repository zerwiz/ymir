#!/usr/bin/env bash
# path-ledger-guard.sh — Rule 25: a path that MOVED may not be referenced again.
#
# The fault this answers (2026-10-18): `bin/nornir-job-*.sh` became
# `bin/time/nornir-job-*.sh`; the operator's own cron kept the old spelling for three
# weeks; the scheduler read a schedule whose commands did not exist. Nothing in the tree
# objected, because nothing knew a path had moved — a path is an interface, and a moved
# interface breaks in silence.
#
# So: every move is written into `.agents/paths-ledger.yaml`, and this ward refuses a
# shipped file that still uses a superseded spelling. History is excepted — `docs/fixes/`
# (one file per fix, append-only) and the ledger itself — and a line may be waived in
# writing with `allow-superseded-path:` and a reason.
#
#   path-ledger-guard.sh check [path…]
#   path-ledger-guard.sh --list
#   path-ledger-guard.sh --version
#
# Exit: 0 clean · 1 a stale reference · 2 usage.
set -u

VERSION="1.0.0"

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.agents" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$d"
}
ROOT="${YMIR_GUARD_ROOT:-$(_root)}"
LEDGER="$ROOT/.agents/paths-ledger.yaml"
MARK="$(mktemp)"; trap 'rm -f "$MARK"' EXIT

[ -r "$LEDGER" ] || { printf 'path-ledger-guard[1]{finding,detail}:\n  "no ledger","%s"\n' "$LEDGER" >&2; exit 2; }

# old<tab>new per line, parsed without a YAML dependency (the file is a list of pairs).
pairs() {
  python3 - "$LEDGER" <<'PY'
import re, sys
old = new = None
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r'\s*-?\s*old:\s*"?([^"\n]+)"?\s*$', line)
    if m: old = m.group(1).strip()
    m = re.match(r'\s*new:\s*"?([^"\n]+)"?\s*$', line)
    if m and old:
        new = m.group(1).strip()
        print(f"{old}\t{new}")
        old = new = None
PY
}

case "${1:-check}" in
  --list) pairs | sed 's/\t/  →  /' | sed 's/^/moved: /'; exit 0 ;;
  --version) printf 'path-ledger-guard %s\n' "$VERSION"; exit 0 ;;
  check) ;;
  *) printf 'usage: path-ledger-guard.sh [check|--list|--version]\n' >&2; exit 2 ;;
esac

findings=0
say() { printf 'path-ledger-guard[1]{finding,file,line,superseded_by}:\n  "%s","%s","%s","%s"\n' "$1" "${2#"$ROOT"/}" "$3" "$4"; findings=$((findings+1)); }

# Only the surfaces a machine READS: shipped code and the assets an agent follows. The
# record is excepted — docs/fixes is one file per fix, append-only — and a line may be
# waived in writing with `allow-superseded-path:` and a reason.
SEARCH_DIRS=(bin .agents tools scripts config apps packages RULES docs)
EXCLUDES=(--exclude-dir=.git --exclude-dir=.yggdrasil --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build)
SELF="${BASH_SOURCE[0]}"

while IFS=$'\t' read -r old new; do
  [ -n "$old" ] || continue
  grep -rns "${EXCLUDES[@]}" -e "$old" "${SEARCH_DIRS[@]/#/$ROOT/}" 2>/dev/null \
  | while IFS= read -r hit; do
      file="${hit%%:*}"; rest="${hit#*:}"; line="${rest%%:*}"
      case "$file" in
        */docs/fixes/*) continue ;;
        */.agents/paths-ledger.yaml) continue ;;
        "$SELF"|*path-ledger-guard.sh) continue ;;   # the ward names the old paths on purpose
      esac
      printf '%s' "$rest" | grep -q 'allow-superseded-path:' && continue
      # If the line already carries the NEW path, the old spelling is its suffix, not a
      # reference to a moved file (bin/time/well-vault-sync.sh contains bin/well-vault-sync.sh).
      printf '%s' "$rest" | grep -qF "$new" && continue
      printf 'path-ledger-guard[1]{finding,file,superseded,line}:
  "%s","%s","%s","%s"\n' \
        "$old" "${file#"$ROOT"/}" "$new" "$(printf '%s' "$line" | cut -c1-100)"
      echo x >>"$MARK"
    done
done < <(pairs)
[ -f "$MARK" ] && findings="$(wc -l <"$MARK" | tr -d ' ')"

if [ "${findings:-0}" -eq 0 ]; then
  printf 'path-ledger-guard: clean — no shipped file references a superseded path (%s moves known)\n' "$(pairs | wc -l | tr -d ' ')"
  exit 0
fi
printf 'path-ledger-guard: %s stale reference(s)\nhelp: RULES/25 — a move is a migration: use the new path (or waive the line with allow-superseded-path: and a reason)\n' "$findings" >&2
exit 1
