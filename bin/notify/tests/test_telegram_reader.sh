#!/usr/bin/env bash
# test_telegram_reader.sh — the hand-over: never two readers, and the reader follows the arm.
# A synthetic home, synthetic harness homes, synthetic tokens and stand-in poller processes.
# Nothing here reads or writes the machine's own bot, arm or vault.
set -uo pipefail
ROOT="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; : >"$T/pids"
trap 'while read -r p; do kill "$p" 2>/dev/null; done <"$T/pids"; rm -rf "$T"' EXIT
pass=0; fail=0
t() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass=$((pass+1)); echo "  ok   $d"; else fail=$((fail+1)); echo "  FAIL $d"; fi; }

export HOME="$T/user" YMIR_HOME="$T/home" YMIR_MACHINE=box-a
export XDG_STATE_HOME="$T/xdg" XDG_CONFIG_HOME="$T/cfg"
export BROKK_MACHINE_STATE_DIR="$T/machine" BROKK_STATE_OVERRIDE="$T/state" YMIR_STATE_DIR="$T/state"
export YMIR_TELEGRAM_READER_FORCE=1
unset PI_CODING_AGENT_DIR CLAUDE_CONFIG_DIR YMIR_CLAUDE_TELEGRAM_DIR HERMES_HOME YMIR_HOARD BROKK_SESSION_PID RODD_ARM_LEASE
export YMIR_HERMES_CMD="$T/hermes-stub"
printf '#!/bin/sh\necho "$@" >>"%s"\n' "$T/hermes.calls" >"$YMIR_HERMES_CMD"; chmod +x "$YMIR_HERMES_CMD"

BOT=111111111; TOKEN="$BOT:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
OTHER="222222222:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
mkdir -p "$YMIR_HOME/hodd/identity" "$YMIR_HOME/hodd/secrets" "$T/machine" "$T/state" \
  "$HOME/.pi/agent/tmp/pi-telegram" "$HOME/.claude/channels/telegram" "$HOME/.hermes"
registry() { printf 'version: 1\nmachines:\n  box-a:\n    telegram: {bot_id: "%s", token_ref: secrets/bot.env%s}\n' "$BOT" "$1" >"$YMIR_HOME/hodd/identity/machines.yaml"; }
printf 'telegram:\n  user_id: "4242"\n' >"$YMIR_HOME/hodd/identity/operator.yaml"
printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TOKEN" >"$YMIR_HOME/hodd/secrets/bot.env"

PI="$HOME/.pi/agent/telegram.json"; PIST="$HOME/.pi/agent/tmp/pi-telegram/state.json"
CL="$HOME/.claude/channels/telegram"; HE="$HOME/.hermes/.env"
R="$ROOT/bin/notify/telegram-reader.sh"
has() { grep -qF "$BOT:" "$1" 2>/dev/null; }
holders() { local n=0 f; for f in "$PI" "$CL/.env" "$HE"; do has "$f" && n=$((n+1)); done; echo "$n"; }
# a stand-in harness session: a live process, named the arm holder by the lock and the role sidecar
session() { sleep 300 >/dev/null 2>&1 & S=$!; echo "$S" >>"$T/pids"; }
arm() { printf '%s\n' "$1" >"$T/machine/brokk.lock"; rm -f "$T/machine/brokk.lock.starttime"; printf 'role=%s session=%s\n' "$2" "$1" >"$T/state/.arm.role"; }
poller() { bash -c 'exec -a "bun server.ts" sleep 300' >/dev/null 2>&1 & P=$!; echo "$P" >>"$T/pids"; printf '%s\n' "$P" >"$CL/bot.pid"; sleep 0.2; }
gone() { for _ in 1 2 3 4 5 6 7 8 9 10; do case "$(ps -o stat= -p "$1" 2>/dev/null)" in ''|Z*) return 0 ;; esac; sleep 0.1; done; return 1; }

echo "telegram-reader"
printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TOKEN" >"$CL/.env"
registry ""; session; PISESSION=$S; arm "$PISESSION" pi
t "off until the home opts in" bash -c "'$R' sync | grep -q '\"off\"'"
t "off: nothing was changed" test ! -e "$PI"

