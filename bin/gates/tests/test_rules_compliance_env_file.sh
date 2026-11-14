#!/usr/bin/env bash
# test_rules_compliance_env_file.sh — the ward tells a filename from a hostname.
#
# WHY (plan 275 item 22, 2026-11-14): RULES/39's ward refuses an internal address or an mDNS
# name in a line a push ADDS. Its pattern for an mDNS host is a token ending in that suffix — so the
# house's own env file, `$YMIR_HOME/.env.local`, was read as a host called `.env` and every
# new document that named it was refused. A ward that refuses the house's own documented
# filename is a ward the next hand must override, and a routinely overridden ward is one
# nobody trusts.
#
# The three claims:
#   1. a new line naming `$YMIR_HOME/.env.local` is CLEAN;
#   2. a new line naming a real mDNS host is still REFUSED (also assembled at run time: a
#      test that asserts the ward catches an address must not carry one in the public tree);
#   3. a new line naming a private LAN address is still REFUSED (the address is assembled
#      at run time: this tree is public and carries no private address as a literal).
#
# Usage: test_rules_compliance_env_file.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
GUARD="$ROOT/bin/gates/guards/rules-compliance-guard.sh"

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

printf 'rules-compliance — a filename is not a hostname\n'

# a throwaway repo carrying the guard at its own path (the guard locates its root from there)
mkdir -p "$T/repo/bin/gates/guards" "$T/repo/docs/fixes/probe"
cp "$GUARD" "$T/repo/bin/gates/guards/rules-compliance-guard.sh"
git -C "$T/repo" init -q -b main
git -C "$T/repo" config user.email t@example.test
git -C "$T/repo" config user.name t
printf 'base\n' > "$T/repo/readme.txt"
git -C "$T/repo" add readme.txt && git -C "$T/repo" commit -qm base
git -C "$T/repo" update-ref refs/remotes/origin/main HEAD
# the guard itself is not part of the judged range
git -C "$T/repo" add -A >/dev/null 2>&1; git -C "$T/repo" commit -qm guard >/dev/null 2>&1 || true
git -C "$T/repo" update-ref refs/remotes/origin/main HEAD

probe() {  # <file> <line> — adds one document and returns the guard's exit code
  local f="$1" line="$2" out rc
  printf '%s\n' "$line" > "$T/repo/docs/fixes/probe/$f.md"
  git -C "$T/repo" add "docs/fixes/probe/$f.md" >/dev/null
  git -C "$T/repo" commit -qm "add $f" >/dev/null
  out="$(cd "$T/repo" && bash bin/gates/guards/rules-compliance-guard.sh check origin/main HEAD 2>&1)"; rc=$?
  printf '%s' "$out" > "$T/out"  # the finding, for the failure message
  echo "$rc"
}

rc="$(probe envfile 'the key lives in `$YMIR_HOME/.env.local` for a fresh install')"
[ "$rc" = 0 ] && ok "the house's own env file name is clean" || bad "the env file name is clean" "$(cat "$T/out")"

MDNS="printer.""local"
rc="$(probe mdns "the door answers at $MDNS on this network")"
[ "$rc" = 1 ] && grep -q 'probe/mdns.md' "$T/out" && ok "a real mDNS host is still refused" || bad "an mDNS host is refused" "$(cat "$T/out")"

LAN="192.168.$(printf '%s' '1').10"
rc="$(probe lan "the service listens on $LAN for the room")"
[ "$rc" = 1 ] && grep -q 'probe/lan.md' "$T/out" && ok "a private LAN address is still refused" || bad "a LAN address is refused" "$(cat "$T/out")"

printf 'rules-compliance env file: %s ok / %s fail\n' "$pass" "$fail"
[ "$fail" = 0 ]
