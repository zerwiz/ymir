#!/usr/bin/env python3
"""
ymir-vad.py — R1, the TURN BOUNDARY (Plan 68 §12, stage R1).

The video's architecture says nothing starts until you can answer one question: *has the human
stopped talking?* There is no turn without it, and every later stage — streaming STT, first-sentence
TTS, barge-in — hangs off this decision. So it is built first, alone, and tested alone.

WHY ONNX AND NOT `pip install silero-vad`:
    pip's silero-vad drags in TORCH, which installs CUDA bindings into the engine venv. This host
    runs ONE resident model on one card and shares VRAM with the rail (plan 68 §10). Adding a
    second CUDA stack to get a 2 MB detector would work and would quietly make the memory situation
    worse for everything else. Silero ships the same detector as a single ONNX file; onnxruntime
    runs it on CPU with no torch at all.

    verified on this host: onnxruntime 1.30.0, silero_vad.onnx 2.3 MB, loads on CPUExecutionProvider,
    inputs ['input','state','sr'], outputs ['output','stateN'].

Usage:
    ymir-vad.py selftest              # proves the model runs and discriminates
    ymir-vad.py watch <wav> [sr]      # per-second SPEECH/SILENCE over a file
    ymir-vad.py say  <wav> [sr]       # exit 0 if speech is present, 1 if only silence
"""

from __future__ import annotations

import sys
import wave
from pathlib import Path

MODEL = Path(__file__).resolve().parent.parent / ".fleet" / "voice" / "silero_vad.onnx"
WINDOW = 512  # Silero's frame size at 16 kHz — the ONNX graph declares this shape


def load():
    import onnxruntime as ort

    opts = ort.SessionOptions()
    opts.inter_op_num_threads = 1
    opts.intra_op_num_threads = 1
    return ort.InferenceSession(str(MODEL), sess_options=opts, providers=["CPUExecutionProvider"])


def pcm16(path: str, target_sr: int = 16000):
    """Read a wav as mono int16 at `target_sr`. ffmpeg does the resample; we never guess rates."""
    import subprocess
    import tempfile

    with tempfile.NamedTemporaryFile(suffix=".raw", delete=False) as tmp:
        raw = tmp.name
    subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(target_sr), "-f", "s16le", raw],
        check=True,
    )
    data = Path(raw).read_bytes()
    Path(raw).unlink(missing_ok=True)
    import numpy as np

    return np.frombuffer(data, dtype=np.int16)


def probability(session, frames, sr: int, state):
    """One window in, one speech probability out. This is the whole of R1."""
    import numpy as np

    out, stateN = session.run(None, {"input": np.asarray(frames, dtype=np.float32).reshape(1, -1),
                                        "state": state, "sr": np.array(sr, dtype=np.int64)})
    return float(out[0].reshape(-1)[0]), stateN


def watch(session, samples, sr: int, threshold: float = 0.5):
    """Yield (second, probability, speaking) — the per-second verdict the turn logic will use."""
    import numpy as np

    state = np.zeros((2, 1, 128), dtype=np.float32)
    per_sec = sr
    for second in range(len(samples) // per_sec):
        chunk = samples[second * per_sec:(second + 1) * per_sec]
        best = 0.0
        for i in range(0, len(chunk) - WINDOW, WINDOW):
            p, state = probability(session, chunk[i:i + WINDOW].astype(np.float32), sr, state)
            best = max(best, p)
        yield second, best, best >= threshold


def selftest() -> int:
    """Prove the model RUNS and that it says NO to silence. The YES-to-speech case needs a real
    recording — a synthetic tone is not speech, and pretending otherwise is how a gate ends up
    reporting green while measuring nothing."""
    import numpy as np

    session = load()
    state = np.zeros((2, 1, 128), dtype=np.float32)
    sr = 16000
    silence = np.zeros(WINDOW, dtype=np.float32)
    p_silence, _ = probability(session, silence, sr, state)

    ok = p_silence < 0.5
    print(f"vad_selftest[3]{MODEL.name,window_samples,p_silence,verdict}:")
    print(f'  "{MODEL.name}","{WINDOW}","{p_silence:.4f}","{"PASS" if ok else "FAIL"}"')
    print("  note: silence must read BELOW threshold. A synthetic tone is NOT speech, so the")
    print("  YES-to-speech case needs a real recording (ymir-vad.py say <wav>) — not a fake pass.")
    return 0 if ok else 1


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 1
    mode = argv[1]
    if mode == "selftest":
        return selftest()
    if mode in ("watch", "say"):
        if len(argv) < 3:
            print(f"ymir-vad: {mode} needs a wav file")
            return 1
        sr = int(argv[3]) if len(argv) > 3 else 16000
        if not MODEL.exists():
            print(f"ymir-vad: model missing at {MODEL}")
            return 1
        session = load()
        samples = pcm16(argv[2], sr)
        if mode == "say":
            _, _, spoke = max(watch(session, samples, sr), key=lambda r: r[1])
            print("speech" if spoke else "silence")
            return 0 if spoke else 1
        for second, p, speaking in watch(session, samples, sr):
            print(f'  {second:>4}s  p={p:.3f}  {"SPEECH" if speaking else "silence"}')
        return 0
    print(f"ymir-vad: unknown mode {mode}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))