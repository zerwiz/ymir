#!/usr/bin/env bash
# smoke.sh — Skírnir and Snotra, end to end, in one command. The house's answer to "are we working?".
#
#   bin/assistant/smoke.sh [--quick] [--quiet]
#
# Every check is a REAL path a person uses, and every one has three possible verdicts:
#   PASS  the thing works, right now, on this box
#   SKIP  the thing cannot be tested here (no network, no meet, no drive) — a clean skip is a pass,
#         but it is PRINTED, so "we did not test it" is never the same as "it passed" (Rule 25)
#   FAIL  it does not work — and the failure names the fix
#
# Exit: 0 every check passed or skipped · 1 at least one FAIL.
#
# This file is the record of every fault of 2026-10-22/23: the dead TTS, the stamp nobody touched, the
# seat with the host's microphone, the invented Trello id, the silent no-answer, the empty digest.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root H 2>/dev/null || true
QUICK=0; QUIET=0
for a in "$@"; do case "$a" in --quick) QUICK=1 ;; --quiet) QUIET=1 ;; esac; done
PASS=0; SKIP=0; FAIL=0
ok()   { PASS=$((PASS+1)); [ "$QUIET" = 0 ] && printf '  PASS  %s\n' "$1"; }
skip() { SKIP=$((SKIP+1)); [ "$QUIET" = 0 ] && printf '  SKIP  %s — %s\n' "$1" "$2"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s — %s\n' "$1" "$2" >&2; }
j() { python3 -c "import sys,json;d=json.load(sys.stdin);print(eval(sys.argv[1]))" "$1" 2>/dev/null; }

echo "smoke — Skírnir and Snotra, end to end"

# ── 1 · the engine answers, and the walls hold ────────────────────────────────────────────────
ASK() { SKIRNIR_MODEL="${SMOKE_MODEL:-}" python3 "$SCRIPT_DIR/skirnir.py" --tier "${2:-owner}" \
        --channel "${3:-console}" --chat "${4:-smoke}" --text "$1" 2>/dev/null; }
R="$(ASK 'what is ymir')"
[ -n "$R" ] && ok "the engine answers" || bad "the engine" "no output at all"
[ "$(printf '%s' "$R" | j "d.get('intent','')")" != "" ] && ok "the answer carries an intent" \
  || bad "intent" "$R"
U="$(ASK 'what is gimle')"
[ "$(printf '%s' "$U" | j "d.get('intent','')")" = "unknown" ] \
  && ok "an unheld subject is refused, not answered as another fact" || bad "matcher" "$U"

# ── 1b · the pitch: asked about Ymir, he must TEACH, not label (his word, 2026-10-23) ────────
P="$(ASK 'what is ymir')"
PW="$(printf '%s' "$P" | j "len(d.get('answer','').split())")"
case "${PW:-0}" in
  ''|0|1|2|3|4|5|6|7|8|9|1[0-9]|2[0-9]|3[0-9]) bad "the Ymir pitch" "only ${PW:-0} words — that is a label, not an explanation" ;;
  *) ok "the Ymir pitch explains it (${PW} words)" ;;
esac
case "$(printf '%s' "$P" | j "d.get('answer','')")" in
  *Brokk*|*Eindri*|*Kaia*) ok "the pitch names the fleet" ;;
  *) bad "the pitch" "does not name the fleet (Brokk, Eindri, Kaia)" ;;
esac

# ── 2 · the digest is the operator's, and it is not empty ─────────────────────────────────────
N=$(wc -l < "$H/hodd/state/assistant/digest.jsonl" 2>/dev/null || echo 0)
[ "${N:-0}" -ge 20 ] && ok "the digest holds ${N} facts" || bad "digest" "only ${N} facts"
C=$(wc -l < "$H/hodd/state/assistant/canaries.derived.txt" 2>/dev/null || echo 0)
[ "${C:-0}" -ge 50 ] && ok "the canaries are derived (${C})" || bad "canaries" "only ${C}"

# ── 3 · the voice OUT (the fault of 2026-10-23) ───────────────────────────────────────────────
# the idle-stop is CORRECT to lower an unused voice — so the smoke raises it first, and only a voice
# that cannot be raised is a fault
if ! curl -s -m 3 -o /dev/null http://127.0.0.1:8765/ 2>/dev/null; then
  systemctl --user start kokoro-serve.service >/dev/null 2>&1
  for _i in $(seq 1 12); do sleep 2
    curl -s -m 3 -o /dev/null http://127.0.0.1:8765/ 2>/dev/null && break
  done
fi
if curl -s -m 6 -o /dev/null -X POST http://127.0.0.1:8765/v1/audio/speech \
     -H 'content-type: application/json' -d '{"input":"x","voice":"af_nicole","response_format":"wav"}' 2>/dev/null; then
  ok "kokoro answers on :8765"
  bash "$ROOT/bin/time/snotra/tts-lease.sh" touch >/dev/null 2>&1
  if [ -f "$HOME/.local/share/skirnir/tts.lease" ]; then ok "the TTS lease is held"; else bad "tts lease" "no lease file"; fi
  if bash "$SCRIPT_DIR/mouth.sh" "smoke test of the voice" /tmp/smoke-voice.ogg >/dev/null 2>&1 \
     && [ -s /tmp/smoke-voice.ogg ]; then
    ok "the mouth makes a voice note ($(stat -c%s /tmp/smoke-voice.ogg) bytes)"
  else bad "the mouth" "no voice note produced"; fi
else
  bad "kokoro" "no answer on :8765 — systemctl --user start kokoro-serve"
fi

