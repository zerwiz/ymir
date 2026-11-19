#!/usr/bin/env bash
# test_ssh_keys_no_needless_chmod.sh — the key sync must not chmod a file that is already right.
#
# WHY (2026-11-20). `~/.ssh/authorized_keys` is watched by the house's own audit rule
# (`-w … -p wa -k ymir-identity`), and the sync runs on a fifteen-minute timer. An unconditional
# `chmod 600` therefore raised an identity alert every quarter hour, all night, on the operator's
# phone — fifteen findings in one evening. The mode is now set only when it is wrong, so a real change
# still reaches the watch and an unchanged file says nothing.
#
# The proof is the file's own ctime: run once, run again unchanged, and the second run must not touch it.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
S="$ROOT/bin/host/heimdall-ssh-keys.sh"
pass=0; fail=0
t() { local n="$1"; shift; if "$@"; then printf '  ok   %s\n' "$n"; pass=$((pass+1)); else printf '  FAIL %s\n' "$n"; fail=$((fail+1)); fi; }

[ -x "$S" ] || { echo "  FAIL no door at $S"; exit 1; }
command -v ssh-keygen >/dev/null 2>&1 || { echo "  SKIP ssh-keygen is not on this machine"; exit 0; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HEIMDALL_KEYS_FILE="$T/ssh/authorized_keys"
mkdir -p "$T/ssh"
ssh-keygen -qt ed25519 -N '' -f "$T/k" >/dev/null 2>&1
KEY="$(cat "$T/k.pub")"
: >"$HEIMDALL_KEYS_FILE"; chmod 666 "$HEIMDALL_KEYS_FILE"

bash "$S" add --key "$KEY" >/dev/null 2>&1
wrong_mode_fixed() { [ "$(stat -c %a "$HEIMDALL_KEYS_FILE" 2>/dev/null)" = "600" ]; }
t "a file with the wrong mode is set to 600"                      wrong_mode_fixed

ctime1="$(stat -c %Z "$HEIMDALL_KEYS_FILE")"; sleep 1.1
bash "$S" add --key "$KEY" >/dev/null 2>&1
untouched() { [ "$(stat -c %Z "$HEIMDALL_KEYS_FILE")" = "$ctime1" ]; }
t "a second run that changes nothing does not chmod or write"      untouched
still_600() { [ "$(stat -c %a "$HEIMDALL_KEYS_FILE")" = "600" ]; }
t "the mode is still 600 afterwards"                              still_600

# a mode that IS wrong is still repaired — the conditional is not a swallow
chmod 644 "$HEIMDALL_KEYS_FILE"; sleep 1.1
bash "$S" add --key "$KEY" >/dev/null 2>&1
repairs_again() { [ "$(stat -c %a "$HEIMDALL_KEYS_FILE")" = "600" ]; }
t "a mode that drifts is repaired on the next run"                 repairs_again

printf 'heimdall-ssh-keys: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
