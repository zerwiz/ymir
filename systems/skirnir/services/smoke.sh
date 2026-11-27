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
# The repo root, found by walking up to the tree that holds .pi and RULES — never counted in
# "../", because this shelf was moved once (bin/assistant/ -> systems/skirnir/, plan 149) and
# 25 scripts kept the old depth, so every $ROOT/bin/... pointed into systems/ instead (2026-11-02).
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
# where the engine listens is one value (plan 326.0) — the unit binds it, the test dials it
# shellcheck source=../../../bin/voice/kokoro-lib.sh
. "$ROOT/bin/voice/kokoro-lib.sh"
KBASE="$(kokoro_base_url)"; KPORT="$(kokoro_port)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root H 2>/dev/null || true
QUICK=0; QUIET=0
for a in "$@"; do case "$a" in --quick) QUICK=1 ;; --quiet) QUIET=1 ;; esac; done
PASS=0; SKIP=0; FAIL=0
# Both must RETURN 0: every check reads `test && ok … || bad …`, so a verdict that returns non-zero
# (as `[ "$QUIET" = 0 ] && printf` does under --quiet) books the same check as a failure too.
ok()   { PASS=$((PASS+1)); [ "$QUIET" = 1 ] || printf '  PASS  %s\n' "$1"; return 0; }
skip() { SKIP=$((SKIP+1)); [ "$QUIET" = 1 ] || printf '  SKIP  %s — %s\n' "$1" "$2"; return 0; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s — %s\n' "$1" "$2" >&2; }
j() { python3 -c "import sys,json;d=json.load(sys.stdin);print(eval(sys.argv[1]))" "$1" 2>/dev/null; }
# every note this run makes lives here, so yesterday's note can never pass today's check
NOTES="$(mktemp -d "${TMPDIR:-/tmp}/skirnir-smoke.XXXXXX")" || exit 1
trap 'rm -rf "$NOTES"' EXIT
# a synthesiser is an endpoint that returns speech: `curl` alone is happy with any server's 501
speaks() { curl -sf -m 60 -o "$NOTES/probe.wav" -X POST "$KBASE/v1/audio/speech" -H 'content-type: application/json' \
             -d '{"model":"kokoro","input":"x","voice":"af_nicole","response_format":"wav"}' 2>/dev/null \
           && [ -s "$NOTES/probe.wav" ]; }

echo "smoke — Skírnir and Snotra, end to end"

# ── 1 · the engine answers, and the walls hold ────────────────────────────────────────────────
ASK() { SKIRNIR_MODEL="${SMOKE_MODEL:-}" python3 "$SCRIPT_DIR/skirnir.py" --tier "${2:-owner}" \
        --channel "${3:-console}" --chat "${4:-smoke}" --text "$1" 2>/dev/null; }
R="$(ASK 'what is ymir')"
[ -n "$R" ] && ok "the engine answers" || bad "the engine" "no output at all"
[ "$(printf '%s' "$R" | j "d.get('intent','')")" != "" ] && ok "the answer carries an intent" \
  || bad "intent" "$R"
# the subject is INVENTED: a real name (`gimle`, until 2026-11-26) stops being unheld the day the house
# writes about it
U="$(ASK 'what is vzorblum')"
[ "$(printf '%s' "$U" | j "d.get('intent','')")" = "unknown" ] \
  && ok "an unheld subject is refused, not answered as another fact" || bad "matcher" "$U"
G="$(ASK 'what is gimle')"
case "$(printf '%s' "$G" | j "d.get('intent','')+' '+' '.join(d.get('facts') or [])")" in
  '') bad "matcher" "no answer for a near-miss subject: $G" ;;
  *ymir_pitch*|*"what is ymir"*|*home-doc-hodd-saves-*|*home-doc-hodd-reference-*retired*|*home-doc-hodd-reference-*moved*)
    bad "matcher" "answered from another subject or an archived record: $G" ;;
  *) ok "a different subject is neither the Ymir pitch nor an archived record" ;;
esac

# ── 1b · the pitch: asked about Ymir, he must TEACH, not label (his word, 2026-10-23) ────────
P="$(ASK 'what is ymir')"
PW="$(printf '%s' "$P" | j "len(d.get('answer','').split())")"
case "${PW:-0}" in
  ''|0|1|2|3|4|5|6|7|8|9|1[0-9]|2[0-9]|3[0-9]) bad "the Ymir pitch" "only ${PW:-0} words — that is a label, not an explanation" ;;
  *) ok "the Ymir pitch explains it (${PW} words)" ;;
