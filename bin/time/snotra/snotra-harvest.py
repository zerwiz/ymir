#!/usr/bin/env python3
"""snotra-harvest — take the meeting's OWN audio out of the bot's store, and prove it.

WHY THIS EXISTS
    The meeting bot (Vexa) records the meeting's own stream, and a per-frame capture log that carries
    a `speakerIndex` on every frame. Both live in the bot's store, and until this door existed NOTHING
    in Snotra reached them — so meeting folders held the room microphone (Rule 33's forbidden source)
    and no transcript at all. This is the door that ends that.

WHAT IT DOES
    status    <meeting-dir>            what the bot holds for this meeting, and what is staged here
    fetch     <meeting-dir> [--force]  pull the audio, verify it byte-for-byte, write harvest.json
    verify    <meeting-dir>            re-check the staged audio against the store's declaration
    speakers  <meeting-dir> [--force]  split the capture log by speakerIndex into one WAV per speaker
    signal    <meeting-dir> [--force]  pull the STT log and audit it — empty text at `ok:true` is FAILURE

WHERE THE BYTES GO (Rule 30 — the vault is not a media store)
    raw audio and the capture log go to a STAGING area outside the vault:
        ${XDG_STATE_HOME:-~/.local/state}/ymir/snotra-harvest/<meeting-folder>/
    the meeting folder in the vault receives only what is text today:
        harvest.json        the manifest (bytes, sha256, duration, session, transport)
        (later) transcript  written by the transcription step, never the audio
    so a 155 MB recording never enters a git repository, and the ladder has something to compress.

THE LAWS IT ENFORCES
    * the transport is the stack's own HTTP API (`GET /recordings/<id>/media/<file>/raw?type=audio`) —
      no docker-exec, no filesystem assumption; unreachable → it names the variable it needs;
    * a harvest is verified or it failed: the byte count must equal the store's `file_size_bytes`, and
      the sha256 is recorded;
    * nothing is deleted here. The retention ladder is a different door, and it may not run before a
      transcript is verified.

CONFIG (Rule 07 — env first, one documented default)
    VEXA_API_URL        default http://127.0.0.1:18080
    VEXA_USER_ID        default 1
    VEXA_S3_ENDPOINT    default http://127.0.0.1:18900
    VEXA_S3_BUCKET      default vexa
    VEXA_S3_ACCESS_KEY / VEXA_S3_SECRET_KEY   else MINIO_ACCESS_KEY / MINIO_SECRET_KEY from the
                                              deployed compose .env (found by the docker label)
    VEXA_COMPOSE_ENV    an explicit env file to read those two keys from
    SNOTRA_HARVEST_DIR  the staging root
"""
from __future__ import annotations

import base64
import hashlib
import json
import os
import re
import struct
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

API = os.environ.get("VEXA_API_URL", "http://127.0.0.1:18080").rstrip("/")
USER = os.environ.get("VEXA_USER_ID", "1")
S3_ENDPOINT = os.environ.get("VEXA_S3_ENDPOINT", "http://127.0.0.1:18900").rstrip("/")
S3_BUCKET = os.environ.get("VEXA_S3_BUCKET", "vexa")
HARVEST = "harvest.json"


