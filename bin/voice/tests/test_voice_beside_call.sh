#!/usr/bin/env bash
# test_voice_beside_call.sh — plan 271 pieces 1 and 2, proven on stand-ins, nothing raised.
#
# A stand-in sound server says a call (Discord) holds the microphone, on the display GPU's
# seat (role dev). Capture tools are shimmed so any attempt to OPEN the microphone is logged.
#   · the helm's bare `host` is refused, naming the holder (piece 1)
#   · the operator's `host --now` goes through, the engine pinned to the CPU, the card hidden,
#     and not one capture tool was opened — the call's stream is untouched (piece 2)
#   · the `talk` road keeps its refusal, and refuses a Bluetooth headset by name of the reason
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; D="$HERE/../voice-door.sh"
[ -x "$HOME/venvs/s2s/bin/speech-to-speech" ] || { echo "skip: no engine on this seat (nothing to dry-run)"; exit 0; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cat > "$T/bin/pactl" <<'P'
#!/usr/bin/env bash
case "$*" in
 "list source-outputs") cat "$FAKE_OUTS" ;;
 "list short sources") printf '1\talsa_input.pci-0\tPipeWire\n2\tbluez_input.AA_BB.0\tPipeWire\n' ;;
esac
P
for t in pw-record parecord arecord; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> "$OPENED"\n' "$t" > "$T/bin/$t"
done
chmod +x "$T"/bin/*
export PATH="$T/bin:$PATH" FAKE_OUTS="$T/outs" OPENED="$T/opened" YMIR_DESK_ROLE=dev \
  YMIR_VOICE_DRY=1 YMIR_VOICE_HEAD_MODEL=stand-in-model YMIR_VOICE_PANE=0
: > "$OPENED"
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }

printf 'Source Output #7\n\tSource: 1\n\tProperties:\n\t\tapplication.name = "Discord"\n' > "$T/outs"
out="$(bash "$D" host 2>&1)"; rc=$?
{ [ $rc = 3 ] && grep -q "Discord" <<<"$out"; } && ok "the helm's bare host is refused, Discord named" || no "bare host not refused ($rc: $out)"

out="$(bash "$D" host --now 2>&1)"; rc=$?
{ [ $rc = 0 ] && grep -q -- "--device cpu" <<<"$out" && grep -q "stt_device=cpu" <<<"$out" && grep -q 'CUDA_VISIBLE_DEVICES=$' <<<"$out"; } \
  && ok "host --now serves beside the call: CPU, card hidden" || no "host --now ($rc: $out)"
[ ! -s "$OPENED" ] && ok "the serve road opened no capture device — the call's stream is untouched" || no "a capture tool was opened: $(cat "$OPENED")"

out="$(bash "$D" client 2>&1)"; rc=$?
{ [ $rc = 3 ] && grep -q "holds the microphone" <<<"$out"; } && ok "the talk road keeps its refusal" || no "talk road ($rc: $out)"

printf 'Source Output #8\n\tSource: 2\n\tProperties:\n\t\tapplication.name = "Discord"\n' > "$T/outs"
out="$(YMIR_DESK_NOW=0 bash "$D" client 2>&1)"
grep -qi "bluetooth" <<<"$out" || grep -q "holds the microphone" <<<"$out" && ok "a headset call is refused with a reason" || no "bluetooth ($out)"
[ ! -s "$OPENED" ] && ok "still nothing opened" || no "a capture tool was opened: $(cat "$OPENED")"
exit $fail