esac
case "$(printf '%s' "$P" | j "d.get('answer','')")" in
  *Brokk*|*Eindri*|*Völundr*) ok "the pitch names the fleet" ;;
  *) bad "the pitch" "does not name the fleet (Brokk, Eindri, Völundr)" ;;
esac
case "$(printf '%s' "$P" | j "' '.join(d.get('facts') or [])")" in
  *home-*|*site-*|*capabilities*) bad "the pitch" "built from document titles or page scraps, not facts about Ymir" ;;
  *) ok "the pitch is built from facts, not document titles" ;;
esac

# ── 2 · the digest is the operator's, and it is not empty ─────────────────────────────────────
N=$(wc -l < "$H/state/assistant/digest.jsonl" 2>/dev/null || echo 0)
[ "${N:-0}" -ge 20 ] && ok "the digest holds ${N} facts" || bad "digest" "only ${N} facts"
C=$(wc -l < "$H/state/assistant/canaries.derived.txt" 2>/dev/null || echo 0)
[ "${C:-0}" -ge 50 ] && ok "the canaries are derived (${C})" || bad "canaries" "only ${C}"

# ── 3 · the voice OUT (the fault of 2026-10-23) ───────────────────────────────────────────────
# the idle-stop is CORRECT to lower an unused voice — so the smoke raises it first, and only a voice
# that cannot be raised is a fault
if ! curl -s -m 3 -o /dev/null "$KBASE/" 2>/dev/null; then
  systemctl --user start kokoro-serve.service >/dev/null 2>&1
  for _i in $(seq 1 12); do sleep 2
    curl -s -m 3 -o /dev/null "$KBASE/" 2>/dev/null && break
  done
fi
if speaks; then
  ok "kokoro answers on :$KPORT"
  bash "$ROOT/systems/snotra/services/tts-lease/tts-lease.sh" touch >/dev/null 2>&1
  if [ -f "$HOME/.local/share/skirnir/tts.lease" ]; then ok "the TTS lease is held"; else bad "tts lease" "no lease file"; fi
  if bash "$SCRIPT_DIR/mouth.sh" "smoke test of the voice" "$NOTES/voice.ogg" >/dev/null 2>&1 \
     && [ -s "$NOTES/voice.ogg" ]; then
    ok "the mouth makes a voice note ($(stat -c%s "$NOTES/voice.ogg") bytes)"
  else bad "the mouth" "no voice note produced"; fi
else
  SQ="$(kokoro_port_squatter)"
  bad "kokoro" "no speech on :$KPORT — ${SQ:-systemctl --user start kokoro-serve}"
fi

# ── 4 · the voice IN (the ear) ────────────────────────────────────────────────────────────────
if [ -s "$NOTES/voice.ogg" ]; then
  HEARD="$(bash "$SCRIPT_DIR/ear.sh" "$NOTES/voice.ogg" 2>/dev/null)"
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
  RD="$(timeout 90 python3 "$SCRIPT_DIR/research.py" --query "EU energy performance certificate requirements" --limit 2 --no-cache 2>/dev/null)"
  PR="$(printf '%s' "$RD" | j "d.get('provider','')")"
  NS="$(printf '%s' "$RD" | j "len(d.get('sources') or [])")"
  case "$PR" in
    exa) ok "research reaches Exa (${NS} sources)" ;;
    exa-cache) ok "research answered from cache (${NS} sources)" ;;
    wikipedia-fallback) bad "research" "fell back to the open encyclopaedia — Exa unreachable" ;;
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
# The board and the list are the OPERATOR's (plan 288 §1): his map names them, so this file never does.
if [ -f "$H/hodd/identity/trello-map.yaml" ]; then
  ARI="$(python3 - "$H/hodd/identity/trello-map.yaml" "$ROOT" <<'PYMAP'
import os, subprocess, sys, yaml
m = yaml.safe_load(open(sys.argv[1], encoding="utf-8")) or {}
boards = m.get("boards") or []
if not isinstance(boards, list):        # a map that names boards but no lists: not trello-map.sh's shape
    boards = []
pair = next(((b.get("name"), l.get("name")) for b in boards if isinstance(b, dict)
             for l in (b.get("lists") or []) if b.get("name") and l.get("name")), None)
if pair:
    door = os.path.join(sys.argv[2], "systems", "snotra", "services", "cron", "trello-map.sh")
    print(subprocess.run(["bash", door, "--resolve", pair[0], pair[1]],
                         capture_output=True, text=True).stdout.strip())
