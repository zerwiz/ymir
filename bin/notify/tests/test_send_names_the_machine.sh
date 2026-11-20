#!/usr/bin/env bash
# test_send_names_the_machine.sh — every alarm line says WHICH MACHINE raised it.
#
# WHY (2026-11-20). At the operator's word: "Make alarm lines name the machine they came from — starting with the
# cron notifier and the garmr and skirnir senders — so a dev machine's failure does not read as the heart's."
# Measured that evening: a burst of cron failures from two DEV machines arrived in the same chat as the heart's,
# indistinguishable, and read as one machine falling apart. Every one of those senders goes through this one door,
# so the tag belongs here, once.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/notify/send.sh"
pass=0; fail=0
t() { local n="$1"; shift; if "$@"; then printf '  ok   %s\n' "$n"; pass=$((pass+1)); else printf '  FAIL %s\n' "$n"; fail=$((fail+1)); fi; }
ok() { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; fail=$((fail+1)); }

here="$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')"
line_for() { timeout 60 bash "$DOOR" --source "$1" --severity HIGH --message "$2" --print-line 2>&1; }

for src in cron garmr assistant; do
  out="$(line_for "$src" "job failed (rc=1): bin/x.sh")"
  case "$out" in "[$here · $src/HIGH] "*) ok "a $src line names this machine first" ;;
                *) bad "a $src line names this machine first" "$out" ;; esac
done

named() { [ "$(YMIR_NOTIFY_HOST=host-a line_for cron msg)" = "[host-a · cron/HIGH] msg" ]; }
t "a relay may name the machine it speaks for (YMIR_NOTIFY_HOST)"   named
keeps_message() { case "$(line_for cron 'a message with · a separator')" in *"a message with · a separator") ok "the message survives whole" ;; *) bad "the message survives whole" "" ;; esac; }
t "the message after the tag is untouched"                          keeps_message

printf 'send-names-the-machine: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
