#!/usr/bin/env bash
# inbound-test.sh — THE acceptance test for "people can mail us" (plan 116 §15.3.4).
#
#   bin/mail/inbound-test.sh                       # test the registry's acceptance address
#   bin/mail/inbound-test.sh --to gimle@zerwiz.org  # name the address yourself
#   bin/mail/inbound-test.sh --mx-only              # ask only "could mail arrive here at all?"
#   bin/mail/inbound-test.sh --dry-run              # prepare the message, send nothing
#   bin/mail/inbound-test.sh --self-test            # the door's proofs, offline
#
# WHAT IT DOES, IN ORDER — and why the order matters:
#   1. ASK FIRST. A test that sends into a domain with no MX proves nothing and looks
#      like a pass. `plan` measures the domain's MX, checks the declared route, and
#      checks that a Workspace alias exists when the address is one (§16). If any is
#      missing the test SKIPS WITH A REASON, naming exactly what is missing.
#   2. SEND FROM OUTSIDE, through the house's existing approved send door
#      (systems/snotra/services/letters/mail-send.sh — the Gmail grant). A sender on the target's own
#      domain proves nothing about outside mail; the door refuses that unless
#      --allow-same-domain, and says so.
#   3. WAIT AND ASSERT. The arrival is searched for by the To: header, and the header
#      is kept VERBATIM: "did it arrive still addressed to the address we used" is the
#      whole question. The proof is appended to
#      $YMIR_HOME/hodd/state/mail/inbound-arrivals.jsonl, which
#      bin/mail/addresses.sh reads — so `deliverable` is something a machine measured,
#      never something a document promised.
#
# EXIT: 0 arrived and proven · 1 sent but no arrival (a real failure: MX exists, so the
#       route is broken) · 2 usage or an unreadable register · 3 SKIP-WITH-REASON.
#
# Test hook: GNA_INBOUND_SEND_CMD replaces the send door (the proofs use it). Nothing
# in production sets it. No host, port or credential is written here: the send door
# resolves them from the vault, and the register resolves addresses from the home.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'inbound-test[1]{state,detail}:\n  "unreadable","the home is unresolved — bin/vault/hoard-lib.sh"\n' >&2; exit 2; }
export YMIR_HOME="$HOME_R"

PY="$(command -v python3 || echo /usr/bin/python3)"
DOOR="$HERE/gna_addresses.py"
SEND_CMD="${GNA_INBOUND_SEND_CMD:-$ROOT/systems/snotra/services/letters/mail-send.sh}"
WAIT="${GNA_INBOUND_WAIT:-300}"

TO=""; FROM=""; MX_ONLY=0; DRY=0; SAME=0; SELFTEST=0
while [ $# -gt 0 ]; do case "$1" in
  --to) TO="${2-}"; shift 2 ;;
  --from) FROM="${2-}"; shift 2 ;;
  --wait) WAIT="${2-}"; shift 2 ;;
  --allow-same-domain) SAME=1; shift ;;
  --mx-only) MX_ONLY=1; shift ;;
  --dry-run) DRY=1; shift ;;
  --self-test) SELFTEST=1; shift ;;
  -h|--help) sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'inbound-test: unknown option %s\n' "$1" >&2; exit 2 ;;
esac; done

if [ "$SELFTEST" = 1 ]; then
  exec "$PY" "$HERE/tests/test_gna.py" InboundDoor InboundChain
fi

PLAN_ARGS=(--to "$TO")
[ -n "$FROM" ] && PLAN_ARGS+=(--sender "$FROM")
[ "$SAME" = 1 ] && PLAN_ARGS+=(--allow-same-domain)

# 1 · ASK FIRST. The plan is the door's own verdict, so the skip and the send can never
# disagree about whether the address can receive.
if ! PLAN="$("$PY" "$DOOR" plan "${PLAN_ARGS[@]}" --json)"; then
  "$PY" "$DOOR" plan "${PLAN_ARGS[@]}"
  exit 3
fi
if [ "$MX_ONLY" = 1 ]; then
  "$PY" "$DOOR" plan "${PLAN_ARGS[@]}"
  exit 0
fi

