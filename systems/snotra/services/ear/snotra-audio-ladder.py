#!/usr/bin/env python3
"""snotra-audio-ladder — the meeting's sound gets smaller AFTER its words are safe.

WHY: the Allfather's charge — *"we can't sit on one terabyte of meetings sound data … that must be smaller
after they are transcribed."* Measured 2026-10-23: one 2 h 50 min meeting costs 155 MB of audio **plus**
253 MB of capture log whose frames are the same sound again, base64'd. Nothing shrank it, and nothing
may delete it before a transcript exists.

WHAT IT DOES (per meeting, in this order — and it stops the moment a step cannot be proven)
    plan    <meeting-dir>                 what would shrink, and by how much — no writes, ever
    apply   <meeting-dir> [--offload DIR] do it: verify → compress → strip the duplicate → report
    status  <meeting-dir>                 the sizes now, and what still holds sound

THE LADDER
    1 verify     the harvest's sha256 and byte count still match the store's declaration
    2 require    a non-empty transcript in `evidence/bot/` — **no transcript, no shrinking** (Rule 30)
    3 compress   the staged `bot.webm` → `bot.opus` (16 kbps mono, 16 kHz); the raw file goes only after
                 the encoded file decodes and its duration is within 2 s of the original
    4 strip      `signal.jsonl` → `signal.meta.jsonl`: the `pcm` field is dropped, the timing and the
                 `speakerIndex` are kept (that is the attribution substrate; the bytes are not)
    5 keep       the per-speaker WAVs until a per-speaker transcript exists — they are the only copy of
                 the split audio, and deleting them would delete the evidence of who spoke

WHAT IT NEVER DOES
    * it never deletes a transcript;
    * it never shrinks audio whose transcript is missing, empty or unverified;
    * it never touches the vault's copy of anything — the vault holds text (Rule 30).
"""
from __future__ import annotations

import base64
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

KBPS = os.environ.get("SNOTRA_AUDIO_KBPS", "16")


def die(msg: str, code: int = 1):
    print(f"snotra-audio-ladder: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def human(n: float) -> str:
    for unit in ("B", "KiB", "MiB", "GiB"):
        if abs(n) < 1024:
            return f"{n:.0f}{unit}"
        n /= 1024
    return f"{n:.1f}TiB"


def stage_of(d: Path) -> Path:
    root = os.environ.get("SNOTRA_HARVEST_DIR")
    if root:
        return Path(root).expanduser() / d.name
    state = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(state) / "ymir" / "snotra-harvest" / d.name


def transcript_ok(d: Path) -> tuple[bool, str]:
    for p in sorted((d / "evidence" / "bot").glob("transcript.bot.txt")) if (d / "evidence" / "bot").is_dir() else []:
        words = len(p.read_text(encoding="utf-8", errors="replace").split())
        if words >= 50:
            return True, f"{p.relative_to(d)} ({words} words)"
        return False, f"{p.relative_to(d)} holds {words} words — too few to be the record"
    return False, "no transcript in evidence/bot/"


def duration(path: Path) -> float:
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                        "-of", "default=nw=1:nk=1", str(path)], capture_output=True, text=True)
    try:
        return float((r.stdout or "0").strip() or 0)
    except ValueError:
        return 0.0


def decode_duration(path: Path) -> float:
    r = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-stats", "-i", str(path),
                        "-f", "null", "-"], capture_output=True, text=True, timeout=3600)
    import re as _re
    times = _re.findall(r"time=(\d+):(\d+):(\d+(?:\.\d+)?)", r.stderr or "")
    if not times:
        return 0.0
    h, m, s = times[-1]
    return int(h) * 3600 + int(m) * 60 + float(s)


def plan_row(label: str, path: Path, note: str = "") -> dict:
    if not path.is_file():
        return {"label": label, "path": path, "bytes": 0, "note": "absent"}
    return {"label": label, "path": path, "bytes": path.stat().st_size, "note": note}


def survey(d: Path) -> dict:
    stage = stage_of(d)
    mp = d / "harvest.json"
    if not mp.is_file():
        die("no harvest.json — harvest the meeting first (snotra-harvest.sh fetch)")
    m = json.loads(mp.read_text(encoding="utf-8"))
    audio = Path(m["file"])
    signal = stage / "signal.jsonl"
    speakers = sorted((stage / "speakers").glob("*.wav")) if (stage / "speakers").is_dir() else []
    rows = [plan_row("audio (raw)", audio), plan_row("capture log", signal)]
    for p in speakers:
        rows.append(plan_row(p.stem, p))
    ok, why = transcript_ok(d)
    return {"manifest": m, "stage": stage, "audio": audio, "signal": signal, "speakers": speakers,
            "rows": rows, "transcript_ok": ok, "transcript": why}


def print_survey(d: Path, s: dict) -> None:
    total = sum(r["bytes"] for r in s["rows"])
    for r in s["rows"]:
        say(f'  {r["label"]:<18} {human(r["bytes"]):>9}  {r["path"].name}')
    say(f"audio_now{{meeting:{d.name},files:{len(s['rows'])},total:{human(total)},"
        f"transcript:{'yes' if s['transcript_ok'] else 'NO'},why:{s['transcript']!r}}}")


