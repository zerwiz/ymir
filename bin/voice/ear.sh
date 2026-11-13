#!/usr/bin/env bash
# ear.sh — turn a recording into words, with whichever engine this machine has.
#
# WHY (the Allfather, 2026-11-13): a voice note arrived and the house was deaf. `voice-door.sh status` said
# "engine ABSENT" because it looked for a whisper BINARY, and this seat has none — it has python. A door that
# only knows one road reports a capability absent while the machine can already do the work.
#
# Two roads, probed in order, and the one that answers is named:
#   1 · whisper-cli (whisper.cpp) — the fast local binary, when a seat has it;
#   2 · faster-whisper in python — installed with `python3 -m pip install --user faster-whisper` and pinned
#       with `av==13.1.0` (pyav 19 dropped `metadata_errors`, which faster-whisper still passes).
#
# Usage: ear.sh <audio-file> [--model base|small|medium] [--json]
# Exit: 0 words printed · 1 no engine (named) · 2 usage · 3 the file has NO AUDIO (measured, not guessed).
set -uo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SELF_DIR/../.." && pwd)"
FILE="${1-}"; shift || true
MODEL="base"; JSON=0
while [ $# -gt 0 ]; do case "$1" in --model) MODEL="${2:-base}"; shift 2;; --json) JSON=1; shift;; *) shift;; esac; done
[ -n "$FILE" ] && [ -r "$FILE" ] || { printf 'usage: ear.sh <audio-file> [--model base|small|medium] [--json]\n' >&2; exit 2; }

# road 1 · the binary
BIN="${SNOTRA_WHISPER_BIN:-$(command -v whisper-cli 2>/dev/null || true)}"
MODEL_FILE="${SNOTRA_WHISPER_MODEL:-${HOME}/whisper.cpp/models/ggml-${MODEL}.bin}"
if [ -n "$BIN" ] && [ -x "$BIN" ] && [ -f "$MODEL_FILE" ]; then
  out="$("$BIN" -m "$MODEL_FILE" -f "$FILE" -nt 2>/dev/null | sed '/^\[/d' | tr '\n' ' ' | sed 's/  */ /g')"
  [ -n "${out// /}" ] && { printf 'ear[3]{engine,model,text}:\n  "whisper-cli","%s","%s"\n' "$MODEL" "$out"; exit 0; }
fi

# road 2 · python
if python3 -c "import faster_whisper" 2>/dev/null; then
  python3 - "$FILE" "$MODEL" "$JSON" <<'PY'
import sys
path, model, as_json = sys.argv[1], sys.argv[2], sys.argv[3] == '1'
import numpy as np
from faster_whisper import WhisperModel
from faster_whisper.audio import decode_audio
a = decode_audio(path, sampling_rate=16000)
rms = float(np.sqrt(np.mean(a**2))) if a.size else 0.0
if rms == 0.0:
    print("ear[1]{engine,verdict}:\n  \"faster-whisper\",\"NO AUDIO — the file decodes to silence (rms 0), so there is nothing to hear\"")
    raise SystemExit(3)
m = WhisperModel(model, device="cpu", compute_type="int8")
segs, info = m.transcribe(a, vad_filter=True, beam_size=5)
text = " ".join(s.text.strip() for s in segs).strip()
if as_json:
    import json; print(json.dumps({"engine":"faster-whisper","model":model,"language":info.language,"duration":info.duration,"text":text}))
else:
    print(f'ear[4]{{engine,model,language,text}}:\n  "faster-whisper","{model}","{info.language}","{text}"')
PY
  exit $?
fi

printf 'ear[1]{verdict,remedy}:\n  "no engine","install one: whisper-cli with a model, or python3 -m pip install --user faster-whisper (av==13.1.0)"\n' >&2
exit 1
