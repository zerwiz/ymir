#!/usr/bin/env bash
# connect.sh — THE connect door: one button to a signed-in mailbox, and the honest line per account.
#
# Plan 221 (`svartalfaheim/<realm>/projects/ymir/plans/221-the-connect-door.md`, §4 and §5).
# The complaint this answers: "it is way way too complicated for new users to set up their email and
# google calendar". A user presses one button and signs in; the operator carries Google ONCE (one Cloud
# project, consent screen Internal, one OAuth client marked agentic) and every user ends up with a
# grant of their own, written to their own vault by KEY. A guest types three fields and their mail
# works the same afternoon.
#
#   connect.sh google [--account ADDR] [--port N] [--no-browser] [--timeout S]
#       the one sign-in: consent URL → loopback redirect → code exchanged → the refresh token
#       written to the vault BY KEY → proved with one GET /users/me/profile:
#       `account <address> · grant live · expires <t>`
#
#   connect.sh google --check [--account ADDR]
#       the boot check. A dead grant prints `grant dead: <reason>` — never an empty inbox.
#       Exit 1 when an account is dead, 3 when none is declared.
#
#   connect.sh imap --address ADDR [--host H] [--port N] [--tls ssl|starttls|none]
#                   [--mailbox INBOX] [--password-stdin]
#       the guest road: address + app password, proved by a REAL LOGIN and a REAL EXAMINE.
#       The password is read on stdin (or a prompt), stored by KEY, never echoed, never in argv.
#
#   connect.sh status [--account ADDR] [--offline]
#       per account: readable · sendable · deliverable. Deliverable is the register's own
#       measurement (bin/mail/addresses.sh) — this door does not re-invent DNS.
#
#   connect.sh revoke <account>
#       revocation as a VERB: the vault key goes dark and the door says what stopped working.
#
#   connect.sh --self-test
#       every claim above, offline, against fixtures on loopback.
#
# LAW. This door cannot send. Sending happens only at
# `systems/snotra/services/letters/mail-send.sh`, where the operator's word is bound to the exact
# RFC822 bytes of the letter (plan 221 §4). A route that cannot show those bytes is refused, however
# easy it is. And no secret is ever printed or written into this repo: the vault holds KEY=value and
# this file names keys.
#
# Exit: 0 the verb's measurement passed · 1 the measurement FAILED (a dead grant, a refused login)
#       · 2 usage · 3 not configured yet (the client is not in the vault, no account declared).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# The ONE resolver (Rule 07): env → the recorded choice → the one documented default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
fi
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || {
  printf 'connect[1]{state,detail}:\n  "unreadable","the home is unresolved — bin/vault/hoard-lib.sh"\n' >&2
  exit 2
}
export YMIR_HOME="$HOME_R"
export YMIR_TREE="${YMIR_TREE:-$ROOT}"

PY="$(command -v python3 || echo /usr/bin/python3)"
DOOR="$HERE/gna_connect.py"

case "${1:-}" in
  -h|--help|help|"")
    sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'
    [ -n "${1:-}" ] && exit 0 || exit 2 ;;
  -v|--version) exec "$PY" "$DOOR" --version ;;
esac

exec "$PY" "$DOOR" "$@"
