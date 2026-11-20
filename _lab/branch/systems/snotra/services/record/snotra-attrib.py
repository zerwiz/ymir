#!/usr/bin/env python3
"""snotra-attrib — who said it: the track, the person, and the evidence for both.

WHY: the bot records the meeting's own audio with a `speakerIndex` per frame. That is *how many* voices there
were — three, on 2026-10-22 — and not *whose*. So all fourteen decisions of that meeting read `decided_by: null`
and every letter says "proposed", because the house could not honestly name the speaker. The Allfather's rule:
**we must know who says what.** This is the door that carries that knowledge, and refuses to invent it.

WHAT IT DOES
    list    <meeting-dir>                     each track: seconds, a spoken sample, and whether it is named
    sample  <meeting-dir> [--seconds N]       transcribe a short probe of each track so a person can recognise the voice
    set     <meeting-dir> <track> "<name>" --by "<who confirms>" [--why "…"]
    check   <meeting-dir>                     for every decision/action/question: which track spoke at its evidence time
    apply   <meeting-dir> --by "<name>"       write the attribution into the record: decided_by + attribution{}
    show    <meeting-dir>                     the map, appended-only

HOW THE TRACK IS CHOSEN FOR A QUOTE
    The capture log carries `{ts, speakerIndex}` per frame. A decision's evidence has `timestamp` ("00:04:36")
    relative to the recording start. The door finds the frames around that instant (±4 s), takes the speaker with
    the most frames, and reports the vote (e.g. `speaker-00 7/9 frames`). A tie or a gap is reported as `unclear`
    and is NEVER attributed.

THE LAWS
    * a **person** names a speaker: `--by "<name>"` is required, and the mapping is appended to `speakers.jsonl`
      — an index re-assigned is a new line, so a correction never erases who said it before;
    * a **track** is evidence, not identity: naming `speaker-01` "Craig Martin" is a claim the operator makes from
      a sample, and the claim records who made it and when;
    * `apply` writes `decided_by` only where the vote is clear; every other decision keeps `decided_by: null` and
      an `attribution.status: unclear` with the reason — an honest unknown beats a plausible name (Rule 33).
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

MINORITY_GAP = 4.0   # seconds either side of a quote used for the vote
CLEAR_RATIO = 0.6    # the winner must hold this share of the frames, or the answer is "unclear"


def die(msg: str, code: int = 1):
    print(f"snotra-attrib: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def stage_of(d: Path) -> Path:
    root = os.environ.get("SNOTRA_HARVEST_DIR")
    if root:
        return Path(root).expanduser() / d.name
    state = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(state) / "ymir" / "snotra-harvest" / d.name


def load_map(d: Path) -> dict:
    p = d / "speakers.json"
    if p.is_file():
        return json.loads(p.read_text(encoding="utf-8"))
    return {"tracks": {}, "confirmed_by": None}


def save_map(d: Path, m: dict) -> None:
    (d / "speakers.json").write_text(json.dumps(m, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def append_map(d: Path, entry: dict) -> None:
    with open(d / "speakers.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def frames(d: Path) -> list[dict]:
    """The capture log without its pcm: {ts, speakerIndex} — the attribution substrate."""
    p = stage_of(d) / "signal.meta.jsonl"
    if not p.is_file():
        p = stage_of(d) / "signal.jsonl"
    if not p.is_file():
        die(f"no capture log in {stage_of(d)} — run `snotra-harvest.sh speakers` first", 2)
    out = []
    with open(p, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            if o.get("type") == "captured_signal_header" or o.get("speakerIndex") is None:
                continue
            out.append({"ts": float(o.get("ts") or 0), "spk": int(o["speakerIndex"])})
    out.sort(key=lambda x: x["ts"])
    return out


def parse_clock(t: str) -> float:
    """'00:04:36' or '1:02:03.5' → seconds."""
    parts = [float(x) for x in re.findall(r"[\d.]+", t or "")]
    if not parts:
        return -1.0
    sec = 0.0
    for x in parts:
        sec = sec * 60 + x
    return sec


def vote(fr: list[dict], at_s: float) -> tuple[int | None, int, int, str]:
    """The speaker at an instant: (index, votes, total, note). A gap or a tie is 'unclear'."""
    if not fr:
        return None, 0, 0, "no frames"
    t0 = fr[0]["ts"] / 1000.0 if fr[0]["ts"] > 1e11 else fr[0]["ts"]
    base = t0 if t0 > 1e9 else 0.0
    target = base + at_s
    win = [f for f in fr if abs(f["ts"] / 1000.0 - target) <= MINORITY_GAP]
    if not win:
        return None, 0, 0, "no frames within ±4 s (the quote is outside the capture)"
    counts: dict[int, int] = {}
    for f in win:
        counts[f["spk"]] = counts.get(f["spk"], 0) + 1
    best = max(counts.items(), key=lambda kv: kv[1])
    total = sum(counts.values())
    if len(counts) > 1 and best[1] / total < CLEAR_RATIO:
        return None, best[1], total, f"unclear — {best[0]} holds {best[1]}/{total}"
    return best[0], best[1], total, f"{best[0]} holds {best[1]}/{total}"


def cmd_list(d: Path) -> int:
    m = load_map(d)
    man_p = stage_of(d) / "speakers" / "manifest.json"
    man = json.loads(man_p.read_text(encoding="utf-8")) if man_p.is_file() else {"tracks": {}}
    for key, t in sorted(man.get("tracks", {}).items()):
        named = (m["tracks"].get(key) or {}).get("name") or "—"
        say(f"track{{{key},seconds:{t['seconds']},frames:{t['frames']},name:{named}}}")
    say(f"map{{tracks:{len(man.get('tracks', {}))},named:{sum(1 for v in m['tracks'].values() if v.get('name'))},"
        f"confirmed_by:{(m.get('confirmed_by') or 'nobody')}}}")
    return 0


def cmd_sample(d: Path, seconds: int) -> int:
    """A short probe per track, so a person can recognise the voice. 12 s at the track's busiest stretch."""
    man_p = stage_of(d) / "speakers" / "manifest.json"
    if not man_p.is_file():
        die("no speaker manifest — run `snotra-harvest.sh speakers` first", 2)
    man = json.loads(man_p.read_text(encoding="utf-8"))
    whisper = None
    for c in (Path.home() / "whisper.cpp.src/build/bin/whisper-cli", Path.home() / "whisper.cpp/build/bin/whisper-cli"):
        if c.is_file():
            whisper = c
            break
    model = os.environ.get("SNOTRA_WHISPER_MODEL", str(Path.home() / "whisper.cpp/models/ggml-small.en.bin"))
    for key, t in sorted(man.get("tracks", {}).items()):
        wav = Path(t["file"])
        if not wav.is_file():
            say(f"sample{{track:{key},state:'audio gone — re-run harvest speakers'}}")
            continue
        # the FIRST seconds of a track are often a prefix of noise; seek into the middle of the speech
        total = float(t.get("seconds") or 0)
        start = max(0.0, total * 0.4)
        probe = stage_of(d) / "speakers" / f"{key}-probe.wav"
        subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-ss", f"{start:.1f}", "-i", str(wav),
                        "-t", str(seconds), "-ar", "16000", "-ac", "1", str(probe)],
                       capture_output=True, text=True, timeout=300)
        text = ""
        if whisper and Path(model).is_file():
            r = subprocess.run([str(whisper), "-m", model, "-f", str(probe), "-l", "en", "-nt", "--no-prints"],
                               capture_output=True, text=True, timeout=600)
            text = " ".join((r.stdout or "").split())[:180]
        say(f"sample{{track:{key},at:{(start if 'start' in dir() else 0):.0f}s,seconds:{seconds},text:{text!r}}}")
    return 0