def die(msg: str, code: int = 1):
    print(f"snotra-harvest: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


# ── staging, outside the vault ──────────────────────────────────────────────────────────────────
def stage_root() -> Path:
    env = os.environ.get("SNOTRA_HARVEST_DIR")
    if env:
        return Path(env).expanduser()
    state = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(state) / "ymir" / "snotra-harvest"


def stage_dir(d: Path) -> Path:
    p = stage_root() / d.name
    p.mkdir(parents=True, exist_ok=True)
    return p


# ── the meeting, resolved ───────────────────────────────────────────────────────────────────────
def record_of(d: Path) -> dict:
    p = d / "record.json"
    if not p.is_file():
        die(f"no record.json in {d} — the meeting has no record to harvest into")
    return json.loads(p.read_text(encoding="utf-8"))


def meet_code(rec: dict) -> str | None:
    """The Meet code is the join key between the vault's record and the bot's store."""
    url = (rec.get("meeting") or {}).get("conference_url") or ""
    m = re.search(r"meet\.google\.com/([a-z0-9]{3,4}-[a-z0-9]{3,4}-[a-z0-9]{3,4})", url or "")
    return m.group(1) if m else None


def api_json(path: str) -> dict:
    req = urllib.request.Request(API + path, headers={"X-User-Id": USER})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        die(f"the bot store answered {e.code} for {path} — check VEXA_API_URL/VEXA_USER_ID ({API})")
    except urllib.error.URLError as e:
        die(f"the bot store is unreachable at {API} ({e.reason}) — set VEXA_API_URL")
    return {}


def all_meetings() -> list[dict]:
    """Every meeting the bot store knows, paged — the API caps `limit` at 100."""
    out: list[dict] = []
    offset = 0
    while True:
        page = api_json(f"/meetings?limit=100&offset={offset}").get("meetings") or []
        out.extend(page)
        if len(page) < 100:
            return out
        offset += 100
        if offset > 10000:  # a runaway page loop is a fault, not a state
            die("the meeting list did not terminate after 10 000 rows — refusing to guess")


def bot_meeting(code: str, required: bool = True) -> dict | None:
    for m in all_meetings():
        if (m.get("native_meeting_id") or "") == code:
            return m
    if required:
        die(f"the bot never sat in {code} — no meeting in the store carries that code "
            "(nothing to harvest)")
    return None


def bot_recordings(meeting_id: int) -> list[dict]:
    """The list endpoint is a summary; the detail carries the session uid and the media files."""
    rows = api_json(f"/recordings?meeting_id={int(meeting_id)}").get("recordings", [])
    out = []
    for r in rows:
        rid = r.get("id")
        out.append(api_json(f"/recordings/{int(rid)}") if rid else r)
    return out


def audio_file(rec: dict) -> dict | None:
    for f in rec.get("media_files") or []:
        if f.get("type") == "audio":
            return f
    return None


def audio_url(rec_id: int, media_id: int) -> str:
    return f"{API}/recordings/{int(rec_id)}/media/{int(media_id)}/raw?type=audio"


# ── fetch + verify ──────────────────────────────────────────────────────────────────────────────
def download(url: str, dest: Path, expect_bytes: int | None) -> tuple[int, str]:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    h = hashlib.sha256()
    n = 0
    req = urllib.request.Request(url, headers={"X-User-Id": USER})
    try:
        with urllib.request.urlopen(req, timeout=60) as r, open(tmp, "wb") as out:
            while True:
                chunk = r.read(1 << 20)
                if not chunk:
                    break
                out.write(chunk)
                h.update(chunk)
                n += len(chunk)
    except urllib.error.HTTPError as e:
        tmp.unlink(missing_ok=True)
        die(f"the audio download answered {e.code} — the recording is not downloadable through this door")
    except urllib.error.URLError as e:
        tmp.unlink(missing_ok=True)
        die(f"the audio download failed: {e.reason}")
    if expect_bytes and n != expect_bytes:
        tmp.unlink(missing_ok=True)
        die(f"size mismatch: downloaded {n:,} B, the store declared {expect_bytes:,} B — the harvest is "
            "refused, not rounded")
    tmp.replace(dest)
    return n, h.hexdigest()


def probe(path: Path) -> dict:
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries",
             "format=duration:stream=codec_name,sample_rate,channels", "-of", "json", str(path)],
            capture_output=True, text=True, timeout=180)
        d = json.loads(out.stdout or "{}")
        dur = float((d.get("format") or {}).get("duration") or 0)
        st = (d.get("streams") or [{}])[0]
        meta = {"duration_s": round(dur, 1), "codec": st.get("codec_name"),
                "sample_rate": st.get("sample_rate"), "channels": st.get("channels")}
        if dur <= 0:
            meta["duration_s"] = decode_duration(path)
        return meta
    except Exception as e:  # noqa: BLE001 - a probe failure is reported, never guessed
        return {"error": str(e)}


