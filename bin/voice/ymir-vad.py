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

WHERE THE WEIGHTS LIVE (plan 288 step 7, plan 287 P4). The detector is a DOWNLOAD, not source: it
    is fetched from a pinned upstream commit and checked against a pinned sha256 into the user's data
    folder, and it is never committed to the public repository. `bin/voice/voice-model-lib.sh` holds
    the one answer — where the weights live and what they must hash to — and this file resolves the
    same three environment variables in the same order, so the install door that fetches and the
    tool that loads cannot disagree (proved by bin/voice/tests/test_voice_vad_model.sh):

        YMIR_VAD_MODEL         one file override (wins outright)
        YMIR_VOICE_MODELS_DIR  the weights folder      (<data root>/models/voice)
        YMIR_RELEASES          the ymir data root      ($XDG_DATA_HOME/ymir → ~/.local/share/ymir)

Usage:
    ymir-vad.py selftest              # proves the model runs and discriminates
    ymir-vad.py watch <wav> [sr]      # per-second SPEECH/SILENCE over a file
    ymir-vad.py say  <wav> [sr]       # exit 0 if speech is present, 1 if only silence
    ymir-vad.py path                  # the file this tool will load (for a caller's own proof)
"""

from __future__ import annotations

import os
import sys
import wave
from pathlib import Path

WINDOW = 512  # Silero's frame size at 16 kHz — the ONNX graph declares this shape
VAD_NAME = "silero_vad.onnx"


def data_root() -> Path:
    """The ymir data root — the same default bin/engine/release.sh uses for releases/."""
    base = os.environ.get("YMIR_RELEASES") or os.path.join(
        os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share"),
        "ymir",
    )
    return Path(base)


def model_path() -> Path:
    """Where the detector lives — mirrors ymir_vad_model() in bin/voice/voice-model-lib.sh."""
    override = os.environ.get("YMIR_VAD_MODEL")
    if override:
        return Path(override)
    models = os.environ.get("YMIR_VOICE_MODELS_DIR")
    folder = Path(models) if models else data_root() / "models" / "voice"
    return folder / VAD_NAME


MODEL = model_path()


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
    # the file is judged BEFORE anything heavy is imported: a missing detector must read as a
    # missing detector, not as a ModuleNotFoundError from whichever package happens to be absent.
    if not MODEL.exists():
        print(f"ymir-vad: model missing at {MODEL}")
        print("ymir-vad: fetch it from its pinned upstream — bin/voice/voice-ensure.sh install")
        return 1
    import numpy as np

    session = load()
    state = np.zeros((2, 1, 128), dtype=np.float32)
    sr = 16000
    silence = np.zeros(WINDOW, dtype=np.float32)
    p_silence, _ = probability(session, silence, sr, state)

    ok = p_silence < 0.5
    verdict = "PASS" if ok else "FAIL"
    # `window_samples` was never defined here, so this selftest raised NameError the first time it was
    # ever run (2026-11-14). The row is now built from names that exist, and it states one row.
    print("vad_selftest[1]{file,window_samples,p_silence,verdict}:")
    print(f'  "{MODEL.name}","{WINDOW}","{p_silence:.4f}","{verdict}"')
    print("  note: silence must read BELOW threshold. A synthetic tone is NOT speech, so the")
    print("  YES-to-speech case needs a real recording (ymir-vad.py say <wav>) — not a fake pass.")
    return 0 if ok else 1


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 1
    mode = argv[1]
    if mode == "path":
        print(MODEL)
        return 0
    if mode == "selftest":
        return selftest()
    if mode in ("watch", "say"):
        if len(argv) < 3:
            print(f"ymir-vad: {mode} needs a wav file")
            return 1
        sr = int(argv[3]) if len(argv) > 3 else 16000
        if not MODEL.exists():
            print(f"ymir-vad: model missing at {MODEL}")
            print("ymir-vad: fetch it from its pinned upstream — bin/voice/voice-ensure.sh install")
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