def cmd_set(d: Path, track: str, name: str) -> int:
    by = why = None
    for i, a in enumerate(sys.argv):
        if a == "--by" and i + 1 < len(sys.argv):
            by = sys.argv[i + 1]
        if a == "--why" and i + 1 < len(sys.argv):
            why = sys.argv[i + 1]
    if not by:
        die("refused: naming a voice is a person's claim — `--by \"<name>\"` (the door records who said so)")
    if not re.match(r"^speaker-\d{2}$", track):
        die(f"unknown track {track!r} — the names look like speaker-00, speaker-01 …", 2)
    m = load_map(d)
    prev = (m["tracks"].get(track) or {}).get("name")
    entry = {"at": datetime.now(timezone.utc).isoformat(timespec="seconds"), "track": track,
             "from": prev, "to": name, "by": by, "why": why}
    append_map(d, entry)
    m["tracks"][track] = {"name": name, "by": by, "at": entry["at"]}
    m["confirmed_by"] = by
    save_map(d, m)
    say(f"named{{track:{track},from:{prev},to:{name},by:{by}}}")
    return 0


def cmd_check(d: Path, apply: bool = False, by: str | None = None) -> int:
    rec = json.loads((d / "record.json").read_text(encoding="utf-8"))
    m = load_map(d)
    fr = frames(d)
    rows = []
    for kind in ("decisions", "actions", "questions"):
        for x in rec.get(kind) or []:
            iid = x.get("decision_id") or x.get("action_id") or x.get("question_id")
            ev = x.get("evidence") or {}
            at = parse_clock(ev.get("timestamp") or "")
            spk, v, total, note = vote(fr, at) if at >= 0 else (None, 0, 0, "no timestamp in the evidence")
            track = f"speaker-{spk:02d}" if spk is not None else None
            name = (m["tracks"].get(track) or {}).get("name") if track else None
            rows.append({"id": iid, "kind": kind[:-1], "at": ev.get("timestamp"), "track": track,
                         "name": name, "note": note, "item": x})
    clear = sum(1 for r in rows if r["name"])
    for r in rows:
        say(f"attrib{{id:{r['id']},at:{r['at']},track:{r['track'] or '—'},name:{r['name'] or '—'},"
            f"vote:{r['note']!r}}}")
    say(f"attribution{{items:{len(rows)},clear_track:{sum(1 for r in rows if r['track'])},"
        f"named:{clear},unnamed:{len(rows) - clear}}}")
    if not apply:
        return 0
    if not by:
        die("refused: writing attribution names the person who confirmed the map — `--by \"<name>\"`", 2)
    n = 0
    for r in rows:
        x = r["item"]
        if r["name"]:
            x["decided_by"] = r["name"] if r["kind"] == "decision" else x.get("decided_by")
            x["attribution"] = {"status": "confirmed", "how": f"track {r['track']} named by the operator",
                                "vote": r["note"], "confirmed_by": by, "track": r["track"]}
        else:
            x["attribution"] = {"status": "unclear", "why": r["note"]}
            if r["kind"] == "decision":
                x["decided_by"] = None
        n += 1
    (d / "record.json").write_text(json.dumps(rec, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    back = json.loads((d / "record.json").read_text(encoding="utf-8"))
    wrote = sum(1 for k in ("decisions", "actions", "questions") for x in back.get(k) or []
                if (x.get("attribution") or {}).get("status") == "confirmed")
    say(f"applied{{items:{n},confirmed:{wrote},by:{by}}}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd, d = argv[1], Path(argv[2]).expanduser().resolve()
    if not (d / "record.json").is_file():
        die(f"no record.json in {d}")
    if cmd == "list":
        return cmd_list(d)
    if cmd == "sample":
        secs = 12
        for i, a in enumerate(argv):
            if a == "--seconds" and i + 1 < len(argv):
                secs = int(argv[i + 1])
        return cmd_sample(d, secs)
    if cmd == "set":
        if len(argv) < 5:
            die("usage: set <meeting-dir> speaker-00 \"Name\" --by \"<who confirms>\" [--why '…']", 2)
        return cmd_set(d, argv[3], argv[4])
    if cmd == "check":
        return cmd_check(d)
    if cmd == "apply":
        by = None
        for i, a in enumerate(sys.argv):
            if a == "--by" and i + 1 < len(sys.argv):
                by = sys.argv[i + 1]
        return cmd_check(d, apply=True, by=by)
    die(f"unknown command {cmd!r} — list | sample | set | check | apply", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