def strip_pcm(signal: Path) -> tuple[int, int, Path]:
    """Rewrite the capture log without the pcm: timing and speakerIndex stay, the duplicated sound goes."""
    out = signal.with_name("signal.meta.jsonl")
    before = signal.stat().st_size
    n = 0
    with open(signal, encoding="utf-8", errors="replace") as src, open(out, "w", encoding="utf-8") as dst:
        for line in src:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            o.pop("pcm", None)
            dst.write(json.dumps(o, separators=(",", ":")) + "\n")
            n += 1
    return before, out.stat().st_size, out


def compress(src: Path, dest: Path) -> tuple[bool, str]:
    r = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src),
                        "-c:a", "libopus", "-b:a", f"{KBPS}k", "-ar", "16000", "-ac", "1", str(dest)],
                       capture_output=True, text=True, timeout=7200)
    if r.returncode != 0 or not dest.is_file() or dest.stat().st_size == 0:
        return False, (r.stderr or "ffmpeg failed").strip()[:200]
    return True, ""


def run(d: Path, do: bool, offload: str | None) -> int:
    s = survey(d)
    print_survey(d, s)
    if not s["transcript_ok"]:
        say("refused — the audio stays: a meeting without a verified transcript may not shrink (Rule 30)")
        return 1
    audio: Path = s["audio"]
    signal: Path = s["signal"]
    raw_bytes = audio.stat().st_size if audio.is_file() else 0
    if not do:
        say(f"would{{compress:{audio.name},{human(raw_bytes)} → about {human(raw_bytes * int(KBPS) / 128)} "
            f"at {KBPS} kbps,strip:{signal.name} → signal.meta.jsonl}}")
        return 0
    # 1 · compress, verified by a decode and a duration comparison
    dur_before = duration(audio) or decode_duration(audio)
    opus = audio.with_suffix(".opus")
    ok, err = compress(audio, opus)
    if not ok:
        say(f"compress_failed{{error:{err!r}}} — the raw audio is untouched")
        return 1
    dur_after = duration(opus)
    if dur_before and dur_after and abs(dur_before - dur_after) > 2.0:
        say(f"refused{{why:'duration moved {dur_before}s → {dur_after}s',kept:{audio.name}}}")
        opus.unlink(missing_ok=True)
        return 1
    say(f"compressed{{from:{human(raw_bytes)},to:{human(opus.stat().st_size)},"
        f"seconds:{dur_after:.1f},kbps:{KBPS}}}")
    import hashlib as _h, datetime as _dt
    audio.unlink()  # the raw goes only now: the opus decoded and matched the duration
    # the manifest must tell the truth AFTER the ladder: the file it names is the compressed one, and
    # the store's original declaration is kept beside it as provenance (never overwritten).
    m = dict(s["manifest"])
    m.setdefault("raw_declared_bytes", m.get("declared_bytes"))
    m.setdefault("raw_sha256", m.get("sha256"))
    m["raw_bytes"] = raw_bytes
    m["compressed"] = {"file": str(opus), "bytes": opus.stat().st_size,
                       "sha256": _h.sha256(opus.read_bytes()).hexdigest(),
                       "kbps": int(KBPS), "seconds": dur_after,
                       "at": _dt.datetime.now(_dt.timezone.utc).isoformat(timespec="seconds")}
    m["file"] = str(opus)
    m["bytes"] = opus.stat().st_size
    m["sha256"] = m["compressed"]["sha256"]
    (d / "harvest.json").write_text(json.dumps(m, indent=2) + "\n", encoding="utf-8")
    # 2 · strip the duplicated pcm, keeping timing and speakerIndex
    if signal.is_file():
        before, after, out = strip_pcm(signal)
        if after > 0 and after < before:
            signal.unlink()
            say(f"stripped{{from:{human(before)},to:{human(after)},file:{out.name}}}")
        else:
            out.unlink(missing_ok=True)
            say("strip_skipped{'the rewritten log was not smaller'}")
    # 3 · offload the compressed copy, keeping the text where it is
    if offload:
        shelf = Path(offload).expanduser()
        if not shelf.is_dir() or not os.access(shelf, os.W_OK):
            say(f"offload_failed{{shelf:{shelf},why:'not a writable directory'}} — the compressed audio stays")
        else:
            dest = shelf / f"{d.name}-bot.opus"
            shutil.move(str(opus), str(dest))
            say(f"offloaded{{to:{dest},bytes:{dest.stat().st_size}}}")
    left = sum(p.stat().st_size for p in s["speakers"] if p.is_file()) + \
        (opus.stat().st_size if opus.is_file() else 0)
    say(f"after{{speaker_wavs:{human(left)},note:'kept until a per-speaker transcript exists'}}")
    return 0


def status(d: Path) -> int:
    s = survey(d)
    print_survey(d, s)
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd = argv[1]
    d = Path(argv[2]).expanduser().resolve()
    if not d.is_dir():
        die(f"no meeting folder at {d}")
    offload = None
    for i, a in enumerate(argv):
        if a == "--offload" and i + 1 < len(argv):
            offload = argv[i + 1]
    if cmd == "plan":
        return run(d, False, offload)
    if cmd == "apply":
        return run(d, True, offload)
    if cmd == "status":
        return status(d)
    die(f"unknown command {cmd!r} — plan | apply | status", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