registry ", reader: arm"
printf '{"profiles":{"default":{"keep":1}}}\n' >"$PI"
poller
t "a pi holder takes the bot" "$R" sync
t "pi has the token" has "$PI"
t "the Claude poller outside the holder is stopped" gone "$P"
t "exactly one harness holds the bot" test "$(holders)" = 1
t "pi gets the home's allowlist" grep -q '"allowedUserId": 4242' "$PI"
t "other pi settings are kept" grep -q '"keep": 1' "$PI"
t "the token file is private" bash -c "ls -l '$PI' | grep -q '^-rw-------'"

# the arm moves to Claude while pi is reading
printf '{"profiles":{"default":{"transport":{"pid":%s,"journalPath":"/j"},"other":1}}}\n' "$PISESSION" >"$PIST"
session; CLSESSION=$S; arm "$CLSESSION" claude
OUT="$("$R" sync)"
t "the arm moved: Claude has the token" has "$CL/.env"
t "the arm moved: pi lost it" bash -c "! grep -qF '$BOT:' '$PI'"
t "the live pi reader is told to stand down" grep -q ymir-arm-handover "$PIST"
t "pi's journal custody and other keys are kept" bash -c "grep -q '\"/j\"' '$PIST' && grep -q '\"other\": 1' '$PIST'"
t "pi itself is never killed" kill -0 "$PISESSION"
t "exactly one harness holds the bot" test "$(holders)" = 1
t "Claude gets the same allowlist" python3 -c "import json;d=json.load(open('$CL/access.json'));assert d['allowFrom']==['4242'] and d['dmPolicy']=='allowlist'"
t "the holder is told the one step left" grep -q '/mcp' <<<"$OUT"
t "no token is printed" bash -c '! grep -qF AAAAAAAA <<<"$1"' _ "$OUT"

poller   # a Claude session that is NOT the holder takes the poller
t "check refuses a reader that is not the holder's" bash -c "! '$R' check"
"$R" sync >/dev/null
t "a second session of the same harness is stopped" gone "$P"
t "check passes afterwards" "$R" check

arm "$PISESSION" counsellor; "$R" sync >/dev/null
t "back on pi: the hand-over record is cleared" bash -c "! grep -q ymir-arm-handover '$PIST'"
t "back on pi: one holder of the bot" test "$(holders)" = 1

session; arm "$S" hermes; "$R" sync >/dev/null
t "a Hermes holder takes the bot and the allowlist" bash -c "grep -qF '$BOT:' '$HE' && grep -qx 'TELEGRAM_ALLOWED_USERS=4242' '$HE'"
t "its gateway is restarted" grep -q 'gateway restart' "$T/hermes.calls"
t "exactly one harness holds the bot" test "$(holders)" = 1

arm "$S" opencode; OUT="$("$R" sync)"
t "a holder with no channel: nobody reads" test "$(holders)" = 0
t "and it says so" grep -q no-channel <<<"$OUT"

arm "$PISESSION" pi; "$R" sync >/dev/null
"$R" sync --released >/dev/null
t "released: nobody reads" test "$(holders)" = 0

printf 'TELEGRAM_BOT_TOKEN=%s\n' "$OTHER" >"$CL/.env"
arm "$PISESSION" pi; "$R" sync >/dev/null
t "a different bot is left alone" grep -qF "$OTHER" "$CL/.env"

cp "$PI" "$T/pi.before"
arm 999999999 claude
t "a vacant arm changes nothing" bash -c "'$R' sync | grep -q vacant && cmp -s '$PI' '$T/pi.before'"

printf 'SKIRNIR_TELEGRAM_BOT_TOKEN=%s\n' "$TOKEN" >"$YMIR_HOME/hodd/secrets/platform.env"
arm "$CLSESSION" claude
t "the assistant's bot is refused as the machine bot" bash -c "! '$R' sync && cmp -s '$PI' '$T/pi.before'"
rm "$YMIR_HOME/hodd/secrets/platform.env"

: >"$YMIR_HOME/hodd/identity/operator.yaml"
t "no operator id: refused, nothing granted" bash -c "! '$R' sync && ! grep -qF '$BOT:' '$CL/.env'"

t "a private seat never moves the bot" bash -c "env -u YMIR_TELEGRAM_READER_FORCE '$R' sync | grep -q private-seat"

printf 'test_telegram_reader: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
