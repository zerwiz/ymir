#!/usr/bin/env python3
"""snotra-transcribe-bot — the meeting's own audio becomes the record's text.

WHY: the harvest brings the bot's audio to the staging shelf, but the transcript was made by hand with
whisper.cpp and a shell one-liner. An unattended pipeline cannot carry a hand-built step. This door is that
step, and it names its engine, its model and its span so the transcript can be trusted later.

WHAT IT DOES
    run     <meeting-dir> [--force] [--model M]   transcribe the staged audio into evidence/bot/
    status  <meeting-dir>                         is there a transcript, from which audio, with how many words

THE LAWS
    * the source must be the MEETING's audio (harvest.json, `is_meeting_stream: true`) — a room microphone
      is refused (Rule 33), and the harvest's own flag is the evidence;
    * the output is never rewritten over a newer transcript unless `--force` says so;
    * it writes what it did: `evidence/bot/transcribe.json` — engine, model, seconds of audio, words, sha256
      of the audio it read;
    * empty output is a FAILURE, not a transcript (8 191 silent successes taught that lesson).
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_MODEL = os.environ.get("SNOTRA_WHISPER_MODEL", str(Path.home() / "whisper.cpp/models/ggml-small.en.bin"))
MIN_WORDS = 50


def die(msg: str, code: int = 1):
    print(f"snotra-transcribe-bot: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def whisper_bin() -> Path:
    for cand in (Path.home() / "whisper.cpp.src/build/bin/whisper-cli",
                 Path.home() / "whisper.cpp/build/bin/whisper-cli"):
        if cand.is_file():
            return cand
    die("whisper-cli not found — build whisper.cpp or set SNOTRA_WHISPER (bin/agents/eir-doctor.sh whisper)")


def load_manifest(d: Path) -> dict:
    p = d / "harvest.json"
    if not p.is_file():
        die("no harvest.json — run snotra-harvest.sh fetch first (there is no audio to transcribe)", 2)
    m = json.loads(p.read_text(encoding="utf-8"))
    if not m.get("is_meeting_stream"):
        die("refused: this harvest does not declare `is_meeting_stream: true` — a room microphone is never "
            "the record (Rule 33)")
    return m


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def decode_duration(p: Path) -> float:
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                        "-of", "default=nw=1:nk=1", str(p)], capture_output=True, text=True)
    try:
        d = float((r.stdout or "0").strip() or 0)
    except ValueError:
        d = 0.0
    if d > 0:
        return d
    r = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-stats", "-i", str(p), "-f", "null", "-"],
                       capture_output=True, text=True, timeout=3600)
    times = re.findall(r"time=(\d+):(\d+):(\d+(?:\.\d+)?)", r.stderr or "")
    if not times:
        return 0.0
    h, m, s = times[-1]
    return int(h) * 3600 + int(m) * 60 + float(s)


def status(d: Path) -> int:
    mp = d / "transcribe.json"
    if not (d / "evidence" / "bot").is_dir():
        say("transcript{none:'no evidence/bot'}")
        return 1
    if not mp.is_file():
        txt = d / "evidence" / "bot" / "transcript.bot.txt"
        if txt.is_file():
            say(f"transcript{{file:evidence/bot/{txt.name},words:{len(txt.read_text().split())},"
                f"meta:'missing transcribe.json (made by hand)'}}")
            return 0
        say("transcript{none:true}")
        return 1
    t = json.loads(mp.read_text(encoding="utf-8"))
    say(f"transcript{{file:{t['text']},words:{t['words']},model:{Path(t['model']).name},"
        f"audio_s:{t['audio_seconds']}}}")
    return 0


def run(d: Path, force: bool, model: str) -> int:
    m = load_manifest(d)
    audio = Path(m["file"])
    if not audio.is_file():
        die(f"the staged audio is gone: {audio} — harvest it again")
    outdir = d / "evidence" / "bot"
    outdir.mkdir(parents=True, exist_ok=True)
    txt = outdir / "transcript.bot.txt"
    meta = outdir / "transcribe.json"
    if txt.is_file() and not force and meta.is_file():
        prev = json.loads(meta.read_text(encoding="utf-8"))
        if prev.get("audio_sha256") == sha256(audio):
            say(f"transcript{{already:'yes',words:{prev.get('words')}}}")
            return 0
    # A WAV is what whisper.cpp wants; the harvest keeps webm/opus, so decode to 16 kHz mono first — and
    # the decode lives on the STAGING shelf, never in the vault: 2 h 50 min of 16 kHz mono is 327 MB, and a
    # git repository is not a scratch disk (measured 2026-10-23 — the first run put it in evidence/bot/).
    stage = Path(m.get("stage") or os.environ.get("SNOTRA_HARVEST_DIR") or outdir)
    stage.mkdir(parents=True, exist_ok=True)
    wav = stage / "bot-16k-mono.wav"
    if not wav.is_file() or force:
        r = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(audio), "-vn",
                            "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", str(wav)],
                           capture_output=True, text=True, timeout=7200)
        if r.returncode != 0:
            die(f"the decode failed: {(r.stderr or '').strip()[:200]}")
    secs = decode_duration(wav)
    base = outdir / "transcript.bot"
    r = subprocess.run([str(whisper_bin()), "-m", model, "-f", str(wav), "-l", "en", "-t", "8",
                        "-oj", "-osrt", "-otxt", "-of", str(base)], capture_output=True, text=True)
    if r.returncode != 0:
        die(f"whisper failed ({r.returncode}): {(r.stderr or '')[-300:]}")
    words = len(txt.read_text(encoding="utf-8", errors="replace").split()) if txt.is_file() else 0
    if words < MIN_WORDS:
        die(f"the transcript holds {words} words — that is a failure, not a record (8 191 silent "
            "successes taught this house that lesson)")
    record = {"at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
              "engine": "whisper.cpp", "model": model, "text": f"evidence/bot/{txt.name}",
              "srt": f"evidence/bot/{base.name}.srt", "audio": str(audio),
              "audio_sha256": sha256(audio), "audio_seconds": round(secs, 1), "words": words,
              "source": m.get("source"), "is_meeting_stream": True}
    meta.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    say(f"transcript{{written:'evidence/bot/{txt.name}',words:{words},audio_s:{record['audio_seconds']},"
        f"model:{Path(model).name}}}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd, d = argv[1], Path(argv[2]).expanduser().resolve()
    if not d.is_dir():
        die(f"no meeting folder at {d}")
    if cmd == "status":
        return status(d)
    if cmd == "run":
        model = DEFAULT_MODEL
        for i, a in enumerate(argv):
            if a == "--model" and i + 1 < len(argv):
                model = argv[i + 1]
        if not Path(model).is_file():
            die(f"no whisper model at {model} — set SNOTRA_WHISPER_MODEL")
        return run(d, "--force" in argv, model)
    die(f"unknown command {cmd!r} — run | status", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
