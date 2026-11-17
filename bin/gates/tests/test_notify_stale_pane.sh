#!/usr/bin/env bash
# test_notify_stale_pane.sh — a remembered pane is proved before it is spoken to (2026-11-16).
#
# THE FAULT: seven errands finished and every one reported "pane w2:p3 reported herdr agent_not_found".
# w2:p3 was the helm's pane before the box rebooted; the arm's state still named it, so the door aimed a
# turn at a ghost, failed, and reported a delivery failure for a line the helm had already received.
#
# The two rules this proves:
#   1. a recalled pane is a CLAIM — it is checked against herdr and discarded when no agent stands there;
#   2. the wake queue is the floor — a chat injection that cannot happen is a lost convenience, not a
#      lost message, so the door exits 0 and says which one it was.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PASS=0; FAIL=0
check() { if [ "$1" = "0" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$2"; fi; }

DOOR="$ROOT/bin/agents/eindri-notify.sh"
[ -x "$DOOR" ]; check $? "the notify door exists and is executable"

W="$(mktemp -d "${TMPDIR:-/tmp}/notify-pane.XXXXXX")"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/state"

# a fake herdr that answers one live pane and nothing else — the ghost is w2:p3
mkdir -p "$W/bin"
cat >"$W/bin/herdr" <<'SH'
#!/usr/bin/env bash
case "${1-}" in
  agent)
    case "${2-}" in
      list) printf '{"result":{"agents":[{"pane_id":"w9:p1","agent":"pi","agent_status":"idle","cwd":"/tmp"}]}}' ;;
      *) exit 0 ;;
    esac ;;
  pane) exit 0 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$W/bin/herdr"

# 1 · no pane, no holder: the queue is the floor and the door exits 0
out="$(PATH="$W/bin:$PATH" BROKK_STATE_OVERRIDE="$W/state" BROKK_HELM_STATE="$W/state" \
        bash "$DOOR" --from test -- "a line that must not be lost" 2>&1)"; rc=$?
[ "$rc" = 0 ]; check $? "no live pane is a success, not a failure (rc=$rc)"
case "$out" in *"wake queue"*) check 0 "and it says the line is in the queue" ;; *) check 1 "queue named: $out" ;; esac

# 2 · a RECALLED ghost pane (the w2:p3 shape) is discarded, not spoken to
printf 'w2:p3\n' >"$W/state/.arm.pane"
out="$(PATH="$W/bin:$PATH" BROKK_STATE_OVERRIDE="$W/state" BROKK_HELM_STATE="$W/state" YMIR_NO_INJECT=1 \
        bash "$DOOR" --from test -- "a line aimed at a ghost" 2>&1)"; rc=$?
[ "$rc" = 0 ]; check $? "a ghost pane does not fail the delivery (rc=$rc)"
case "$out" in *"holds no live agent"*) check 0 "the ghost is named as a ghost" ;; *) check 1 "ghost named: $out" ;; esac
case "$out" in *"w2:p3"*) check 0 "and it is named by id, so the record can be corrected" ;; *) check 1 "ghost id: $out" ;; esac

printf 'notify stale-pane tests: %d pass, %d fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
