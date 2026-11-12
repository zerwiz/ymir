#!/usr/bin/env bash
# test_heimdall_named_user.sh — Heimdall admits only the GitHub user the operator names (2026-11-12).
#
# Before this fix, `heimdall-ensure.sh ensure` always ran `add zerwiz`, and with no user recorded it
# took the owner of the checkout's remote. On a collaborator's machine either path wrote the upstream
# owner's SSH keys into authorized_keys and kept them fresh every 15 minutes.
#
#   · no user named            → refuses to arm: exit 1, no ward copied, no keys written
#   · no built-in user         → the script names no GitHub user of its own
#   · no remote inference      → the remote's owner is never read
#   · no silent download       → the ward is copied from this tree unless HEIMDALL_DISTRO_URL is set
#
# Runs in a throwaway HOME; nothing on the machine is touched. Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
ENSURE="$ROOT/bin/host/heimdall-ensure.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-heimdall.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

# 1. no user named → refuse, write nothing
out="$(HOME="$TMP" XDG_CONFIG_HOME="$TMP/cfg" HEIMDALL_WARD_DEST="$TMP/ward.sh" HEIMDALL_GH_USERS='' \
       bash "$ENSURE" ensure 2>&1)"; rc=$?
[ "$rc" = 1 ] && ok "no user named: ensure refuses (exit 1)" || bad "no user named: ensure exited $rc"
[ ! -e "$TMP/ward.sh" ] && ok "no user named: no ward copied" || bad "no user named: a ward was copied"
[ ! -e "$TMP/.ssh/authorized_keys" ] && ok "no user named: no keys written" || bad "no user named: keys were written"
printf '%s' "$out" | grep -q 'stays unarmed' && ok "no user named: says why" || bad "no user named: no reason given"

# 2. no built-in user: `add` is only ever called with the resolved list
if grep -nE '"\$WARD_DEST" add[^$]*--quiet [A-Za-z0-9]' "$ENSURE" >/dev/null; then
  bad "a built-in GitHub user is still added"
else
  ok "no built-in GitHub user"
fi

# 3. no remote inference
if grep -nE 'remote\.origin\.url|config --get remote' "$ENSURE" >/dev/null; then
  bad "the user is still inferred from a git remote"
else
  ok "the user is never inferred from a git remote"
fi

# 4. no silent download: the default URL is empty and the local ward exists
grep -qE '^DISTRO_URL="\$\{HEIMDALL_DISTRO_URL:-\}"' "$ENSURE" && ok "no default download URL" || bad "a default download URL remains"
[ -r "$ROOT/bin/host/heimdall-ssh-keys.sh" ] && ok "the ward ships beside the ensure script" || bad "the local ward is missing"

exit "$fail"