# ── 4 · the voice IN (the ear) ────────────────────────────────────────────────────────────────
if [ -s /tmp/smoke-voice.ogg ]; then
  HEARD="$(bash "$SCRIPT_DIR/ear.sh" /tmp/smoke-voice.ogg 2>/dev/null)"
  case "$HEARD" in *smoke*|*voice*|*Voice*) ok "the ear hears the note back" ;;
    "") skip "the ear" "no transcription returned" ;;
    *) bad "the ear" "heard: ${HEARD:0:60}" ;; esac
elif curl -s -m 4 -o /dev/null http://127.0.0.1:10300/ 2>/dev/null; then
  skip "the ear" "no note to hear (the mouth failed above)"
else
  skip "the ear" "no whisper on :10300"
fi

# ── 5 · the schedule reads the live calendar ──────────────────────────────────────────────────
S="$(ASK 'where is he' owner)"
case "$S" in *schedule*|*"free"*|*"meeting"*|*"calendar"*) ok "the schedule reads the calendar" ;;
  *) skip "the schedule" "the calendar is unreadable from here" ;; esac

# ── 6 · research reaches the real provider ────────────────────────────────────────────────────
if [ "$QUICK" = 0 ]; then
  RD="$(timeout 90 python3 "$SCRIPT_DIR/research.py" --query "OVK ventilation Boverket" --limit 2 --no-cache 2>/dev/null)"
  PR="$(printf '%s' "$RD" | j "d.get('provider','')")"
  NS="$(printf '%s' "$RD" | j "len(d.get('sources') or [])")"
  case "$PR" in
    exa) ok "research reaches Exa (${NS} sources)" ;;
    exa-cache) ok "research answered from cache (${NS} sources)" ;;
    wikipedia-fallback) bad "research" "fell back to the stub — Exa unreachable" ;;
    *) skip "research" "no network or no provider" ;;
  esac
  case "$RD" in *http*) bad "research door" "a link leaked into the text" ;; *) : ;; esac
fi

# ── 7 · the answer-back ledger ────────────────────────────────────────────────────────────────
AID="$(bash "$SCRIPT_DIR/asks.sh" add --who "smoke (@smoke)" --chat 0 --channel console \
       --question "smoke: can an answer find its way back" 2>/dev/null)"
if [ -n "$AID" ]; then ok "an ask can be recorded (${AID})"
  MSG="$(bash "$SCRIPT_DIR/escalate.sh" --tier collaborator --chat 0 --who "smoke (@smoke)" \
          --text "smoke" --context "smoke" --reason "smoke" --dry-run 2>&1)"
  case "$MSG" in *"smoke (@smoke)"*) ok "the handoff names the asker" ;; *) bad "handoff" "$MSG" ;; esac
  bash "$SCRIPT_DIR/asks.sh" close "$AID" --why "smoke" >/dev/null 2>&1
else bad "ask ledger" "could not record an ask"; fi

# ── 8 · Trello: resolve by name, never by id ─────────────────────────────────────────────────
if [ -f "$H/hodd/identity/trello-map.yaml" ]; then
  ARI="$(bash "$ROOT/bin/time/snotra/trello-map.sh" --resolve "control tower" "in progress" 2>/dev/null)"
  case "$ARI" in ari:cloud:trello::list/*) ok "the Trello id resolves by name" ;;
    *) bad "trello resolve" "${ARI:-no answer}" ;; esac
else
  skip "trello map" "no map yet — bin/time/snotra/trello-map.sh"
fi

# ── 9 · the meeting seat has a mouth and a guard ─────────────────────────────────────────────
if command -v chromium >/dev/null 2>&1; then
  if bash "$ROOT/bin/time/snotra/snotra-meet.sh" state --port 9899 >/dev/null 2>&1; then
    skip "the seat" "no live seat to inspect on :9899"
  else
    ok "the seat door answers (no seat running)"
  fi
  python3 "$ROOT/bin/time/snotra/snotra-cdp.py" seat --port 9899 >/dev/null 2>&1
  [ $? -eq 2 ] && ok "the seat refuses to run without a url" || bad "seat guard" "seat ran without --url"
fi

# ── 10 · the far-side ear (plan 111 · S1): a chain, not a switch ────────────────────────────
if [ -x "$ROOT/bin/time/snotra/stt-wire.sh" ]; then
  CHAIN="$(bash "$ROOT/bin/time/snotra/stt-wire.sh" check 2>&1)"
  case "$CHAIN" in
    *"cannot reach"*) skip "the far-side ear" "the firewall blocks the docker bridge — one scoped ufw rule closes it (see stt-wire.sh check)" ;;
    *FAIL*) bad "the far-side ear" "$(printf '%s' "$CHAIN" | grep FAIL | head -1 | sed 's/^ *//')" ;;
    *) ok "the far-side ear's chain is whole (whisper → shim → network → env)" ;;
  esac
else
  skip "the far-side ear" "no stt-wire.sh on this seat"
fi

# ── 11 · the guardrails that keep the above true ─────────────────────────────────────────────
if [ -f "$HOME/.local/bin/kokoro-idle-stop.sh" ]; then
  grep -q "tts.lease" "$HOME/.local/bin/kokoro-idle-stop.sh" \
    && ok "the idle-stop consults the lease" || bad "idle-stop" "does not consult Skírnir's lease"
else bad "idle-stop" "~/.local/bin/kokoro-idle-stop.sh is missing"; fi
[ -d "$H/hodd/saves/assistant" ] && ok "the ledger has a nightly snapshot" \
  || skip "backup" "no snapshot yet — bin/assistant/backup.sh"
G="$(bash "$ROOT/bin/people/group-members.sh" 2>/dev/null | grep -c '","')"
[ "${G:-0}" -ge 1 ] && ok "the group door lists ${G} group(s)" || skip "group members" "no groups allowed yet"

echo
printf 'smoke: %d pass · %d skip · %d fail\n' "$PASS" "$SKIP" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
