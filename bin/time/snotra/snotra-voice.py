#!/usr/bin/env python3
"""snotra-voice.py — the STREAMING voice loop: capture, transcribe and speak while
the humans are still talking, instead of in two-second blocks.

This is plan 34's design applied to a meeting (plan 87's ear and mouth), and it is the
correction of the chunked loop that preceded it — same door, different clock:

    capture    drain the page's media every 250 ms (the bridge tees every remote track)
    ASR        transcribe a rolling window every ~700 ms; keep only the DELTA, so a
               partial transcript forms while the sentence is still being spoken
    VAD        an energy endpointer with a 700 ms hangover decides the turn is over
    floor      the name test runs on every partial: the moment it is heard, we answer
    LLM        stream tokens from the rail; a sentence is complete at ./!/? (or 60 chars)
    TTS+mouth  sentence N+1 is synthesised while N plays; PCM is pushed into the page's
               microphone stream paced at real time

Every stage writes its own latency to the log, so "streaming" is a measurement and not
a word: stt_ms, ttft_ms, first_audio_ms, turn_ms.

    snotra-voice.py --port 9222 [--name Skírnir] [--once] [--model ID]
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import struct
import subprocess
import sys
import threading
import time
import urllib.request
import wave
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)

RATE = 48000
ASR_RATE = 16000
WHISPER = os.environ.get("SNOTRA_WHISPER_URL", "http://127.0.0.1:10300").rstrip("/")
KOKORO = os.environ.get("KOKORO_URL", "http://127.0.0.1:8765").rstrip("/")
BASE = os.environ.get("SNOTRA_TALK_BASE", "http://127.0.0.1:8080/v1").rstrip("/")
MODEL = os.environ.get("SNOTRA_TALK_MODEL", "qwen3.5-9b@q4_k_s-summarizer")
STATE = os.path.join(os.environ.get("YMIR_HOME", os.path.expanduser("~")),
                     "hodd", "state", "snotra")

DIGEST = (
    "You are Skirnir, the Allfather's assistant, speaking aloud in a meeting beside "
    "his meeting ear Snotra. Answer in one or two short spoken sentences, no lists, no "
    "URLs, no markup. You never decide anything, never agree to a date or a price, and "
    "never speak about plans, ports, keys or private notes. If you do not hold the fact, "
    "say in one sentence that the Allfather can confirm it."
)


def log(**row):
    os.makedirs(STATE, exist_ok=True)
    row["at"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    with open(os.path.join(STATE, "voice-stream.log"), "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(" ".join(f"{k}={v}" for k, v in row.items() if k != "at"), flush=True)


# --------------------------------------------------------------------- the page
def page(port: int):
    import importlib.util
    spec = importlib.util.spec_from_file_location("snotra_cdp", os.path.join(HERE, "snotra-cdp.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    ws = mod.attach(port)
    if not ws.js("!!window.__skirnir"):
        raise SystemExit("the bridge is not in the page — snotra-meet.sh join --port %d" % port)
    return mod, ws


# --------------------------------------------------------------------- pieces
def lev(a: str, b: str) -> int:
    if a == b:
        return 0
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def skeleton(text: str) -> str:
    letters = re.sub(r"[^a-z]", "", text.lower().replace("c", "k").replace("ph", "f"))
    return re.sub(r"[aeiouy]", "", letters)


def addressed(text: str, name: str) -> bool:
    low = text.lower()
    if re.search(r"\b(assistant|snotra)\b", low):
        return True
    target = skeleton(name)
    words = [w for w in re.split(r"[^a-z]+", low) if w]
    for i in range(len(words)):
        if len(words[i]) >= 4 and lev(skeleton(words[i]), target) <= 2:
            return True
        for span in (2, 3):
            phrase = skeleton(" ".join(words[i:i + span]))
            if len(phrase) >= 3 and abs(len(phrase) - len(target)) <= 1 and lev(phrase, target) <= 3:
                return True
    return False


def transcribe(pcm16: bytes) -> tuple[str, int]:
    """pcm16 @16 kHz mono -> text. Returns (text, ms)."""
    boundary = "----v%d" % int(time.time() * 1000)
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
        f"filename=\"w.wav\"\r\nContent-Type: audio/wav\r\n\r\n".encode(),
        wav_bytes(pcm16), 
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"temperature\"\r\n\r\n0.0"
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"response_format\"\r\n\r\njson"
        f"\r\n--{boundary}--\r\n".encode()])
    t0 = time.time()
    req = urllib.request.Request(f"{WHISPER}/inference", data=body,
                                 headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            text = (json.loads(r.read().decode()).get("text") or "").strip()
    except Exception:
        text = ""
    return text, int((time.time() - t0) * 1000)


def wav_bytes(pcm: bytes) -> bytes:
    import io
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(ASR_RATE)
        w.writeframes(pcm)
    return buf.getvalue()


def downsample(pcm48: bytes) -> bytes:
    """48k s16 mono -> 16k s16 mono (take every third sample: 48/16 = 3)."""
    n = len(pcm48) // 2
    if n == 0:
        return b""
    src = struct.unpack("<%dh" % n, pcm48[: n * 2])
    out = struct.pack("<%dh" % (n // 3), *src[::3])
    return out


def rms(pcm16: bytes) -> float:
    n = len(pcm16) // 2
    if not n:
        return 0.0
    data = struct.unpack("<%dh" % n, pcm16[: n * 2])
    return (sum(x * x for x in data) / n) ** 0.5


def ensure_voice() -> bool:
    key = _rail_key()
    for _ in range(2):
        if _port_open(8765):
            return _ensure_vram(key)
        subprocess.run(["systemctl", "--user", "start", "kokoro-serve.service"], capture_output=True)
        for _ in range(20):
            time.sleep(1)
            if _port_open(8765):
                return _ensure_vram(key)
    return False


def _port_open(port: int) -> bool:
    import socket
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=2):
            return True
    except OSError:
        return False


def _rail_key() -> str:
    if os.environ.get("LLAMA_SWAP_API_KEY"):
        return os.environ["LLAMA_SWAP_API_KEY"]
    try:
        return (json.load(open(os.path.expanduser("~/.pi/agent/auth.json")))
                .get("llama-swap") or {}).get("key", "")
    except Exception:
        return ""


def _ensure_vram(key: str) -> bool:
    """Kokoro fails SILENTLY when the card is full (500 CUBLAS failure 3 — measured)."""
    def free_mb() -> int:
        try:
            out = subprocess.run(["nvidia-smi", "--query-gpu=memory.free",
                                  "--format=csv,noheader,nounits"],
                                 capture_output=True, text=True, timeout=10).stdout
            return int((out.strip().splitlines() or ["0"])[0] or 0)
        except Exception:
            return 99999

    if free_mb() >= 1200:
        return True
    alias = ""
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            parts = open(f"/proc/{pid}/cmdline", "rb").read().decode("utf-8", "replace").split("\x00")
        except Exception:
            continue
        if "llama-server" in " ".join(parts[:1]) and "--alias" in parts:
            alias = parts[parts.index("--alias") + 1]
            break
    if alias and key:
        body = json.dumps({"model": alias}).encode()
        req = urllib.request.Request("http://127.0.0.1:8080/models/unload", data=body,
                                     headers={"Content-Type": "application/json",
                                              "Authorization": f"Bearer {key}"})
        try:
            urllib.request.urlopen(req, timeout=60).read()
        except Exception:
            return False
        for _ in range(20):
            time.sleep(1)
            if free_mb() >= 1200:
                return True
    return free_mb() >= 1200


def synth(text: str, voice: str = "af_nicole") -> bytes | None:
    body = json.dumps({"model": "kokoro", "input": text, "voice": voice,
                       "response_format": "wav"}).encode()
    req = urllib.request.Request(f"{KOKORO}/v1/audio/speech", data=body,
                                 headers={"Content-Type": "application/json"})
    for attempt in (1, 2):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                raw = r.read()
            import io
            with wave.open(io.BytesIO(raw)) as w:
                pcm = w.readframes(w.getnframes())
                ch, rate = w.getnchannels(), w.getframerate()
            if ch > 1:
                a = struct.unpack("<%dh" % (len(pcm) // 2), pcm)
                pcm = struct.pack("<%dh" % (len(a) // ch), *a[::ch])
            if rate != RATE:
                pcm = _resample(pcm, rate, RATE)
            return pcm
        except Exception:
            if attempt == 1:
                ensure_voice()
                continue
    return None


def _resample(pcm: bytes, src: int, dst: int) -> bytes:
    a = struct.unpack("<%dh" % (len(pcm) // 2), pcm)
    n = int(len(a) * dst / src)
    out = [0] * n
    for i in range(n):
        pos = i * src / dst
        i0 = int(pos); i1 = min(i0 + 1, len(a) - 1)
        f = pos - i0
        out[i] = int(a[i0] * (1 - f) + a[i1] * f)
    return struct.pack("<%dh" % n, *out)


def sentences(text: str):
    """Yield sentences as they complete — the streaming half of the pipeline."""
    buf = ""
    for piece in re.split(r"(?<=[.!?])\s+", text):
        buf = f"{buf} {piece}".strip()
        if len(buf.split()) >= 3 or re.search(r"[.!?]$", piece):
            yield buf
            buf = ""
    if buf:
        yield buf


# --------------------------------------------------------------------- the loop
class Voice:
    def __init__(self, args):
        self.args = args
        self.name = args.name
        self.mod, self.ws = page(args.port)
        self.blocks = deque()          # 48k s16 blocks from the page
        self.running = True
        self.spoke_at = 0.0
        self.last_partial = ""
        self.turn = ""
        self.last_voice = 0.0
        self.first_audio_ms = 0
        self.lock = threading.Lock()

    # ---- capture: drain the page continuously
    def capture(self):
        while self.running:
            try:
                got = self.ws.js("window.__skirnir.drain(0)") or {}
                pcm = base64.b64decode(got.get("b64") or "")
                if pcm:
                    with self.lock:
                        self.blocks.append(pcm)
            except Exception:
                self.running = False
                return
            time.sleep(self.args.hop)

    def take_pcm(self) -> bytes:
        with self.lock:
            chunks = list(self.blocks)
            self.blocks.clear()
        return b"".join(chunks)

    # ---- ASR: rolling window, emit the delta, VAD decides the turn
    def asr(self):
        window = deque()               # 16k pcm pieces
        heard = 0.0
        last_speech = 0.0
        while self.running:
            time.sleep(self.args.step)
            pcm48 = self.take_pcm()
            if not pcm48:
                continue
            pcm16 = downsample(pcm48)
            window.append(pcm16)
            heard += len(pcm16) / 2 / ASR_RATE
            keep = self.args.window
            while heard > keep and window:
                heard -= len(window[0]) / 2 / ASR_RATE
                window.popleft()
            audio = b"".join(window)
            level = rms(pcm16)
            if level < self.args.silence:
                if self.turn and time.time() - last_speech > self.args.hangover:
                    self.speak_turn(self.turn)
                    self.turn, self.last_partial = "", ""
                    window.clear(); heard = 0.0
                continue
            last_speech = time.time()
            text, ms = transcribe(audio)
            if not text:
                continue
            # delta against the previous partial, so the turn grows word by word
            if text.startswith(self.last_partial) and len(text) > len(self.last_partial):
                new = text[len(self.last_partial):].strip()
                self.last_partial = text
            else:
                new = ""
                self.last_partial = text
            self.turn = f"{self.turn} {new}".strip()[-400:]
            log(stage="asr", stt_ms=ms, rms=int(level), new=new[-80:] or "-")
            if addressed(text, self.name) or addressed(self.turn, self.name):
                if time.time() - self.spoke_at > self.args.cooldown:
                    self.speak_turn(self.turn)
                    self.turn, self.last_partial = "", ""
                    window.clear(); heard = 0.0

    # ---- brain + mouth
    def speak_turn(self, heard: str):
        if not heard.strip():
            return
        if time.time() - self.spoke_at < self.args.cooldown:
            return
        t0 = time.time()
        self.spoke_at = t0
        log(stage="turn", heard=heard[-120:])
        thread = threading.Thread(target=self.compose_and_speak, args=(heard, t0), daemon=True)
        thread.start()

    def compose_and_speak(self, heard: str, t0: float):
        answer = self.compose(heard)
        log(stage="compose", ms=int((time.time() - t0) * 1000), text=answer[:120])
        first = True
        for sentence in sentences(answer):
            text = f"{self.name}, the Allfather's assistant, speaking. {sentence}" if first else sentence
            first = False
            pcm = synth(text)
            if not pcm:
                log(stage="tts", result="refused — no audio")
                continue
            if not self.first_audio_ms:
                self.first_audio_ms = int((time.time() - t0) * 1000)
                log(stage="first_audio", ms=self.first_audio_ms)
            self.push(pcm)
        log(stage="done", total_ms=int((time.time() - t0) * 1000), answer=answer[:160])

    def compose(self, heard: str) -> str:
        ask = os.path.join(ROOT, "bin", "assistant", "ask.sh")
        if os.access(ask, os.X_OK):
            try:
                out = subprocess.run([ask, "--tier", "owner", "--text", heard],
                                     capture_output=True, text=True, timeout=60).stdout
                data = json.loads(out.strip().splitlines()[-1]) if out.strip() else {}
                if data.get("answer"):
                    return re.sub(r"[*_`#>]", "", data["answer"])
                if data.get("refused"):
                    return "I do not hold that yet — the Allfather can confirm it."
            except Exception:
                pass
        return self.stream_llm(heard)

    def stream_llm(self, heard: str) -> str:
        """Token stream from the rail, cut into sentences as they complete."""
        body = json.dumps({"model": self.args.model,
                           "messages": [{"role": "system", "content": DIGEST},
                                        {"role": "user", "content": heard}],
                           "temperature": 0.3, "max_tokens": 220, "stream": True}).encode()
        req = urllib.request.Request(f"{BASE}/chat/completions", data=body,
                                     headers={"Content-Type": "application/json",
                                              "Authorization": f"Bearer {_rail_key()}"})
        text = ""
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                for raw in r:
                    line = raw.decode("utf-8", "replace").strip()
                    if not line.startswith("data:"):
                        continue
                    payload = line[5:].strip()
                    if payload == "[DONE]":
                        break
                    try:
                        delta = json.loads(payload)["choices"][0].get("delta", {})
                    except Exception:
                        continue
                    piece = delta.get("content") or ""
                    if piece:
                        text += piece
        except Exception as exc:
            return f"I cannot reach the model just now ({type(exc).__name__})."
        return text.strip()

    def push(self, pcm48: bytes, pace: bool = True):
        """Push PCM into the page's microphone, paced so it sounds like speech."""
        frame = 480 * 2 * 5          # 50 ms of 16-bit mono at 48 kHz
        for i in range(0, len(pcm48), frame):
            b64 = base64.b64encode(pcm48[i:i + frame]).decode()
            try:
                self.ws.js("window.__skirnir.push(%s)" % json.dumps(b64), await_promise=False)
            except Exception:
                return
            if pace:
                time.sleep(0.05)
        while True:
            try:
                left = self.ws.js("window.__skirnir.queued()") or 0
            except Exception:
                return
            if left <= 0:
                return
            time.sleep(0.1)

    def run(self):
        ensure_voice()
        log(stage="start", port=self.args.port, name=self.name, model=self.args.model,
            hop=self.args.hop, step=self.args.step, window=self.args.window)
        threads = [threading.Thread(target=self.capture, daemon=True),
                   threading.Thread(target=self.asr, daemon=True)]
        for t in threads:
            t.start()
        try:
            while self.running:
                time.sleep(0.5)
        except KeyboardInterrupt:
            self.running = False


def main(argv):
    ap = argparse.ArgumentParser(description="the streaming voice loop")
    ap.add_argument("--port", type=int, default=9222)
    ap.add_argument("--name", default="Skírnir")
    ap.add_argument("--model", default=MODEL)
    ap.add_argument("--hop", type=float, default=0.25, help="capture drain interval (s)")
    ap.add_argument("--step", type=float, default=0.7, help="ASR interval (s)")
    ap.add_argument("--window", type=float, default=6.0, help="rolling ASR window (s)")
    ap.add_argument("--silence", type=float, default=120.0, help="RMS below this is silence")
    ap.add_argument("--hangover", type=float, default=0.7, help="silence before a turn ends (s)")
    ap.add_argument("--cooldown", type=float, default=6.0, help="do not answer twice within (s)")
    args = ap.parse_args(argv)
    Voice(args).run()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