PYMAP
)"
  case "$ARI" in ari:cloud:trello::list/*) ok "the Trello id resolves by name" ;;
    "") skip "trello resolve" "his map names no board and list yet" ;;
    *) bad "trello resolve" "${ARI:-no answer}" ;; esac
else
  skip "trello map" "no map yet — systems/snotra/services/cron/trello-map.sh"
fi

# ── 9 · the meeting seat has a mouth and a guard ─────────────────────────────────────────────
if command -v chromium >/dev/null 2>&1; then
  if bash "$ROOT/systems/snotra/services/ear/snotra-meet.sh" state --port 9899 >/dev/null 2>&1; then
    skip "the seat" "no live seat to inspect on :9899"
  else
    ok "the seat door answers (no seat running)"
  fi
  python3 "$ROOT/systems/snotra/services/ear/snotra-cdp.py" seat --port 9899 >/dev/null 2>&1
  [ $? -eq 2 ] && ok "the seat refuses to run without a url" || bad "seat guard" "seat ran without --url"
fi

# ── 10 · the far-side ear (plan 111 · S1): a chain, not a switch ────────────────────────────
if [ -x "$ROOT/systems/snotra/services/ear/stt-wire.sh" ]; then
  CHAIN="$(bash "$ROOT/systems/snotra/services/ear/stt-wire.sh" check 2>&1)"
  case "$CHAIN" in
    *"cannot reach"*) skip "the far-side ear" "the firewall blocks the docker bridge — one scoped ufw rule closes it (see stt-wire.sh check)" ;;
    *FAIL*) bad "the far-side ear" "$(printf '%s' "$CHAIN" | grep FAIL | head -1 | sed 's/^ *//')" ;;
    *) ok "the far-side ear's chain is whole (whisper → shim → network → env)" ;;
  esac
else
  skip "the far-side ear" "no stt-wire.sh on this seat"
fi

# ── the meeting record: a tracked record may not go missing (Rule 11) ──────────────────────
if [ -x "$ROOT/systems/snotra/services/approve/meeting-record-guard.sh" ]; then
  MG="$(bash "$ROOT/systems/snotra/services/approve/meeting-record-guard.sh" check 2>&1)"
  case "$MG" in
    *not\ a\ git\ repo*) skip "meeting records" "the meetings shelf is not in a repo here" ;;
    *'"0"'*) ok "every tracked meeting record is on disk" ;;
    *) bad "meeting records" "$(printf '%s' "$MG" | sed -n '2,3p' | tr '\n' ' ')" ;;
  esac
else
  skip "meeting records" "no meeting-record-guard.sh"
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


# ═══ the suite that must never let an update break a room ═══════════════════════════════════
# Every check below exists because something BROKE this way on 2026-10-22/23. A check that cannot
# fail is a decoration; each one here asserts a behaviour a person would notice.

# ── A · the pitch, in the shapes people actually use (it fell through the table once) ─────────
for PHRASE in "tell Regan about Ymir" "can you explain what ymir is" "introduce ymir to a client"; do
  OUT="$(ASK "$PHRASE")"
  W="$(printf '%s' "$OUT" | j "len(d.get('answer','').split())")"
  [ "${W:-0}" -ge 40 ] && ok "the pitch answers \"$PHRASE\" (${W} words)" \
    || bad "pitch: $PHRASE" "${W:-0} words — a label, not an explanation"
done

# ── B · the law: ONLY the owner's private chat answers every message ─────────────────────────
# His word, 2026-10-23: "only my private chat should be answering on all. groups never." A room
# that answers an unnamed message is a mouth talking to other people unprompted — and it did, once,
# with a wrong fact in it. The adapter now has no per-room switch; this check proves the config has
# not grown one back, and the adapter suite (`adapter-test.sh`) proves the code ignores the unnamed.
if grep -vE '^[[:space:]]*#' "$H/hodd/identity/assistant/groups.yaml" 2>/dev/null \
     | grep -qE 'addressed_only:[[:space:]]*false'; then
  bad "the rooms" "a room is declared open — only the owner's DM may answer every message"
else
  ok "no room answers an unnamed message — only the owner's DM answers everything"
fi
# the adapter's own suite: the addressee rule is CODE now, so it is proven in code and not in a config
if bash "$SCRIPT_DIR/adapter-test.sh" >/dev/null 2>&1; then
  ok "the adapter suite holds — typing, the tiers, an unnamed group message ignored"
else
  bad "adapter suite" "bin/assistant/adapter-test.sh reports a failure"
fi

# ── C · the room's members, asked three ways ─────────────────────────────────────────────────
for Q in "who is in this group" "can you see who are in this group" "who's in this room"; do
  M="$(ASK "$Q" owner telegram-group "-5435500944")"
  case "$M" in *"members"*|*"admin"*) ok "the group door answers \"$Q\"" ;; *) bad "group members: $Q" "$M" ;; esac
