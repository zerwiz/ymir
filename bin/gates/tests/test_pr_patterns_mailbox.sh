#!/usr/bin/env bash
# test_pr_patterns_mailbox.sh — a MAILBOX is an address, a ROLE TOKEN is not.
#
# Why this test exists: on 2026-11-20 a pull request was refused by pr-identity-guard because its
# body quoted a scheduled row — "The Nornir row `@dev 03:05 …`" — and the mailbox pattern read
# `[^space]+@[^space]+`, so `@dev` looked like somebody's address. The ward must refuse a published
# address and must NOT refuse the schedule the house writes down; both halves are asserted here.
#
#   bin/gates/tests/test_pr_patterns_mailbox.sh
#
# Exit: 0 both halves hold · 1 a case failed (each printed by name).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=bin/forge/pr-patterns.sh
. "$ROOT/bin/forge/pr-patterns.sh"

rc=0
ok() { printf '  ok   %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; rc=1; }

clean() {  # clean <text> — the ward must say nothing
  local got; got="$(pr_pattern_check_line "$1")"
  if [ -z "$got" ]; then ok "clean: $1"; else bad "clean: $1 — the ward said \"$got\""; fi
}
flagged() {  # flagged <text> <expected label>
  local got; got="$(pr_pattern_check_line "$1")"
  if [ "${got%% (*}" = "$2" ]; then ok "flagged $2: $1"; else bad "flagged $2: $1 — the ward said \"${got:-nothing}\""; fi
}

printf 'a role token is not a mailbox\n'
clean 'The Nornir row `@dev 03:05 …` runs before the brief'
clean '@heart carries the brief at 07:00'
clean 'the schedule names @dev, @heart and @forge, never a person'
clean 'noreply from users.noreply.github.com (a GitHub account, allowed)'
clean 'a cron line at 03:05 with no address at all'

printf 'an address still is\n'
flagged 'write to ada@example.org about it' mailbox
flagged 'Test Person <someone@example.org>' mailbox
flagged 'a@b.c' mailbox
flagged 'first.last+tag@sub.example.org' mailbox
flagged 'mixed: users.noreply.github.com and ada@example.org' mailbox

printf 'the other patterns still bite\n'
flagged 'the pane was w12:p1 that night' paneid
flagged 'the host answered 192.0.2.7' ipv4

printf 'the whole door, not one line\n'
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
printf 'The Nornir row `@dev 03:05 …` runs before the brief\n' >"$tmp"
if out="$(pr_pattern_match "$tmp")"; then bad "pr_pattern_match refused a cron role token: $out"
else ok 'pr_pattern_match passes a body that quotes @dev'; fi
printf 'thanks, write to ada@example.org\n' >"$tmp"
out="$(pr_pattern_match "$tmp")" || true
case "$out" in mailbox:*) ok 'pr_pattern_match refuses a real address' ;; *) bad "pr_pattern_match said \"${out:-nothing}\" for an address" ;; esac

[ "$rc" = 0 ] && printf 'all cases hold\n'
exit "$rc"