def decode_duration(path: Path) -> float:
    """A live-stream container carries no duration header; the decode knows the truth.
    Reported as 0.0 with `duration_source: 'unmeasurable'` if the decode also cannot say."""
    try:
        out = subprocess.run(
            ["ffmpeg", "-nostdin", "-v", "error", "-stats", "-i", str(path), "-f", "null", "-"],
            capture_output=True, text=True, timeout=1800)
        times = re.findall(r"time=(\d+):(\d+):(\d+(?:\.\d+)?)", out.stderr or "")
        if not times:
            return 0.0
        h, m, s = times[-1]
        return round(int(h) * 3600 + int(m) * 60 + float(s), 1)
    except Exception:  # noqa: BLE001
        return 0.0


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def harvest(d: Path, force: bool = False) -> dict:
    rec = record_of(d)
    code = meet_code(rec)
    if not code:
        die("the record carries no Google Meet link — there is no join key to the bot's store")
    bm = bot_meeting(code)
    recs = bot_recordings(bm["id"])
    if not recs:
        die(f"the bot joined {code} (meeting {bm['id']}) and the store holds no recording for it")
    recs.sort(key=lambda r: r.get("created_at") or "")
    chosen = [r for r in recs if r.get("status") == "completed"] or recs
    r = chosen[-1]
    f = audio_file(r)
    if not f:
        die(f"recording {r['id']} has no audio media file")
    expect = int(f.get("file_size_bytes") or 0)
    stage = stage_dir(d)
    dest = stage / "bot.webm"
    manifest_p = d / HARVEST
    if manifest_p.is_file() and not force:
        prev = json.loads(manifest_p.read_text(encoding="utf-8"))
        if dest.is_file() and prev.get("bytes") == dest.stat().st_size and prev.get("sha256"):
            say(f"harvest{{already:'yes',file:{dest},bytes:{prev['bytes']}}}")
            return prev
    say(f"harvest{{meeting:{bm['id']},code:{code},recording:{r['id']},media:{f['id']},"
        f"declared_bytes:{expect}}}")
    n, sha = download(audio_url(r["id"], f["id"]), dest, expect)
    meta = probe(dest)
    manifest = {
        "harvested_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "transport": "http",
        "api": API,
        "bot_meeting_id": bm["id"],
        "native_meeting_id": code,
        "recording_id": r["id"],
        "session_uid": r.get("session_uid") or (r.get("data") or {}).get("session_uid"),
        "media_file_id": f["id"],
        "stage": str(stage),
        "file": str(dest),
        "bytes": n,
        "declared_bytes": expect,
        "sha256": sha,
        "codec": meta.get("codec"),
        "sample_rate": meta.get("sample_rate"),
        "channels": meta.get("channels"),
        "duration_s": meta.get("duration_s"),
        "source": "bot",
        "is_meeting_stream": True,
        "chunks": f.get("chunk_count"),
    }
    manifest_p.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    say(f"staged{{file:{dest},bytes:{n},duration_s:{manifest['duration_s']},sha256:{sha[:12]}…}}")
    return manifest


def verify(d: Path) -> int:
    mp = d / HARVEST
    if not mp.is_file():
        die("nothing harvested here — run fetch first", 2)
    m = json.loads(mp.read_text(encoding="utf-8"))
    p = Path(m["file"])
    if not p.is_file():
        die(f"the staged audio is gone: {p} — fetch it again (the ladder may have moved it)")
    n = p.stat().st_size
    sha = sha256_of(p)
    # after the ladder the manifest names the compressed file; the store's declaration is provenance,
    # so it is reported beside the check rather than compared with a file it no longer describes.
    compressed = bool(m.get("compressed")) or p.suffix == ".opus"
    ok_size = n == m["bytes"] and (compressed or n == m.get("declared_bytes"))
    ok_sha = sha == m["sha256"]
    meta = probe(p)
    say(f"verify{{file:{p.name},bytes:{n},manifest_bytes:{m['bytes']},"
        f"store_declared:{m.get('raw_declared_bytes') or m.get('declared_bytes')},"
        f"compressed:{str(compressed).lower()},size_ok:{str(ok_size).lower()},"
        f"sha_ok:{str(ok_sha).lower()},duration_s:{meta.get('duration_s')}}}")
    return 0 if (ok_size and ok_sha) else 1