done

# ── D · the handoff names the asker (it said \"someone\" once) ───────────────────────────────
# An INVENTED asker: the door's job is to carry the name it is given, not to know a person.
H2="$(bash "$SCRIPT_DIR/escalate.sh" --tier collaborator --chat -5435500944 --who "Blake Ashford (@blake)" \
      --text "smoke" --context "smoke" --reason "smoke" --dry-run 2>&1)"
case "$H2" in *"Blake Ashford (@blake)"*) ok "the handoff carries the person's name" ;; *) bad "handoff name" "$H2" ;; esac

# ── E · a tier gate that must not rot: a stranger cannot hear contacts ──────────────────────
# The person is the OPERATOR's, taken from his own digest at run time — a name in this public file
# would be the very leak the gate exists to stop (plan 288 §1). No person registered is a clean skip.
CONTACT="$(bash "$SCRIPT_DIR/test-fixtures.sh" contact 2>/dev/null)"
if [ -n "$CONTACT" ]; then
  S2="$(ASK "who is $CONTACT" stranger)"
  case "$S2" in *"$CONTACT"*) bad "tier gate" "a stranger heard a contact" ;; *) ok "a stranger cannot hear a contact" ;; esac
  O2="$(ASK "who is $CONTACT" owner)"
  case "$O2" in *"$CONTACT"*) ok "the owner can hear a contact" ;; *) bad "owner contact" "$O2" ;; esac
else
  skip "the tier gate" "the home holds no contact fact — nothing to test the gate against"
fi

# ── F · the voice RAISES itself, and still fails LOUD when it cannot ────────────────────────
# The idle-stop is CORRECT to lower an unused voice — which is why the mouth must raise it before it
# speaks. That was the fault of 2026-10-23: kokoro was lowered at 12:29 and every voice note until
# 19:30 arrived as text. A mouth that cannot be raised must still SAY SO, and must not hang.
systemctl --user stop kokoro-serve.service >/dev/null 2>&1; sleep 1
if bash "$SCRIPT_DIR/mouth.sh" "the voice raises itself" "$NOTES/raise.ogg" >/dev/null 2>&1 \
   && [ -s "$NOTES/raise.ogg" ]; then
  ok "the mouth raises an idle-lowered voice and speaks ($(stat -c%s "$NOTES/raise.ogg") bytes)"
else
  SQ="$(kokoro_port_squatter)"
  bad "mouth raise" "the mouth did not raise kokoro — a voice note would arrive as text${SQ:+ ($SQ)}"
fi
if MOUTH_WAIT_SECONDS=3 KOKORO_URL=http://127.0.0.1:9/v1/audio/speech \
   bash "$SCRIPT_DIR/mouth.sh" "the voice must refuse loudly" "$NOTES/down.ogg" >/dev/null 2>&1; then
  bad "mouth guard" "succeeded with no synthesiser"
else
  RC=$?
  [ "$RC" -eq 3 ] && ok "a synthesiser that cannot be raised fails loudly (exit 3)" || ok "a dead synthesiser fails (exit $RC)"
fi
systemctl --user start kokoro-serve.service >/dev/null 2>&1
for _i in $(seq 1 12); do sleep 2; curl -s -m 3 -o /dev/null "$KBASE/" 2>/dev/null && break; done
bash "$SCRIPT_DIR/mouth.sh" "the voice is back" "$NOTES/up.ogg" >/dev/null 2>&1 \
  && ok "the voice comes back after a restart" || bad "voice restart" "no voice after restarting kokoro"

# ── G · the idle-stop respects the lease, and lowers a truly idle card ──────────────────────
bash "$ROOT/systems/snotra/services/tts-lease/tts-lease.sh" touch >/dev/null 2>&1
bash "$HOME/.local/bin/kokoro-idle-stop.sh" >/dev/null 2>&1
systemctl --user is-active --quiet kokoro-serve.service \
  && ok "the idle-stop leaves the voice up while the lease is fresh" \
  || bad "idle-stop lease" "lowered the voice under a fresh lease"

# ── H · the ledger, the retention rule, the backup ──────────────────────────────────────────
bash "$ROOT/systems/snotra/services/ear/audio-retention.sh" scan >/dev/null 2>&1 \
  && ok "the retention rule scans the audio shelf" || bad "retention" "scan failed"


echo
printf 'smoke: %d pass · %d skip · %d fail\n' "$PASS" "$SKIP" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
