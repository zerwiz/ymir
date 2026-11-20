#!/usr/bin/env bash
# addresses.sh — THE register of the mail addresses the house uses, and whether mail can reach them.
#
# WHY THIS DOOR EXISTS (plan 116 §15.3.1): on 2026-10-24 zerwiz.org published no MX
# record at all, so gimle@, snotra@, reply+* and bounce+* were undeliverable — while five
# documents assumed mail arrived, and the desk showed an empty inbox. A house address that
# cannot receive is reported `undeliverable` here; nothing is assumed good.
#
#   addresses.sh              the register, TOON (address · domain · mx · route · arrived · state)
#   addresses.sh --check      exit nonzero when a declared address cannot receive
#   addresses.sh --honesty    the desk's line, per address: deliverable · forwarded · unreadable
#   addresses.sh --domain D   one domain's MX, measured
#   addresses.sh --aliases    re-measure the Workspace aliases (read-only sendAs), one row each
#   addresses.sh --self-test  the proofs, offline, with a fixture resolver on loopback
#
# Registered addresses and their declared routing live in ONE place: the home's
# hodd/memory/mail/accounts.yaml, under `house:` (Rule 04 — the registry is the home's,
# never this repo's).
#
# Exit: 0 every address deliverable · 1 an address is undeliverable (or its DNS could
#       not be read) · 2 the register itself could not be read · 3 all reachable but
#       unproven (a routed address with no arrival proof yet — `unproven` is not `good`).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# The ONE resolver (Rule 07): env -> the recorded choice -> the one documented default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
fi
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'addresses[1]{state,detail}:\n  "unreadable","the home is unresolved — bin/vault/hoard-lib.sh"\n' >&2; exit 2; }
export YMIR_HOME="$HOME_R"

PY="$(command -v python3 || echo /usr/bin/python3)"
DOOR="$HERE/gna_addresses.py"

ACTION=list
case "${1:-}" in
  ""|list) ACTION=list ;;
  --check|check) ACTION=check ;;
  --honesty|honesty) ACTION=honesty ;;
  --aliases|aliases) ACTION=aliases ;;
  --self-test|--test) ACTION=self-test ;;
  --domain) ACTION=domain; DOMAIN="${2-}" ;;
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'addresses: unknown option %s\n' "$1" >&2; exit 2 ;;
esac

case "$ACTION" in
  self-test) exec "$PY" "$DOOR" --self-test ;;
  domain)
    [ -n "${DOMAIN-}" ] || { printf 'addresses: --domain needs a domain\n' >&2; exit 2; }
    exec "$PY" "$DOOR" probe --domain "$DOMAIN" ;;
  honesty) exec "$PY" "$DOOR" honesty ;;
  aliases) exec "$PY" "$DOOR" aliases ;;
  check) exec "$PY" "$DOOR" check ;;
  *) exec "$PY" "$DOOR" list ;;
esac
