#!/usr/bin/env bash
# open-target.test.sh — every message opens something, or says it cannot.
#
# Plan 230, his word: *"i wanna be eble to click all ymirs messegnes and see whats they
# are about."* The fault that opened the plan was a toast that looked clickable and did
# nothing. So this test proves:
#
#   1. the four target kinds RESOLVE (file · plan · pr · yl://), and a target that does
#      not resolve is refused, never opened;
#   2. a message with no target says `(no link)` in its title — the dead end is visible;
#   3. `send.sh --target` verifies once and reports what it resolved;
#   4. no subsystem draws its own toast any more: `notify-send` and
#      `omarchy-notification-send` are named ONLY under bin/notify/.
#
# Hermetic: the opener is a stub (YMIR_OPEN_CMD), the gate is a closed port, and the
# plan shelf is only asserted when the home is present.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OT="$ROOT/bin/notify/open-target.sh"
DK="$ROOT/bin/notify/desktop.sh"
SEND="$ROOT/bin/notify/send.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OPENER_LOG="$TMP/opened.log"
cat > "$TMP/opener" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$OPENER_LOG"
SH
chmod +x "$TMP/opener"
export YMIR_OPEN_CMD="$TMP/opener"
export OPENER_LOG
export YMIR_OPEN_TARGET_FINDING=1   # never file a finding from inside the test
export YMIR_GATE_URL="http://127.0.0.1:1"   # a port nothing listens on

state() { printf '%s' "$1" | sed -n 's/^  "[^"]*","[^"]*","[^"]*","\([^"]*\)"$/\1/p' | head -1; }
resolved() { printf '%s' "$1" | sed -n 's/^  "[^"]*","[^"]*","\([^"]*\)","[^"]*"$/\1/p' | head -1; }

# ── 1. a file target: resolved, then handed to the opener ─────────────────────
printf 'a report\n' > "$TMP/report.md"
out="$(bash "$OT" --check "file:$TMP/report.md")"
[ "$(state "$out")" = "would-open" ] && ok "a file target resolves (would-open)" \
  || bad "a file target resolves (got: $out)"
rm -f "$OPENER_LOG"
out="$(bash "$OT" "file:$TMP/report.md")"; rc=$?
[ "$rc" -eq 0 ] && [ "$(state "$out")" = "opened" ] && ok "a file target opens" \
  || bad "a file target opens (rc=$rc, $out)"
sleep 0.2
grep -qx "$TMP/report.md" "$OPENER_LOG" 2>/dev/null \
  && ok "the opener received the real path" \
  || bad "the opener received the real path (log: $(cat "$OPENER_LOG" 2>/dev/null))"

out="$(bash "$OT" --check "file:$TMP/nothing-here.md")"; rc=$?
[ "$rc" -eq 1 ] && [ "$(state "$out")" = "missing" ] && ok "a missing file is refused as 'target missing'" \
  || bad "a missing file is refused (rc=$rc, $out)"

# ── 2. plan · pr · yl:// ─────────────────────────────────────────────────────
HOME_R="$(bash -c '. "$1" 2>/dev/null; ymir_home_root H; printf "%s" "$H"' _ "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null | tail -1)"
if [ -n "$HOME_R" ] && [ -d "$HOME_R/svartalfaheim" ]; then
  out="$(bash "$OT" --check plan:230)"
  case "$(resolved "$out")" in
    */plans/230-*.md) ok "plan:230 resolves to the ledger file" ;;
    *) bad "plan:230 resolves to the ledger file (got: $out)" ;;
  esac
  out="$(bash "$OT" --check plan:99999)"; rc=$?
  [ "$rc" -eq 1 ] && ok "a plan number with no file is refused, not guessed" || bad "an absent plan is refused"
else
  printf '# skip: no plan shelf on this box (the home is absent)\n'
fi

out="$(bash "$OT" --check pr:https://github.com/zerwiz/ymir/pull/599)"
[ "$(state "$out")" = "would-open" ] && ok "a pull-request target resolves" || bad "a PR target resolves (got: $out)"
out="$(bash "$OT" --check pr:https://example.com/not/a/pr)"; rc=$?
[ "$rc" -eq 1 ] && ok "a non-PR url is refused" || bad "a non-PR url is refused (rc=$rc)"

out="$(bash "$OT" --check yl://day)"; rc=$?
[ "$rc" -eq 1 ] && [ "$(state "$out")" = "gate-down" ] && ok "a Hlidskjalf route is refused while the gate is down" \
  || bad "a route is refused while the gate is down (rc=$rc, $out)"

# ── 3. the title tells him when there is nothing to open ─────────────────────
out="$(bash "$DK" --title "a notice" --body "nothing to open" --dry-run)"
case "$out" in *"(no link)"*) ok "a message with no target says (no link) in its title" ;;
  *) bad "a message with no target says (no link) (got: $out)" ;; esac
out="$(bash "$DK" --title "a notice" --body "b" --dry-run --target "file:$TMP/report.md")"
case "$out" in *"(no link)"*) bad "a message WITH a resolvable target must not say (no link)" ;;
  *) ok "a message with a resolvable target carries it, and no (no link)" ;; esac
out="$(bash "$DK" --title "a notice" --body "b" --dry-run --target "file:$TMP/gone.md")"
case "$out" in *"(target missing)"*) ok "a message whose target vanished says (target missing)" ;;
  *) bad "a vanished target says (target missing) (got: $out)" ;; esac

# ── 4. send.sh verifies the target once and reports it ───────────────────────
out="$(bash "$SEND" --source notify --severity INFO --message "probe" --target "file:$TMP/report.md" --dry-run)"
case "$out" in *"\"resolved\",\"$TMP/report.md\""*) ok "send.sh reports what the target resolved to" ;;
  *) bad "send.sh reports the resolved target (got: $(printf '%s' "$out" | tail -3 | tr '\n' ' '))" ;; esac
out="$(bash "$SEND" --source notify --severity INFO --message "probe" --dry-run)"
case "$out" in *'"none",""'*) ok "send.sh reports honestly when a message carries no target" ;;
  *) bad "send.sh reports 'none' with no target (got: $(printf '%s' "$out" | tail -3 | tr '\n' ' '))" ;; esac

# ── 5. one spout: no subsystem draws its own toast ───────────────────────────
leaks="$(grep -rn --include='*.sh' --include='*.py' --include='*.ts' --include='*.js' --include='*.mjs' \
  -e 'notify-send' -e 'omarchy-notification-send' "$ROOT" 2>/dev/null \
  | grep -v '/node_modules/' | grep -v '/.yggdrasil/' | grep -v '/bin/notify/' | grep -v '/.agents/tests/')"
if [ -z "$leaks" ]; then ok "notify-send and omarchy-notification-send are named only under bin/notify/"
else bad "only bin/notify/ draws a toast — found: $(printf '%s' "$leaks" | head -4 | tr '\n' ' ')"; fi

for sender in bin/gates/wedge-notify.sh bin/host/crash-sense.sh \
              systems/snotra/services/tts-lease/ymir-say.sh \
              systems/snotra/services/cron/snotra-cron.sh; do
  grep -q 'notify/send\.sh\|notify/desktop\.sh' "$ROOT/$sender" 2>/dev/null \
    && ok "$(basename "$sender") routes through the notify door" \
    || bad "$(basename "$sender") routes through the notify door"
done

[ "$fail" -eq 0 ] && printf '1..1 # all claims proved\n'
exit "$fail"