# ── the bot's S3 store: the capture log and the STT log ────────────────────────────────────────
def compose_env_file() -> Path | None:
    p = os.environ.get("VEXA_COMPOSE_ENV")
    if p:
        return Path(p)
    try:
        out = subprocess.run(
            ["docker", "inspect", "vexa-v012-meeting-api-1",
             "--format", '{{index .Config.Labels "com.docker.compose.project.working_dir"}}'],
            capture_output=True, text=True, timeout=15)
        wd = (out.stdout or "").strip()
        if wd:
            for cand in (Path(wd) / ".env", Path(wd).parent / ".env"):
                if cand.is_file():
                    return cand
    except Exception:  # noqa: BLE001 - probing may fail; the caller names what is missing
        return None
    return None


def s3_creds() -> tuple[str, str]:
    ak = os.environ.get("VEXA_S3_ACCESS_KEY") or os.environ.get("MINIO_ACCESS_KEY")
    sk = os.environ.get("VEXA_S3_SECRET_KEY") or os.environ.get("MINIO_SECRET_KEY")
    if ak and sk:
        return ak, sk
    envf = compose_env_file()
    if envf and envf.is_file():
        vals: dict[str, str] = {}
        for line in envf.read_text(encoding="utf-8", errors="replace").splitlines():
            m = re.match(r"^([A-Z0-9_]+)=(.*)$", line.strip())
            if m:
                vals[m.group(1)] = m.group(2).strip().strip('"').strip("'")
        ak = vals.get("MINIO_ACCESS_KEY") or vals.get("VEXA_S3_ACCESS_KEY")
        sk = vals.get("MINIO_SECRET_KEY") or vals.get("VEXA_S3_SECRET_KEY")
        if ak and sk:
            return ak, sk
    die("no storage credentials: set VEXA_S3_ACCESS_KEY/VEXA_S3_SECRET_KEY, or VEXA_COMPOSE_ENV to the "
        "deployed compose .env (it carries MINIO_ACCESS_KEY/MINIO_SECRET_KEY)")


def s3():
    try:
        import boto3  # noqa: PLC0415 - optional dependency, named when missing
        from botocore.config import Config  # noqa: PLC0415
    except Exception:  # noqa: BLE001
        die("boto3 is missing: pip install boto3 (the capture log lives in the bot's S3 store)")
    ak, sk = s3_creds()
    return boto3.client("s3", endpoint_url=S3_ENDPOINT, aws_access_key_id=ak, aws_secret_access_key=sk,
                        region_name="us-east-1",
                        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}))


def s3_get(key: str, dest: Path) -> Path:
    say(f"s3{{bucket:{S3_BUCKET},key:{key}}}")
    try:
        s3().download_file(S3_BUCKET, key, str(dest))
    except Exception as e:  # noqa: BLE001
        die(f"not readable at s3://{S3_BUCKET}/{key} — {e}")
    return dest


def wav_write(path: Path, pcm: bytes, rate: int = 16000):
    data_bytes = len(pcm)
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + data_bytes) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, rate, rate * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", data_bytes))
        f.write(pcm)


