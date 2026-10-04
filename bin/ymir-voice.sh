#!/usr/bin/env bash
# ymir-voice.sh — the voice door (Plan 68 §8, plan 34's stack).
#
# THE ACCEPTANCE CRITERION, from the Allfather: full duplex, ALWAYS ON WHILE THE SESSION IS OPEN.
# The mic is never a button. You speak, VAD sees you stop, it answers IN AUDIO, you interrupt and it
# cuts off and listens again. Explicit activation only — one tap open, one tap close.
#
# WHAT THIS DOOR IS TODAY, measured on this box (2026-10-03):
#   ears   ~/whisper-dictate.sh  (whisper.cpp, CUDA, small.en)   PRESENT — but ONE-SHOT
#   mouth  ~/piper-speak.sh      (piper 1.8.0)                     PRESENT
#   pipe   ffmpeg · arecord · pw-record                            PRESENT
#   VAD    Silero                                                   ABSENT
#   loop   continuous capture -> streaming STT -> VAD -> brain -> streaming TTS  ABSENT
#
# So `speak`, `listen` and `status` work TODAY. `hold` — the actual criterion — REFUSES with a
# stated reason rather than pretending. That refusal is the honest state of the work, and it is the
# first thing a session should have to fix.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${HOME}"
PIPER="$HOME_DIR/piper-speak.sh"
WHISPER="$HOME_DIR/whisper-dictate.sh"

have() { command -v "$1" >/dev/null 2>&1 || [ -x "$2" ]; }

case "${1:-status}" in
  status)
    printf 'ymir_voice[5]{part,present,note}:\n'
    printf '  "ears (whisper.cpp)","%s","%s"\n' \
      "$([ -x "$WHISPER" ] && echo yes || echo no)" "one-shot transcription; NOT streaming"
    printf '  "mouth (piper)","%s","%s"\n' \
      "$([ -x "$PIPER" ] && echo yes || echo no)" "present; faster than playback is the hard rule"
    printf '  "capture (arecord/pw-record)","%s","%s"\n' \
      "$(have arecord '' && echo yes || echo no)" "one-shot per turn, not a live stream"
    printf '  "vad (silero)","no","NOT PRESENT — the turn boundary is undecided"\n'
    printf '  "full-duplex loop","no","NOT BUILT — the acceptance criterion is unmet"\n'
    printf '\nhelp: ymir-voice.sh speak <text> | listen <wav> | status | hold\n'
    exit 0
    ;;

  speak)
    shift
    text="${*:-}"
    [ -n "$text" ] || { echo "ymir-voice: speak needs text" >&2; exit 1; }
    [ -x "$PIPER" ] || { echo "ymir-voice: no mouth — $PIPER is not executable" >&2; exit 1; }
    bash "$PIPER" "$text"
    ;;

  listen)
    shift
    wav="${1:-}"
    [ -f "$wav" ] || { echo "ymir-voice: listen needs an audio file (wav)" >&2; exit 1; }
    [ -x "$WHISPER" ] || { echo "ymir-voice: no ears — $WHISPER is not executable" >&2; exit 1; }
    bash "$WHISPER" "$wav"
    ;;

  hold)
    # The real criterion, stated as a refusal rather than faked. P2-P6 of plan 68.
    cat >&2 <<'MSG'
ymir-voice: hold is NOT BUILT — full duplex is not available yet.

What exists: the ears (whisper.cpp, one-shot), the mouth (piper), capture.
What is missing, in order:
  1 VAD — nothing decides that you have STOPPED speaking. Silero is not installed.
  2 the loop — continuous capture -> streaming STT -> VAD -> brain -> streaming TTS.
  3 the OVERLAP POLICY — the mic must stay OPEN while it speaks. Buffering makes every
    interruption cost a round trip, and the whole thing feels like 2019.
  4 barge-in — the audio must stop when speech is detected over it.

This door refuses rather than pretending, because a held-open silence that is not really
full duplex is worse than an honest refusal.
MSG
    exit 1
    ;;

  *)
    echo "usage: ymir-voice.sh status|speak <text>|listen <wav>|hold" >&2
    exit 1
    ;;
esac