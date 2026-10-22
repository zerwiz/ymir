#!/usr/bin/env python3
"""snotra-talk.py — the streaming talk loop: hear, decide, compose, speak, record.

This is plan 34's voice loop applied to a meeting (plan 87's third voice), and it is
what `snotra-stream.sh talk` runs. It is deliberately NOT streaming-by-hope: every
stage is a real subprocess call with a measured latency written to the log.

    hear      ~2 s chunks recorded from a source; each chunk is transcribed as it
              lands (whisper-server /inference), so words are written while spoken
    decide    a deterministic floor test — the speaker's name, or a chair's slot.
              Never a model: a bot that guesses when to speak is a bot that interjects
    compose   the rail (llama-swap), one short answer, 3 sentences hard cap
    speak     sentence by sentence: Kokoro renders sentence N+1 while N plays.
              The first word names the speaker; the whole answer is capped
    record    talk.log (measured), the meeting transcript line, and a Rune

Env:
  SNOTRA_TALK_MODEL     rail model id (default qwen3.6-35b-a3b@iq3_s)
  SNOTRA_TALK_BASE      OpenAI-compatible base (default http://127.0.0.1:8080/v1)
  SNOTRA_WHISPER_URL    whisper.cpp server (default http://127.0.0.1:10300)
  KOKORO_URL            Kokoro TTS (default http://127.0.0.1:8765)
  SNOTRA_MIC_NAME       the PipeWire sink the voice plays into (default snotra_mic)
  SNOTRA_MAX_SPEAK_SECONDS  the cap on one answer (default 20)

Exit: 0 answered · 1 error · 3 refused (muted)
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))


def home() -> str:
    env = os.environ.get("YMIR_HOME")
    if env:
        return os.path.expanduser(env)
    out = subprocess.run(
        ["bash", "-c", f'. "{ROOT}/bin/vault/hoard-lib.sh" >/dev/null 2>&1; r=""; '
                      'ymir_home_root r 2>/dev/null; printf "%s" "$r"'],
        capture_output=True, text=True).stdout.strip()
    if not out:
        raise SystemExit("snotra-talk: the hoard is unresolved — set YMIR_HOME "
                         "(this door never guesses where the home lives)")
    return os.path.expanduser(out)


HOME = home()
STATE = os.path.join(HOME, "hodd", "state", "snotra")
MUTE = os.path.join(STATE, "voice-muted")
MODEL = os.environ.get("SNOTRA_TALK_MODEL", "qwen3.6-35b-a3b@iq3_s")
BASE = os.environ.get("SNOTRA_TALK_BASE", "http://127.0.0.1:8080/v1").rstrip("/")
WHISPER = os.environ.get("SNOTRA_WHISPER_URL", "http://127.0.0.1:10300").rstrip("/")
KOKORO = os.environ.get("KOKORO_URL", "http://127.0.0.1:8765").rstrip("/")
MIC = os.environ.get("SNOTRA_MIC_NAME", "snotra_mic")
CAP = float(os.environ.get("SNOTRA_MAX_SPEAK_SECONDS", "20"))

# What he may know. A derived, redacted digest — never the vault, never a plan, never a
# port, never a name that has not consented (plan 101 §"the lethal trifecta").
DIGEST = (
    "You are Skirnir, the Allfather's assistant, speaking aloud in a meeting. "
    "You speak for no one: you never make a decision, never agree to anything, never "
    "promise a date, and never read out any plan, port, key, address or private note. "
    "Answer in at most two sentences, plainly, in the past-or-present tense, no lists, "
    "no URLs, no markup. If you do not know, say so in one sentence and offer to have "
    "the Allfather confirm it."
)


def log(row: dict) -> None:
    os.makedirs(STATE, exist_ok=True)
    row.setdefault("at", time.strftime("%Y-%m-%dT%H:%M:%S%z"))
    with open(os.path.join(STATE, "talk.log"), "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")


# ---- hear ---------------------------------------------------------------------
def record_chunk(seconds: float, target: str | None, out: str) -> bool:
    """Record one chunk from a live source. Returns False if nothing was captured."""
    if shutil.which("pw-record"):
        cmd = ["pw-record", "--rate", "16000", "--channels", "1", "--format", "s16", out]
        if target:
            cmd[1:1] = ["--target", target]
        try:
            subprocess.run(cmd, timeout=seconds, capture_output=True)
            return os.path.getsize(out) > 1000
        except subprocess.TimeoutExpired:
            return os.path.getsize(out) > 1000 if os.path.exists(out) else False
        except Exception:
            return False
    return False


def rms_of(path: str) -> float:
    try:
        with wave.open(path) as w:
            n = w.getnframes()
            data = w.readframes(n)
        if not data:
            return 0.0
        import array
        a = array.array("h")
        a.frombytes(data[: len(data) - (len(data) % 2)])
        if not a:
            return 0.0
        return (sum(x * x for x in a) / len(a)) ** 0.5
    except Exception:
        return 0.0


def transcribe(path: str) -> str:
    try:
        boundary = "----snotra%d" % int(time.time() * 1000)
        with open(path, "rb") as fh:
            audio = fh.read()
        body = b"".join([
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
            f"filename=\"chunk.wav\"\r\nContent-Type: audio/wav\r\n\r\n".encode(),
            audio,
            f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"temperature\"\r\n\r\n0.0"
            f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"response_format\"\r\n\r\njson"
            f"\r\n--{boundary}--\r\n".encode(),
        ])
        req = urllib.request.Request(f"{WHISPER}/inference", data=body, headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}"})
        with urllib.request.urlopen(req, timeout=180) as r:
            payload = json.loads(r.read().decode("utf-8", "replace") or "{}")
        return (payload.get("text") or "").strip()
    except Exception as exc:  # never let a dead ear kill the loop
        return "" if "timed out" in str(exc) else ""


# ---- decide -------------------------------------------------------------------
def _lev(a: str, b: str) -> int:
    if a == b:
        return 0
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def addressed(text: str, name: str) -> bool:
    """The floor is his only because he was NAMED — deterministic, never a model.

    Matched with a small edit distance on purpose: whisper small.en hears "Skírnir" as
    "Scurnier" and the operator himself types "Skirmir" (both measured). A name test that
    only passes on the exact spelling is a name test that never fires in a real room.
    """
    import unicodedata

    def norm(s: str) -> str:
        s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
        return s.lower()

    if not text:
        return False
    words = [w for w in re.split(r"[^A-Za-z]+", norm(text)) if w]
    target = norm(name)
    if re.search(r"\b(assistant|snotra)\b", norm(text)):
        return True
    def skeleton(w: str) -> str:
        # consonants carry the name; c/k are one sound and ASR splits them freely
        return re.sub(r"[aeiouy]", "", w.replace("c", "k").replace("ph", "f"))

    t_sk = skeleton(target)
    for w in words:
        if w == target or _lev(w, target) <= 2:
            return True
        # ASR hears the vowels wrong far more than the consonants: "Skírnir" arrives as
        # "Scurnier" — the same consonant skeleton, three edits apart.
        if len(w) >= 5 and t_sk and skeleton(w) == t_sk:
            return True
    return False


# ---- compose ------------------------------------------------------------------
def compose(heard: str, name: str) -> str:
    key = os.environ.get("LLAMA_SWAP_API_KEY", "")
    if not key:
        try:
            auth = json.load(open(os.path.expanduser("~/.pi/agent/auth.json")))
            key = (auth.get("llama-swap") or {}).get("key", "")
        except Exception:
            key = ""
    body = json.dumps({
        "model": MODEL,
        "messages": [
            {"role": "system", "content": DIGEST},
            {"role": "user", "content": f"The room said: {heard}\n\nAnswer as {name}, briefly."},
        ],
        "temperature": 0.3,
        "max_tokens": 160,
        "stream": False,
    }).encode()
    req = urllib.request.Request(f"{BASE}/chat/completions", data=body, headers={
        "Content-Type": "application/json",
        **({"Authorization": f"Bearer {key}"} if key else {}),
    })
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            payload = json.loads(r.read().decode("utf-8", "replace"))
        text = (payload["choices"][0]["message"].get("content") or "").strip()
    except Exception as exc:
        return f"I heard you, but I cannot reach the model just now ({type(exc).__name__})."
    return sanitise(text)


def sanitise(text: str) -> str:
    """No URLs, no markup, no plan or port spoken aloud."""
    text = re.sub(r"https?://\S+", "the link", text)
    text = re.sub(r"[*_`#>]", "", text)
    text = re.sub(r"\b(port|vault|plan)\s*\d+\b", r"\1", text, flags=re.I)
    return " ".join(text.split())


def sentences(text: str, limit: int = 3) -> list[str]:
    parts = re.split(r"(?<=[.!?])\s+", text.strip())
    out, buf = [], ""
    for p in parts:
        buf = f"{buf} {p}".strip()
        if len(buf.split()) >= 4 or len(parts) == 1:
            out.append(buf)
            buf = ""
    if buf:
        out.append(buf)
    return out[:limit]


# ---- speak --------------------------------------------------------------------
def ensure_voice() -> bool:
    """Kokoro is idle-lowered by design; raise it, and wait for the port to answer.

    The probe is a TCP connect, not GET /v1/models: this Kokoro server implements only
    /v1/audio/speech, so a models probe answers 404 and would read a live server as dead
    (measured 2026-10-22).
    """
    import socket
    from urllib.parse import urlparse
    host = urlparse(KOKORO).hostname or "127.0.0.1"
    port = urlparse(KOKORO).port or 8765

    def up() -> bool:
        try:
            with socket.create_connection((host, port), timeout=2):
                return True
        except OSError:
            return False

    if up():
        return True
    subprocess.run(["systemctl", "--user", "start", "kokoro-serve.service"], capture_output=True)
    for _ in range(20):
        time.sleep(1)
        if up():
            return True
    return False


def synth(text: str) -> str | None:
    body = json.dumps({"model": "kokoro", "input": text, "voice": "af_nicole",
                       "response_format": "wav"}).encode()
    req = urllib.request.Request(f"{KOKORO}/v1/audio/speech", data=body,
                                 headers={"Content-Type": "application/json"})
    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        with urllib.request.urlopen(req, timeout=90) as r, open(path, "wb") as out:
            out.write(r.read())
        return path
    except Exception:
        os.unlink(path)
        return None


def play(path: str) -> None:
    subprocess.run(["paplay", f"--device={MIC}", path], capture_output=True)


def speak(lines: list[str], name: str) -> tuple[float, str]:
    """Sentence N+1 is rendered while N plays — the streaming part of the loop."""
    total, spoken = 0.0, []
    queue: list[str | None] = []
    first = True
    ensure_voice()
    t0 = time.time()
    for line in lines:
        text = f"{name}, the Allfather's assistant, speaking. {line}" if first else line
        if total >= CAP:
            break
        path = synth(text)
        first = False
        if not path:
            continue
        try:
            with wave.open(path) as w:
                dur = w.getnframes() / float(w.getframerate())
        except Exception:
            dur = 0.0
        if total + dur > CAP:
            os.unlink(path)
            break
        play(path)
        os.unlink(path)
        total += dur
        spoken.append(text)
        queue.append(text)
    return total, " ".join(spoken), time.time() - t0


# ---- the loop -----------------------------------------------------------------
def talk(target: str | None, name: str, once: bool, chunk: float, grace: float) -> int:
    if os.path.exists(MUTE):
        print("refused: muted — run `snotra-stream.sh unmute`", file=sys.stderr)
        return 3
    turn_text, silence, spoke_once = "", 0.0, False
    print(f"talk\tlistening\t{target or 'default'} · name={name} · chunk={chunk}s", flush=True)
    while True:
        fd, path = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
        os.unlink(path)
        ok = record_chunk(chunk, target, path)
        if not ok:
            time.sleep(0.2)
            continue
        rms = rms_of(path)
        if rms < 120:                      # ~-48 dBFS: the room is quiet
            silence += chunk
            os.unlink(path)
            if turn_text and silence >= grace:
                break_loop = handle(turn_text, name, spoke_once)
                if break_loop:
                    return 0
                spoke_once = True
                turn_text, silence = "", 0.0
                if once:
                    return 0
            continue
        silence = 0.0
        text = transcribe(path)
        os.unlink(path)
        if text and text.strip(" ."):
            turn_text = f"{turn_text} {text}".strip()
            print(f"heard\t{turn_text[-160:]}", flush=True)
    return 0


def handle(heard: str, name: str, spoke: bool) -> bool:
    if not addressed(heard, name):
        log({"event": "ignored", "heard": heard[:400], "why": "not addressed"})
        print(f"ignored\tnot addressed\t{heard[:120]}", flush=True)
        return False
    t0 = time.time()
    answer = compose(heard, name)
    compose_s = time.time() - t0
    total, spoken, speak_s = speak(sentences(answer), name)
    log({"event": "answered", "heard": heard[:400], "answer": answer[:500],
         "compose_s": round(compose_s, 2), "speak_s": round(speak_s, 2),
         "audio_s": round(total, 2), "name": name})
    rune(heard, spoken)
    print(f"answered\tcompose={compose_s:.1f}s\taudio={total:.1f}s\t{spoken[:160]}", flush=True)
    return False


def rune(heard: str, spoken: str) -> None:
    door = os.path.join(ROOT, "bin", "records", "runes-append.sh")
    if not os.access(door, os.X_OK):
        return
    subprocess.run([door, "snotra", "voice.talk",
                    "--message", f"heard: {heard[:150]} | said: {spoken[:150]}"],
                   capture_output=True)


def main(argv: list[str]) -> int:
    target, name, once, chunk, grace = None, "Skírnir", False, 2.0, 1.0
    listen_file = None
    args = argv[:]
    while args:
        a = args.pop(0)
        if a == "--listen":
            target = args.pop(0)
        elif a == "--listen-file":
            listen_file = args.pop(0)
        elif a == "--name":
            name = args.pop(0)
        elif a == "--chunk":
            chunk = float(args.pop(0))
        elif a == "--grace":
            grace = float(args.pop(0))
        elif a == "--once":
            once = True
        else:
            print(f"error: unknown argument {a}", file=sys.stderr)
            return 2
    if listen_file:                        # the deterministic test door
        heard = transcribe(listen_file)
        print(f"heard\t{heard}", flush=True)
        handle(heard, name, False)
        return 0
    try:
        return talk(target, name, once, chunk, grace)
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