def speakers(d: Path, force: bool = False) -> int:
    """Split the capture log by speakerIndex — the bot's per-frame speaker labels become tracks."""
    mp = d / HARVEST
    if not mp.is_file():
        die("nothing harvested here — run fetch first", 2)
    m = json.loads(mp.read_text(encoding="utf-8"))
    if not m.get("session_uid"):
        die("the harvest manifest carries no session_uid — the capture log cannot be located")
    stage = stage_dir(d)
    src = stage / "signal.jsonl"
    if not src.is_file() or force:
        s3_get(f"signal/1/{m['bot_meeting_id']}/{m['session_uid']}/captured-signal.jsonl", src)
    outdir = stage / "speakers"
    outdir.mkdir(parents=True, exist_ok=True)
    rate = 16000
    tracks: dict[int, list[bytes]] = {}
    spans: dict[int, dict] = {}
    header = None
    frames = 0
    with open(src, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            if o.get("type") == "captured_signal_header":
                header = o
                continue
            si, pcm = o.get("speakerIndex"), o.get("pcm")
            if si is None or not pcm:
                continue
            raw = base64.b64decode(pcm)
            tracks.setdefault(int(si), []).append(raw)
            s = spans.setdefault(int(si), {"first_ts": o.get("ts"), "last_ts": o.get("ts"), "frames": 0})
            s["last_ts"] = o.get("ts")
            s["frames"] += 1
            frames += 1
    if not tracks:
        die("the capture log holds no pcm frames — nothing to split (is this the right session?)")
    manifest = {"at": datetime.now(timezone.utc).isoformat(timespec="seconds"), "source": str(src),
                "header": header or {}, "frames": frames, "tracks": {}}
    for si, blobs in sorted(tracks.items()):
        pcm = b"".join(blobs)
        p = outdir / f"speaker-{si:02d}.wav"
        wav_write(p, pcm, rate)
        secs = round(len(pcm) / 2 / rate, 1)
        s = spans[si]
        manifest["tracks"][f"speaker-{si:02d}"] = {
            "speaker_index": si, "file": str(p), "bytes": len(pcm), "seconds": secs,
            "frames": s["frames"], "first_ts": s["first_ts"], "last_ts": s["last_ts"],
        }
        say(f"track{{speaker:{si},seconds:{secs},frames:{s['frames']},file:{p.name}}}")
    (outdir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    say(f"speakers{{tracks:{len(tracks)},frames:{frames},manifest:{outdir / 'manifest.json'}}}")
    return 0


def stt_audit(d: Path, force: bool = False) -> int:
    """T9 — an STT call that returns `ok:true` and no words is a FAILURE, not a success."""
    mp = d / HARVEST
    if not mp.is_file():
        die("nothing harvested here — run fetch first", 2)
    m = json.loads(mp.read_text(encoding="utf-8"))
    stage = stage_dir(d)
    out = stage / "stt.jsonl"
    if not out.is_file() or force:
        s3_get(f"signal/1/{m['bot_meeting_id']}/{m['session_uid']}/stt.jsonl", out)
    total = ok = empty = withtext = 0
    with open(out, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            total += 1
            if o.get("ok"):
                ok += 1
                if (o.get("text") or "").strip():
                    withtext += 1
                else:
                    empty += 1
    say(f"stt_audit{{calls:{total},ok:{ok},with_text:{withtext},empty_text:{empty},file:{out}}}")
    if empty:
        say(f"FAIL — {empty} transcription call(s) reported ok and produced no words; that is why this "
            "meeting has no transcript (T9). A silent success is a defect, not a state.")
        return 1
    return 0


def status(d: Path) -> int:
    rec = record_of(d)
    code = meet_code(rec)
    stage = stage_root() / d.name
    local = "none"
    mp = d / HARVEST
    if mp.is_file():
        m = json.loads(mp.read_text(encoding="utf-8"))
        local = f"{m['file']} ({m['bytes']:,} B, {m.get('duration_s')} s)"
    say(f"local{{audio:{local},stage:{stage}}}")
    if not code:
        say("join_key{none:the record has no Meet link}")
        return 0
    # A store that cannot be reached is NOT "the bot never sat here": the two are reported apart.
    bm = bot_meeting(code, required=False)
    if bm is None:
        say(f"store{{meeting:'none for {code}'}}")
        return 0
    for r in bot_recordings(bm["id"]):
        f = audio_file(r) or {}
        say(f"store{{meeting:{bm['id']},code:{code},recording:{r['id']},status:{r.get('status')},"
            f"bytes:{f.get('file_size_bytes')},chunks:{f.get('chunk_count')},"
            f"session:{r.get('session_uid')}}}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]
    d = Path(argv[2] if len(argv) > 2 else "").expanduser().resolve()
    force = "--force" in argv
    if cmd in ("status", "fetch", "verify", "speakers", "signal") and not d.is_dir():
        die(f"no meeting folder at {d}")
    if cmd == "status":
        return status(d)
    if cmd == "fetch":
        harvest(d, force)
        return 0
    if cmd == "verify":
        return verify(d)
    if cmd == "speakers":
        return speakers(d, force)
    if cmd == "signal":
        return stt_audit(d, force)
    die(f"unknown command {cmd!r} — status | fetch | verify | speakers | signal", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
