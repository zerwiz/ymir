#!/usr/bin/env bash
# test_vram_ledger.sh — the house can say who holds the card (plan 275 item 23).
#
# WHY: at 03:16 on 2026-11-14 the rail could not load its model and the chat had no words for
# it, because nothing in the house could say that Rödd's voice engine was holding 2,762 MiB of
# a 16 GiB card. `bin/model/vram-ledger.sh` is that answer, and this is its proof.
#
# The claims:
#   1. the holders are classified (voice / rail / other) and their MiB are summed;
#   2. `--busy-with-voice` says yes when the voice holds the card and the rail holds nothing;
#   3. the same door says no when a rail model is resident beside it;
#   4. a seat whose card cannot be read reports `known:false` WITH THE REASON — it never
#      invents a voice it cannot see;
#   5. the verdict line a person reads names the holder.
#
# A fake `nvidia-smi` stands in for the card; nothing on the machine is probed.
#
# Usage: test_vram_ledger.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/model/vram-ledger.sh"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

mkdir -p "$T/bin"
cat > "$T/bin/nvidia-smi" <<'SH'
#!/usr/bin/env bash
# fake nvidia-smi — the shapes the ledger asks for, from $FAKE_APPS / $FAKE_TOTAL / $FAKE_USED
case "$*" in
  -L) printf 'GPU 0: FAKE (UUID: GPU-fake)\n' ;;
  *query-gpu=memory.total*) printf '%s\n' "${FAKE_TOTAL:-16384}" ;;
  *query-gpu=memory.used*)  printf '%s\n' "${FAKE_USED:-3200}" ;;
  *query-compute-apps*)     printf '%s\n' "${FAKE_APPS:-}" ;;
  *) exit 0 ;;
esac
SH
chmod +x "$T/bin/nvidia-smi"

# ledger <verb> [VAR=value …] — the door's verb first, then any overrides
ledger() { local cmd="$1"; shift; local -a envs=() door=()
  for a in "$@"; do case "$a" in --*) door+=("$a") ;; *) envs+=("$a") ;; esac; done
  env -i HOME="$T" PATH="$T/bin:/usr/bin:/bin" ${envs[0]+"${envs[@]}"} bash "$DOOR" "$cmd" ${door[0]+"${door[@]}"}; }
APPS_VOICE=$'900001, /home/u/venvs/s2s/bin/speech-to-speech, 2762\n900002, /usr/bin/voxtype, 480'
APPS_BOTH=$'900001, /home/u/venvs/s2s/bin/speech-to-speech, 2762\n900003, /usr/local/bin/llama-server, 9200'

printf 'vram ledger — who holds the card\n'

out="$(ledger who FAKE_APPS="$APPS_VOICE" YMIR_VOICE_HOLD_MIB=1500 --json)"
if printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["known"] is True, d
assert d["voice_mib"]==2762, d
assert d["rail_mib"]==0, d
assert [h["who"] for h in d["holders"]]==["voice","other"], d
' 2>/dev/null; then ok "the holders are classified and the MiB summed"
else bad "the holders are classified" "$out"; fi

if ledger --busy-with-voice FAKE_APPS="$APPS_VOICE" YMIR_VOICE_HOLD_MIB=1500 >/dev/null 2>&1; then
  ok "--busy-with-voice says yes while the voice holds the card"
else bad "--busy-with-voice sees the voice holding the card"; fi

if ledger --busy-with-voice FAKE_APPS="$APPS_BOTH" YMIR_VOICE_HOLD_MIB=1500 >/dev/null 2>&1; then
  bad "--busy-with-voice says no when the rail holds a model" "(it said yes)"
else ok "--busy-with-voice says no when the rail holds a model"; fi

out="$(env -i HOME="$T" PATH=/nonexistent /bin/bash "$DOOR" who --json)"
if printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["known"] is False, d
assert d["reason"].strip(), d
' 2>/dev/null; then ok "a seat with no readable card says known:false, with the reason"
else bad "an unreadable card is reported honestly" "$out"; fi

out="$(ledger who FAKE_APPS="$APPS_VOICE" YMIR_VOICE_HOLD_MIB=1500 2>&1)"
if printf '%s' "$out" | grep -q 'the voice holds the card'; then
  ok "the verdict a person reads names the holder"
else bad "the verdict names the holder" "$out"; fi

printf 'vram ledger: %s ok / %s fail\n' "$pass" "$fail"
[ "$fail" = 0 ]
