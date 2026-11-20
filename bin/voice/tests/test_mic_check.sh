#!/usr/bin/env bash
# test_mic_check.sh — the level door tells a steady voice from a pumping one, and names its band.
# Fenced: nothing is recorded; the door only reads wav files written here into a throwaway folder.
set -u
SELF="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOOR="$SELF/../mic-check.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1 — want [$3] got [$2]"; fi; }

# one second per level, a 220 Hz tone: a steady voice, a pumping one (the gain control's swing), a quiet one, a clip
python3 - "$tmp" <<'PY'
import array, math, sys, wave
def write(path, levels_db):
    rate = 48000
    out = array.array("h")
    for db in levels_db:
        amp = 10 ** (db / 20) * math.sqrt(2)          # RMS of a sine is amp/sqrt(2)
        out.extend(int(max(-1, min(1, amp * math.sin(2 * math.pi * 220 * i / rate))) * 32767) for i in range(rate))
    w = wave.open(path, "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(out.tobytes()); w.close()
d = sys.argv[1]
write(f"{d}/steady.wav",  [-60, -26, -28, -27, -30, -60, -26, -29, -28])
write(f"{d}/pumping.wav", [-60, -14, -20, -27, -33, -38, -22, -30, -37])
write(f"{d}/quiet.wav",   [-60, -40, -41, -39, -42, -40])
write(f"{d}/clip.wav",    [-60, -3, -2, -3, -2])
PY

verdict() { bash "$DOOR" trace "$1" | tail -1 | sed 's/.*· //'; }
check "a steady voice is one band" "$(verdict "$tmp/steady.wav")" "steady — one band (good)"
check "a pumping voice is not steady" "$(verdict "$tmp/pumping.wav" | cut -c1-11)" "NOT steady "
check "a quiet voice is named quiet" "$(verdict "$tmp/quiet.wav")" "steady — one band (quiet)"
check "a clipped voice is named clip" "$(verdict "$tmp/clip.wav")" "steady — one band (clip)"
check "the spread is measured in dB" "$(bash "$DOOR" trace "$tmp/pumping.wav" | tail -1 | grep -oE 'spread [0-9]+ dB')" "spread 24 dB"
check "silence in the trace is shown, not judged" "$(bash "$DOOR" trace "$tmp/steady.wav" | tail -1 | grep -oE 'voiced [0-9]+ s')" "voiced 7 s"
bash "$DOOR" >/dev/null 2>&1; check "no verb is a usage error (exit 2)" "$?" "2"
bash "$DOOR" trace >/dev/null 2>&1; check "trace without a file is a usage error (exit 2)" "$?" "2"
echo "test_mic_check: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
