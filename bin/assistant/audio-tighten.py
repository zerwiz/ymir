#!/usr/bin/env python3
"""audio-tighten.py — close the short gaps a voice inserts INSIDE its words.

    python3 audio-tighten.py <in.wav> [<out.wav>] [--max-gap 0.12] [--keep 0.03] [--squeeze-all]

MEASURED 2026-10-22, af_nicole on this box: "the Allfather's assistant" took 1.83 s with four
silences *inside* the word "assistant", and a whole sentence carried 1.4 s of inserted silence in
5.2 s of audio. That is what the Allfather heard as "do n,,,, t" and "allfather .... s". No text can
fix it — the model puts the gaps there.

So the gaps are closed AFTER synthesis, and only the SHORT ones: a gap shorter than --max-gap is an
artefact of the voice and is squeezed to --keep; a longer gap is a natural pause between clauses and
is left alone. Nothing else about the audio changes: no resampling, no tempo change, no pitch shift.

Standard library only (wave + array), so it runs wherever the assistant runs.
"""
from __future__ import annotations

import array
import sys
import wave


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        return 2
    src = argv[1]
    dst = argv[2] if len(argv) > 2 and not argv[2].startswith("--") else src
    max_gap, keep = 0.12, 0.03
    squeeze_all = False
    for i, arg in enumerate(argv):
        if arg == "--max-gap" and i + 1 < len(argv):
            max_gap = float(argv[i + 1])
        if arg == "--keep" and i + 1 < len(argv):
            keep = float(argv[i + 1])
        if arg == "--squeeze-all":
            squeeze_all = True

    with wave.open(src, "rb") as fh:
        params = fh.getparams()
        raw = fh.readframes(fh.getnframes())
    width = params.sampwidth
    channels = params.nchannels
    rate = params.framerate
    if width not in (1, 2, 3, 4):
        return 0
    samples = array.array({1: "b", 2: "h", 3: "i", 4: "i"}[width])
    samples.frombytes(raw[: len(raw) - (len(raw) % (width * channels))])

    frame_count = len(samples) // channels
    # a frame is silent when every channel is under the floor
    floor = {1: 3, 2: 300, 3: 20000, 4: 20000}[width]

    def silent(i: int) -> bool:
        base = i * channels
        return all(abs(samples[base + c]) < floor for c in range(channels))

    max_frames = int(max_gap * rate)
    keep_frames = int(keep * rate)
    out = array.array(samples.typecode)
    i = 0
    changed = 0
    while i < frame_count:
        if not silent(i):
            base = i * channels
            out.extend(samples[base:base + channels])
            i += 1
            continue
        j = i
        while j < frame_count and silent(j):
            j += 1
        run = j - i
        # short run inside/between words: squeeze it. long run: a real pause, keep it.
        take = min(run, keep_frames) if squeeze_all else (run if run > max_frames else min(run, keep_frames))
        if take < run:
            changed += 1
        for k in range(take):
            base = (i + k) * channels
            out.extend(samples[base:base + channels])
        i = j

    with wave.open(dst, "wb") as fh:
        fh.setnchannels(channels)
        fh.setsampwidth(width)
        fh.setframerate(rate)
        fh.writeframes(out.tobytes())
    if changed:
        print(f"audio-tighten: closed {changed} short gap(s) — "
              f"{frame_count / rate:.2f}s -> {len(out) / channels / rate:.2f}s", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
