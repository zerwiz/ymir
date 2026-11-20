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
CAP = float(os.environ.get("SNOTRA_MAX_SPEAK_SECONDS", "120"))
MAX_SENTENCES = int(os.environ.get("SNOTRA_MAX_SENTENCES", "8"))

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
MONITOR_STREAM = os.environ.get("SNOTRA_MONITOR_STREAM", "")
PAGE_PORT = int(os.environ.get("SNOTRA_PAGE_PORT", "0") or 0)
_PAGE = [None]


def page():
    """The seat browser as the meeting's mouth and ear (snotra-cdp.py).

    This is the path measured to work: getUserMedia in the page returns a stream we
    fill over CDP, and every remote track is teed back to us. PulseAudio is not in
    the loop at all — on this seat it reported success and carried silence.
    """
    if _PAGE[0] is not None:
        return _PAGE[0]
    if not PAGE_PORT:
        return None
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "snotra_cdp", os.path.join(HERE, "snotra-cdp.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    ws = mod.attach(PAGE_PORT)
    if not ws.js("!!window.__skirnir"):
        raise SystemExit("page bridge missing — run: snotra-meet.sh join")
    _PAGE[0] = (mod, ws)
    return _PAGE[0]


def page_ears(seconds: float, out: str) -> bool:
    """Take `seconds` of the ROOM from the page and write them as a wav."""
    import base64
    pair = page()
    if not pair:
        return False
    _, ws = pair
    time.sleep(seconds)
    got = ws.js("window.__skirnir.drain(0)") or {}
    pcm = base64.b64decode(got.get("b64") or "")
    if not pcm:
        return False
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(48000)
        w.writeframes(pcm)
    return True


def page_mouth(path: str) -> bool:
    """Push a wav into the page's microphone stream."""
    import base64
    pair = page()
    if not pair:
        return False
    mod, ws = pair
    raw, rate = mod.wav_to_pcm(path)
    raw = mod.resample(raw, rate, 48000)
    step = 512 * 2
    for i in range(0, len(raw), step):
        ws.js("window.__skirnir.push(%s)" % json.dumps(
            base64.b64encode(raw[i:i + step]).decode()), await_promise=False)
        if (i // step) % 20 == 0:
            time.sleep(0.18)
    return True


def record_chunk(seconds: float, target: str | None, out: str) -> bool:
    """Record one chunk of the ROOM. Returns False if nothing was captured.

    `--page` takes it from the browser that is in the meeting (the measured path).
    `--monitor-stream <sink-input>` records what ONE client is playing.
    `pw-record --target` was measured ignoring its target and recording the default
    microphone instead, so it is only a fallback.
    """
    if PAGE_PORT:
        return page_ears(seconds, out)
    if MONITOR_STREAM and shutil.which("parec"):
        try:
            subprocess.run(["parec", f"--monitor-stream={MONITOR_STREAM}", "--rate=16000",
                            "--channels=1", "--file-format=wav", out],
                           timeout=seconds, capture_output=True)
            return os.path.exists(out) and os.path.getsize(out) > 1000
        except subprocess.TimeoutExpired:
            return os.path.exists(out) and os.path.getsize(out) > 1000
        except Exception:
            return False
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

    Matched generously, because speech recognition mangles a name it has never seen.
    Measured in a live meeting (2026-10-22): whisper heard "Skírnir" as **"Scare men"**,
    "Scream it", "Scurnier"; the operator types "Skirmir". So the test compares the
    CONSONANT SKELETON of one to three consecutive words against the name's skeleton,
    with a small edit budget — c/k collapse, vowels dropped, m/n and r/l confusion
    tolerated — plus the old single-word edit distance.
    """
    import unicodedata

    def norm(t: str) -> str:
        t = unicodedata.normalize("NFKD", t).encode("ascii", "ignore").decode()
        return t.lower()

    def skeleton(t: str) -> str:
        letters = re.sub(r"[^a-z]", "", norm(t).replace("c", "k").replace("ph", "f"))
        return re.sub(r"[aeiouy]", "", letters)

    if not text:
        return False
    low = norm(text)
    if re.search(r"\b(assistant|snotra)\b", low):
        return True
    target = norm(name)
    t_sk = skeleton(target)
    words = [w for w in re.split(r"[^a-z]+", low) if w]
    for w in words:
        if w == target or _lev(w, target) <= 2:
            return True
        if len(w) >= 5 and t_sk and skeleton(w) == t_sk:
            return True
    # "scare men" / "scream it" / "skirn are": one to three consecutive words
    for i in range(len(words)):
        for span in (2, 3):
            phrase = " ".join(words[i:i + span])
            sk = skeleton(phrase)
            if not sk or len(sk) < 3:
                continue
            budget = 2 if abs(len(sk) - len(t_sk)) <= 1 else 3
            if _lev(sk, t_sk) <= budget:
                return True
    return False


# ---- compose ------------------------------------------------------------------
def compose(heard: str, name: str) -> str:
    """Compose the answer.

    FIRST through Skírnir's own engine (`systems/skirnir/services/ask.sh`, tier owner): it holds
    the approved digest — who the Allfather is, what Ymir and the projects are — and the
    four walls. The rail fallback is for when that door is down, and it is then blind:
    it answers only as a generic assistant and never invents a fact.
    """
    ask = os.path.join(ROOT, "bin", "assistant", "ask.sh")
    if os.access(ask, os.X_OK):
        try:
            out = subprocess.run([ask, "--tier", "owner", "--text", heard],
                                 capture_output=True, text=True, timeout=90).stdout
            data = json.loads(out.strip().splitlines()[-1]) if out.strip() else {}
            answer = (data.get("answer") or "").strip()
            if answer:
                return sanitise(answer)
            if data.get("refused"):
                return "I do not have that in my notes. The Allfather can confirm it."
        except Exception:
            pass
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


def sentences(text: str, limit: int = 0) -> list[str]:
    parts = re.split(r"(?<=[.!?])\s+", text.strip())
    out, buf = [], ""
    for p in parts:
        buf = f"{buf} {p}".strip()
        if len(buf.split()) >= 4 or len(parts) == 1:
            out.append(buf)
            buf = ""
    if buf:
        out.append(buf)
    return out[:limit] if limit else out


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
        return ensure_vram()
    ensure_vram()
    subprocess.run(["systemctl", "--user", "start", "kokoro-serve.service"], capture_output=True)
    for _ in range(20):
        time.sleep(1)
        if up():
            return True
    return False


def ensure_vram(need_mb: int = 1200) -> bool:
    """The card is shared with the rail, and Kokoro fails SILENTLY when it is full:
    `POST /v1/audio/speech` answers 500 CUBLAS failure 3 and the loop counts 0.0 s of
    audio (measured 2026-10-22, right in a live meeting). So free the rail first — the
    house's own rule for this box: the rail reloads on its next request.
    """
    def free_mb() -> int:
        try:
            out = subprocess.run(["nvidia-smi", "--query-gpu=memory.free",
                                  "--format=csv,noheader,nounits"],
                                 capture_output=True, text=True, timeout=10).stdout
            return int((out.strip().splitlines() or ["0"])[0] or 0)
        except Exception:
            return 99999

    if free_mb() >= need_mb:
        return True
    key = os.environ.get("LLAMA_SWAP_API_KEY", "")
    if not key:
        try:
            key = (json.load(open(os.path.expanduser("~/.pi/agent/auth.json")))
                   .get("llama-swap") or {}).get("key", "")
        except Exception:
            key = ""
    alias = ""
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            cmd = open(f"/proc/{pid}/cmdline", "rb").read().decode("utf-8", "replace")
        except Exception:
            continue
        if "llama-server" in cmd and "--alias" in cmd:
            parts = cmd.split("\x00")
            if "--alias" in parts:
                alias = parts[parts.index("--alias") + 1]
                break
    if alias and key:
        body = json.dumps({"model": alias}).encode()
        req = urllib.request.Request(
            "http://127.0.0.1:8080/models/unload", data=body,
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                r.read()
        except Exception:
            return False
        for _ in range(20):
            time.sleep(1)
            if free_mb() >= need_mb:
                return True
    return free_mb() >= need_mb


def synth(text: str) -> str | None:
    body = json.dumps({"model": "kokoro", "input": text, "voice": "af_nicole",
                       "response_format": "wav"}).encode()
    req = urllib.request.Request(f"{KOKORO}/v1/audio/speech", data=body,
                                 headers={"Content-Type": "application/json"})
    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    for attempt in (1, 2):
        try:
            with urllib.request.urlopen(req, timeout=180) as r, open(path, "wb") as out:
                out.write(r.read())
            return path if os.path.getsize(path) > 1000 else None
        except Exception:
            if attempt == 2:
                try: os.unlink(path)
                except OSError: pass
                return None
            ensure_voice()
            time.sleep(1)


BOT_CONTAINER = os.environ.get("SNOTRA_BOT_CONTAINER", "")


def bot_container(meeting_id: str) -> str:
    """The container running the bot in a meeting — its `tts_sink` IS the room's ear.

    Vexa's own `speak` is 404 at the API, but the plumbing behind it is right there:
    inside the bot container PulseAudio has `tts_sink` → `virtual_mic`, and Chromium
    records from `virtual_mic`. Play a wav into `tts_sink` and the room hears it
    (measured 2026-10-22). This is that door, without waiting for the upstream fix.
    """
    import urllib.request as u
    base = os.environ.get("VEXA_API_URLS", "").split(",")[0].rstrip("/")
    key = os.environ.get("VEXA_API_KEY", "")
    if not (base and key and meeting_id):
        return ""
    try:
        req = u.Request(f"{base}/meetings/{meeting_id}", headers={"X-API-Key": key})
        with u.urlopen(req, timeout=15) as r:
            data = json.loads(r.read().decode())
        return data.get("bot_container_id") or ""
    except Exception:
        return ""


def docker_name(container: str) -> str:
    """The API names the bot `mtg-4-…`; Docker names it `vexa-mtg-4-…`. Bridge that."""
    for cand in (container, f"vexa-{container}"):
        probe = subprocess.run(["docker", "inspect", "-f", "{{.State.Running}}", cand],
                               capture_output=True, text=True)
        if probe.returncode == 0:
            return cand
    return container


def play_bot(container: str, path: str) -> bool:
    container = docker_name(container)
    cp = subprocess.run(["docker", "cp", path, f"{container}:/tmp/snotra-say.wav"],
                        capture_output=True)
    if cp.returncode != 0:
        return False
    out = subprocess.run(["docker", "exec", container, "paplay",
                          "--device=tts_sink", "/tmp/snotra-say.wav"], capture_output=True)
    subprocess.run(["docker", "exec", container, "rm", "-f", "/tmp/snotra-say.wav"],
                   capture_output=True)
    return out.returncode == 0


def play(path: str) -> None:
    if PAGE_PORT and page_mouth(path):
        return
    if BOT_CONTAINER:
        if not play_bot(BOT_CONTAINER, path):
            print("error\tthe bot refused the audio (is the container running?)", file=sys.stderr)
        return
    subprocess.run(["paplay", f"--device={MIC}", path], capture_output=True)


def speak(lines: list[str], name: str):
    """Speak the answer, rendering sentence N+1 while N plays.

    This is the streaming half of the loop: the first sentence starts the synthesiser,
    and every later sentence is rendered during the previous one's playback, so a long
    answer is not a long silence. The whole answer is still capped (CAP seconds,
    MAX_SENTENCES sentences) so it yields the floor.
    """
    import threading

    ensure_voice()
    if not lines:
        return 0.0, "", 0.0
    t0 = time.time()
    total, spoken = 0.0, ""
    slots: list = []                       # [(text, path|None)] rendered ahead

    def render(text: str) -> None:
        slots.append((text, synth(text)))

    head = lines[0]
    rest = list(lines[1:])
    head_text = f"{name}, the Allfather's assistant, speaking. {head}"
    thread = threading.Thread(target=render, args=(head_text,), daemon=True)
    thread.start()
    while thread is not None:
        thread.join()
        thread = None
        if not slots:
            break
        text, path = slots.pop(0)
        nxt = rest.pop(0) if rest else None
        if nxt is not None and total < CAP:
            thread = threading.Thread(target=render, args=(nxt,), daemon=True)
            thread.start()
        if total >= CAP:
            if path:
                os.unlink(path)
            break
        if not path:
            continue
        try:
            with wave.open(path) as w:
                dur = w.getnframes() / float(w.getframerate())
        except Exception:
            dur = 0.0
        play(path)
        os.unlink(path)
        total += dur
        spoken = f"{spoken} {text}".strip()
    return total, spoken, time.time() - t0


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
            turn_text = f"{turn_text} {text}".strip()[-600:]
            print(f"heard\t{turn_text[-160:]}", flush=True)
            if addressed(text, name):
                # named inside this chunk: answer now rather than wait for a silence
                handle(turn_text, name, spoke_once)
                spoke_once = True
                turn_text, silence = "", 0.0
                if once:
                    return 0
    return 0


LAST_SPOKE = [0.0]


def handle(heard: str, name: str, spoke: bool) -> bool:
    # Never answer its own voice coming back through the room's speakers: the answer
    # opens with the speaker's name by law, so that prefix is the tell.
    if re.search(r"\bassistant,? speaking\b", heard, re.I):
        print("ignored\town announcement echoed back", flush=True)
        return False
    if time.time() - LAST_SPOKE[0] < 6:
        print("ignored\tcooldown", flush=True)
        return False
    if not addressed(heard, name):
        log({"event": "ignored", "heard": heard[:400], "why": "not addressed"})
        print(f"ignored\tnot addressed\t{heard[:120]}", flush=True)
        return False
    t0 = time.time()
    answer = compose(heard, name)
    compose_s = time.time() - t0
    total, spoken, speak_s = speak(sentences(answer, MAX_SENTENCES), name)
    log({"event": "answered", "heard": heard[:400], "answer": answer[:500],
         "compose_s": round(compose_s, 2), "speak_s": round(speak_s, 2),
         "audio_s": round(total, 2), "name": name})
    LAST_SPOKE[0] = time.time()
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
        if a == "--page":
            globals()["PAGE_PORT"] = int(args.pop(0))
        elif a == "--monitor-of":
            globals()["MONITOR_STREAM"] = args.pop(0)
        elif a == "--listen":
            target = args.pop(0)
        elif a == "--listen-file":
            listen_file = args.pop(0)
        elif a == "--bot-container":
            global BOT_CONTAINER
            BOT_CONTAINER = args.pop(0)
        elif a == "--meeting":
            globals()["BOT_CONTAINER"] = bot_container(args.pop(0))
            if not BOT_CONTAINER:
                print("error: no bot container for that meeting", file=sys.stderr)
                return 1
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
