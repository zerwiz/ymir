#!/usr/bin/env bash
# nornir-status.sh — every Nornir job judged on the seat that owns it (plan 365).
#   nornir-status.sh [--json] [--no-ssh]     exit 1 when anything needs the Allfather
# TOON on stdout; the house cloth (ymir-style.sh marks and colours) on stderr when a person is watching.
HERE="$(CDPATH='' command cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out=$(python3 "$HERE/nornir-status.py" "$@"); rc=$?
printf '%s\n' "$out"
case " $* " in *" --json "*) exit "$rc" ;; esac
if [ -t 2 ] || [ "${YMIR_PRETTY:-}" = 1 ]; then
  # shellcheck disable=SC1091
  . "$HERE/../desktop/ymir-style.sh" 2>/dev/null && style_init 2>/dev/null
  printf '%s\n' "$out" | python3 -c '
import sys, json
for l in sys.stdin:
    if l.startswith("  \""):
        print("\t".join(json.loads("[" + l.strip() + "]")))' | while IFS=$'\t' read -r st owner at job detail nxt; do
    case "$st" in RAN|MOVED) s=ok ;; ELSEWHERE|DUE|IDLE) s=info ;; *) s=fail ;; esac
    style_line "$s" "$st" "$at ${job##*/} — $detail${nxt:+ → $nxt}"
  done
fi
exit "$rc"