read_out() { printf '%s' "$PLAN" | "$PY" -c "import json,sys;print(json.load(sys.stdin).get('$1') or '')"; }
TARGET="$(read_out target)"
SENDER="$(read_out sender)"
[ -n "$TARGET" ] && [ -n "$SENDER" ] || { printf 'inbound-test: the plan named no target or sender\n' >&2; exit 2; }

STAMP="$("$PY" -c 'from datetime import datetime,timezone;print(datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"))')"
SUBJECT="inbound test $STAMP — plan 116 §15.3.4 (safe to ignore)"
BODY="$(mktemp)"; trap 'rm -f "$BODY"' EXIT
cat > "$BODY" <<BODYEOF
This is the house's inbound acceptance test, sent from outside to $TARGET at $STAMP.

It exists to answer one question with a measurement instead of an assumption: can a
stranger's mail actually reach this address? If you are a person reading this, nothing
is required of you — the test asserts its own arrival and records the proof.

Plan 116 §15.3.4 · bin/mail/inbound-test.sh
BODYEOF

# 2 · SEND FROM OUTSIDE, through the approved send door. A draft is created and sent, so
# the same approval machinery that guards a real letter guards the test.
if [ "$DRY" = 1 ]; then
  "$SEND_CMD" draft --to "$TARGET" --subject "$SUBJECT" --body "$BODY" --dry-run \
    || { printf 'inbound-test: the send door refused to prepare the message\n' >&2; exit 1; }
  printf 'inbound-test[1]{state,target,sender,detail}:\n  "dry-run","%s","%s","the message is prepared and nothing was sent"\n' "$TARGET" "$SENDER"
  exit 0
fi

DRAFT_OUT="$("$SEND_CMD" draft --to "$TARGET" --subject "$SUBJECT" --body "$BODY" 2>&1)" || {
  printf 'inbound-test[1]{state,detail}:\n  "failed","the send door could not create the draft"\n  "%s"\n' \
    "$(printf '%s' "$DRAFT_OUT" | tail -1)" >&2
  exit 1
}
DRAFT_ID="$(printf '%s\n' "$DRAFT_OUT" | awk -F'\t' '$1=="draft"{print $2; exit}')"
[ -n "$DRAFT_ID" ] || { printf 'inbound-test: the send door printed no draft id\n' >&2; exit 1; }

SENT_AT="$("$PY" -c 'from datetime import datetime,timezone;print(datetime.now(timezone.utc).isoformat(timespec="seconds"))')"
"$SEND_CMD" send "$DRAFT_ID" >/dev/null || {
  printf 'inbound-test[1]{state,draft}:\n  "failed","%s"\n' "$DRAFT_ID" >&2
  exit 1
}

# 3 · WAIT AND ASSERT. `await` searches the readable mailbox for a message addressed to
# the target, keeps the To: header verbatim, and appends the proof to the ledger.
PROOF="$("$PY" "$DOOR" await --account "$SENDER" --to "$TARGET" --since "$SENT_AT" --timeout "$WAIT" --poll 10)"
PROOF_RC=$?
printf '%s' "$PROOF" | "$PY" -c '
import json,sys
proof=json.load(sys.stdin)
if proof.get("result")=="arrived":
    print("inbound-test[1]{result,target,to_header,from,message_id,waited_ledger}:")
    print("  \"ARRIVED\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"" % (
        proof.get("to"), proof.get("to_header"), proof.get("from"), proof.get("message_id"), proof.get("ledger")))
    print("assert: the To: header is intact — mail from outside reaches this address")
else:
    print("inbound-test[2]{result,target,detail}:")
    print("  \"NO ARRIVAL\",\"%s\",\"%s\"" % (proof.get("to"), (proof.get("last_error") or "nothing landed inside the window")))
    print("  \"NO ARRIVAL\",\"%s\",\"MX exists, so the route is broken — check the routing row, the destination verification, and the mailbox this forwards to\"" % proof.get("to"))
'
[ "$PROOF_RC" = 0 ] || { printf 'inbound-test: sent, but nothing arrived — this is a FAIL, not a skip\n' >&2; exit 1; }
printf 'proof: "%s" — bin/mail/addresses.sh now reports %s deliverable\n' \
  "$(printf '%s' "$PROOF" | "$PY" -c 'import json,sys;print(json.load(sys.stdin).get("ledger",""))')" "$TARGET"
exit 0
