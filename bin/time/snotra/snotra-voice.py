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


SELF_ECHO = re.compile(r"\bassistant[,]?\s+speaking\b", re.I)


def addressed(text: str, name: str) -> bool:
    if SELF_ECHO.search(text):
        return False
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
    kept = src[::3]                     # 48k -> 16k
    gain = float(os.environ.get("SNOTRA_EAR_GAIN", "6"))
    if gain != 1.0:
        # the tee of a Meet remote track arrives very quiet (measured rms ~700 where the
        # room is loud), so whisper gets fragments. Lift it before the ear, clip safely.
        kept = [max(-32768, min(32767, int(x * gain))) for x in kept]
    return struct.pack("<%dh" % len(kept), *kept)


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


MUTE = os.path.join(os.environ.get("YMIR_HOME", os.path.expanduser("~")),
                    "hodd", "state", "snotra", "voice-muted")


def muted() -> bool:
    return os.path.exists(MUTE)


DIGEST_JSONL = os.path.join(os.environ.get("YMIR_HOME", os.path.expanduser("~")),
                            "hodd", "state", "assistant", "digest.jsonl")
_STOP = {"the","a","an","is","are","was","were","what","who","why","how","does","do","did",
         "you","your","i","my","me","we","it","its","of","in","on","to","for","and","or",
         "about","that","this","there","tell","know","have","has","holds","hold","can","could",
         "would","should","much","many","far","more","some","any","all","not","with","please",
         "give","say","said","us","also","again"}


SUBJECTS = {"opticat": ["opticat", "opti-cat", "opticad", "optica", "opticat's", "opticaat"],
            "snotra": ["snotra", "snatra", "snotre", "nutra", "snorta", "snota"],
            "skirnir": ["skirnir", "skirmir", "skamer", "scurnier", "skirner"],
            "allfather": ["allfather", "all father", "our father", "alfather"],
            "ymir": ["ymir", "ymer", "imir"],
            "brokk": ["brokk", "brok", "brock"]}


def subject_of(heard: str):
    """Which of our subjects this question is about — tolerant of a mangled noun.

    BEST distance wins, never first-hit: "Nutra" is SNOTRA (distance 2), not OptiCat, and
    an earlier first-hit table answered the Allfather's Snotra question with OptiCat.
    """
    low = heard.lower()
    words = re.findall(r"[a-z]+", low)
    best = None
    for canon, aliases in SUBJECTS.items():
        for alias in aliases:
            if alias in low:
                return canon
            if " " in alias:
                continue
            for w in words:
                if len(w) < 4 or abs(len(w) - len(alias)) > 2:
                    continue
                d = lev(w, alias)
                if d <= 2 and (best is None or d < best[0]):
                    best = (d, canon)
    return best[1] if best else None


def digest_match(heard: str, limit: int = 3) -> list[str]:
    """Facts the Allfather approved that answer THIS question.

    The intent table is a phrasebook; a question phrased differently ("tell me more about
    OptiCat") walks past it. This is the retrieval door: token overlap over the approved
    claims, best first, so a fact once approved can be spoken in any wording.
    """
    if not os.path.exists(DIGEST_JSONL):
        return []
    q = {w for w in re.findall(r"[a-z0-9]+", heard.lower()) if w not in _STOP and len(w) > 2}
    if not q:
        return []
    # 1) a small deterministic pre-pass for the questions a meeting actually asks about
    #    people and contact. Weights alone let the OptiCat record answer "how do I contact
    #    you" because it contains the word "contact" (measured). A map is honest.
    prefer = None
    if re.search(r"\b(contact|reach|get in touch|email|telegram|phone|call you|"
                 r"how do (i|we) (reach|contact))\b", heard, re.I):
        prefer = r"^to reach"
    elif re.search(r"\b(your name|who are you|what are you)\b", heard, re.I):
        prefer = r"^sk[ií]rnir"
    else:
        # definition questions want the fact that DEFINES the subject ("Snotra is …"),
        # not one that merely mentions it (measured: "who is the Allfather" answered with
        # the availability fact)
        guess = subject_of(heard)
        if guess:
            prefer = {"opticat": r"^opticat is", "snotra": r"^snotra is",
                      "skirnir": r"^sk[ií]rnir", "allfather": r"^the allfather is",
                      "ymir": r"^ymir is", "brokk": r"^brokk is"}[guess]
        for subject, pattern in (("snotra", r"^snotra is"),
                                 ("brokk", r"^brokk is"),
                                 ("allfather", r"^the allfather is"),
                                 ("ymir", r"^ymir is"),
                                 ("opticat", r"^opticat is"),
                                 ("ovk", r"^ovk records")):
            if re.search(rf"\b{subject}\b", heard, re.I):
                prefer = pattern
                break
    facts = []
    try:
        with open(DIGEST_JSONL, encoding="utf-8") as fh:
            for line in fh:
                try:
                    facts.append(json.loads(line))
                except Exception:
                    continue
    except Exception:
        return []
    if not facts:
        return []
    if prefer:
        chosen = [str(f.get("claim", "")) for f in facts
                  if re.match(prefer, str(f.get("claim", "")).strip(), re.I)]
        if chosen:
            return chosen[:limit]
    # rare words decide the subject; "opticat" must outweigh "system"
    df: dict[str, int] = {}
    tokenised = []
    for fact in facts:
        claim = str(fact.get("claim", "")).lower()
        toks = {w for w in re.findall(r"[a-z0-9]+", claim) if w not in _STOP and len(w) > 2}
        tokenised.append(toks)
        for t in toks:
            df[t] = df.get(t, 0) + 1
    import math
    def weight(t: str) -> float:
        return math.log(1 + len(facts) / (1 + df.get(t, 0)))
    scored = []
    for fact, toks in zip(facts, tokenised):
        if not toks:
            continue
        shared = q & toks
        if not shared:
            continue
        hit = sum(weight(t) for t in shared) / sum(weight(t) for t in q)
        claim = str(fact.get("claim", ""))
        # the fact whose SUBJECT is the question's subject wins: "The Allfather is …" for
        # "who is the Allfather", "Snotra is …" for "what is Snotra", "OptiCat is …" first.
        words = [w for w in re.findall(r"[a-z0-9]+", claim.lower())]
        head = " ".join(words[:2])
        if head and head in heard.lower():
            hit += 0.5
        if "opticat" in q and "opticat" in toks:
            hit += 0.05
        # "how do I contact you / reach him / send a message" is about the CONTACT fact,
        # not about any claim that happens to contain the word "contact" (measured:
        # "how do I contact you" answered with the OptiCat record)
        if re.search(r"\b(contact|reach|get in touch|message|email|telegram|phone|call)\b",
                     heard, re.I) and claim.lower().startswith("to reach"):
            hit += 0.7
        if hit >= 0.40:
            scored.append((hit, fact.get("approved_at", ""), claim))
    scored.sort(reverse=True)
    out, seen = [], set()
    for _, _, claim in scored:
        if claim in seen:
            continue
        seen.add(claim)
        out.append(claim)
        if len(out) >= limit:
            break
    return out


def sanitise(text: str) -> str:
    """The gate each flushed clause passes before it can reach the sink."""
    text = re.sub(r"https?://\S+", "the link", text)
    text = re.sub(r"[*_`#>]", "", text)
    text = re.sub(r"\b(port|vault|plan)\s*\d+\b", r"\1", text, flags=re.I)
    return " ".join(text.split())


def synth_pcm(text: str, voice: str = "af_nicole", on_block=None) -> bool:
    """Kokoro's audio, read in blocks as it arrives — never a whole file, never a player.

    The endpoint refuses `response_format: pcm` (400 — measured), so the body is a WAV,
    but it is still read progressively: the 44-byte header is stripped once and every
    later block is resampled 24k→48k and handed to `on_block`, which pushes it into the
    page's microphone. One sink for the whole answer, opened once, closed never.
    """
    body = json.dumps({"model": "kokoro", "input": text, "voice": voice,
                       "response_format": "wav"}).encode()
    req = urllib.request.Request(f"{KOKORO}/v1/audio/speech", data=body,
                                 headers={"Content-Type": "application/json"})
    for attempt in (1, 2):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                header = b""
                while len(header) < 44:
                    piece = r.read(44 - len(header))
                    if not piece:
                        return False
                    header += piece
                data_at = header.find(b"data")
                if data_at < 0:
                    return False
                rest = header[data_at + 8:]
                if rest:
                    pcm48 = _resample(rest, 24000, RATE)
                    if on_block:
                        on_block(pcm48)
                tail = b""
                while True:
                    chunk = r.read(8192)
                    if not chunk:
                        break
                    buf = tail + chunk
                    cut = len(buf) - (len(buf) % 2)
                    tail = buf[cut:]
                    if cut:
                        pcm48 = _resample(buf[:cut], 24000, RATE)
                        if on_block:
                            on_block(pcm48)
            return True
        except Exception:
            if attempt == 1:
                ensure_voice()
                continue
    return False


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
    """Yield speech-sized clauses, not whole paragraphs.

    A clause longer than ~18 words is cut at a comma (or a space at 22) so the synthesiser
    can start on the first fragment: Kokoro renders ~2 s per second of audio, and a 6 s
    clause is a 6 s wait before the next one can play (measured as 1.7 s gaps in the sink).
    """
    buf = ""
    for piece in re.split(r"(?<=[.!?])\s+", text):
        buf = f"{buf} {piece}".strip()
        while len(buf.split()) > 20:
            cut = -1
            words = buf.split()
            limit = 14 if "," in " ".join(words[:20]) else 18
            for i, w in enumerate(words[:limit], 1):
                if w.endswith(","):
                    cut = i
                    break
            if cut < 0:
                cut = min(limit, len(words))
            yield " ".join(words[:cut]).strip()
            buf = " ".join(words[cut:]).strip()
        if re.search(r"[.!?]$", piece):
            if buf:
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
        self.turn_addressed = False
        self.addressed_at = 0.0
        self.last_voice = 0.0
        self.first_audio_ms = 0
        self.lock = threading.Lock()
        self.wslock = threading.Lock()      # one CDP socket, two threads
        self.cancel = threading.Event()     # barge-in
        self.speaking = False               # the mouth is open
        self.last_push = 0.0

    # ---- capture: drain the page continuously
    def capture(self):
        while self.running:
            try:
                with self.wslock:
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
            if self.speaking or (time.time() - self.last_push) < 1.2:
                # our own voice is in the room's audio: do not listen to ourselves
                window.clear(); heard = 0.0
                continue
            if level < self.args.silence:
                if self.turn and time.time() - last_speech > self.args.hangover:
                    # nobody named him: drop the turn, do not speak into the room
                    log(stage="dropped", heard=self.turn[-80:])
                    self.turn, self.last_partial, self.turn_addressed = "", "", False
                    window.clear(); heard = 0.0
                continue
            last_speech = time.time()
            text, ms = transcribe(audio)
            text = re.sub(r"\[(BLANK_AUDIO|LAUGH|FOREIGN|MUSIC|NOISE|INAUDIBLE)\]",
                          " ", text, flags=re.I).strip()
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
            clean = re.sub(r"\[BLANK_AUDIO\]", "", text).strip()
            floor_open = (time.time() - self.addressed_at) < self.args.floor_window
            subject = re.search(r"\b(opticat|opti-?cat|ovk|ymir|snotra|skirnir|wayof|way of|"
                                r"trello|meeting|calendar|ventilation|inspection)\b", clean, re.I)
            asked = "?" in clean or subject or re.match(r"^(what|who|why|how|when|where|can|"
                                                        r"could|would|do|does|is|are|tell)\b",
                                                        clean.strip(), re.I)
            noise = re.fullmatch(r"[\[\(]?(burps?|laughs?|laughing|sniff|coughs?|"
                                 r"music|noise|sound|blank_audio|bye|magic|oh|ah|heh)[\]\)]?[.!]?",
                                 clean.strip(), re.I)
            strong = (subject_of(clean) is not None) or ("?" in clean)
            if noise:
                strong = False
            if len(clean.split()) >= (2 if addressed(clean, self.name) else 4) and \
                    (addressed(clean, self.name) or (floor_open and asked and strong)):
                self.turn_addressed = True
                self.addressed_at = time.time()
                if self.speaking and time.time() - self.spoke_at < 20:
                    self.cancel.set()          # barge-in: new address cancels the answer
                if time.time() - self.spoke_at > self.args.cooldown:
                    self.speak_turn(self.turn)
                    self.turn, self.last_partial, self.turn_addressed = "", "", False
                    window.clear(); heard = 0.0

    # ---- brain + mouth
    def restricted(self) -> bool:
        """The law's fifth step: a restricted meeting never reaches a voice in the room."""
        try:
            import glob
            for path in glob.glob(os.path.join(os.environ.get("YMIR_HOME", ""),
                                               "hodd", "state", "snotra", "meetings", "*",
                                               ".classification")):
                if "restricted" in open(path, encoding="utf-8").read().lower():
                    return True
        except Exception:
            pass
        return False

    def speak_turn(self, heard: str):
        if self.restricted():
            log(stage="restricted_silent", heard=heard[:60])
            return
        if not heard.strip():
            return
        if time.time() - self.spoke_at < self.args.cooldown:
            return
        if self.speaking:                 # single-flight: never two answers at once
            log(stage="busy", heard=heard[-80:])
            return
        t0 = time.time()
        self.spoke_at = t0
        log(stage="turn", heard=heard[-120:])
        self.speaking = True               # one answer at a time, but the EAR keeps hearing
        threading.Thread(target=self.compose_and_speak, args=(heard, t0),
                         daemon=True).start()

    def compose_and_speak(self, heard: str, t0: float):
        """One long-lived sink, filled while the answer is still being written.

        A producer thread composes and synthesises clause N+1 while the consumer pushes
        clause N into the microphone at real time; the page's queue is the sink and it
        never closes between sentences, so there is no boundary gap. (The defect this
        replaces: a whole answer rendered before a word was spoken, then one player per
        sentence — measured TTFA 2.0 s and gaps up to 2.2 s.)
        """
        import queue

        # address the QUESTION, not the greeting: "Skirnir, what is OptiCat?" must reach the
        # digest as "what is OptiCat" (with the name in it the intent matcher misses and the
        # rail answers at length — measured 24.9 s of audio for one question)
        heard = re.sub(r"\b(sk[iy]?r?n?[aeiou]?r|scare\s*men|scream\s*it|skirm\w*)\b[,:]?\s*",
                       "", heard, flags=re.I).strip() or heard.strip()

        self.cancel.clear()
        blocks: "queue.Queue" = queue.Queue(maxsize=400)
        first_clause = [True]
        spoke = [False]
        final = object()

        def producer():
            pcms = 0
            spoken = 0
            max_clauses = int(os.environ.get("SNOTRA_MAX_CLAUSES", "4"))
            for clause in self.compose_clauses(heard):
                if self.cancel.is_set() or spoken >= max_clauses:
                    break
                spoken += 1
                text = sanitise(clause)
                if not text:
                    continue
                if muted():
                    log(stage="muted", dropped=text[:60])
                    return
                if first_clause[0]:
                    text = f"{self.name}, the Allfather's assistant, speaking. {clause}"
                    first_clause[0] = False
                def on_block(pcm48: bytes):
                    nonlocal pcms
                    if self.cancel.is_set():
                        return
                    pcms += len(pcm48) // 2
                    blocks.put(pcm48)
                if re.search(r"do not (hold|have) that|i don't have that|can confirm it",
                             text, re.I):
                    log(stage="refused_silent", heard=heard[:80])
                    return
                if not synth_pcm(text, on_block=on_block):
                    log(stage="tts", result="refused — no audio")
            blocks.put(final)

        thread = threading.Thread(target=producer, daemon=True)
        thread.start()
        audio_s = 0.0
        started = None
        pending: list[bytes] = []
        prebuffer_s = float(os.environ.get("SNOTRA_PREBUFFER", "1.0"))
        ahead_max = float(os.environ.get("SNOTRA_AHEAD", "6.0"))
        while True:
            item = blocks.get()
            if item is not final:
                if self.cancel.is_set():
                    continue
                pending.append(item)
                audio_s += len(item) / 2 / RATE
                if started is None and audio_s < prebuffer_s:
                    continue          # let the first sentence build a cushion
            if started is None and (item is final or audio_s >= prebuffer_s):
                started = time.time()
                self.first_audio_ms = int((started - t0) * 1000)
                log(stage="first_pcm", ms=self.first_audio_ms)
            for block in pending:
                self.push(block, pace=False, wait=False)
            pending.clear()
            if item is final:
                break
            ahead = audio_s - (time.time() - started)
            if ahead > ahead_max:
                time.sleep(ahead - ahead_max)
        self.speaking = False
        self.last_push = time.time()
        log(stage="done", total_ms=int((time.time() - t0) * 1000), audio_s=round(audio_s, 1))

    def research(self, question: str) -> str:
        """Ask the harness to search, and take back two sentences.

        The voice has no browser of its own; `pi -p` does (web_search, fetch). It is slow
        by voice standards — so it announces the search first and returns one short
        answer, never a page.
        """
        prompt = ("Search the web and answer in at most two spoken sentences. Name the "
                  "sources in parentheses at the end, never in the middle. No lists, no "
                  "markdown. Question: " + question)
        try:
            out = subprocess.run(["pi", "-p", "--no-session", prompt],
                                 capture_output=True, text=True, timeout=120).stdout
            text = " ".join(out.split())
            return text[:600]
        except Exception as exc:
            return f"I could not reach the web just now ({type(exc).__name__})."

    def compose_clauses(self, heard: str):
        """Sentences as they complete: the digest first (no model, 0.23 s), else the rail
        token stream cut by a running chunker."""
        if re.search(r"\b(look (it )?up|search|research|find out|google|check online|"
                     r"what.s online)\b", heard, re.I):
            log(stage="research", question=heard[:90])
            for clause in sentences(self.research(heard)):
                yield clause
            return
        for claim in digest_match(heard):
            log(stage="digest_hit", fact=claim[:70])
            for clause in sentences(re.sub(r"[*_`#>]", "", claim)):
                yield clause
            return
        ask = os.path.join(ROOT, "bin", "assistant", "ask.sh")
        if os.access(ask, os.X_OK):
            try:
                out = subprocess.run([ask, "--tier", "owner", "--text", heard],
                                     capture_output=True, text=True, timeout=60).stdout
                data = json.loads(out.strip().splitlines()[-1]) if out.strip() else {}
                ans = data.get("answer") or ""
                refusal = re.search(r"do not (hold|have) that|i don't have that|tell me the fact",
                                    ans, re.I)
                if ans and not refusal:
                    clean = re.sub(r"[*_`#>]", "", ans)
                    for clause in sentences(clean):
                        yield clause
                    return
                if refusal:
                    log(stage="digest_miss", heard=heard[:80])
            except Exception:
                pass
        body = json.dumps({"model": self.args.model,
                           "messages": [{"role": "system", "content": DIGEST},
                                        {"role": "user", "content": heard}],
                           "temperature": 0.3, "max_tokens": 120, "stream": True}).encode()
        req = urllib.request.Request(f"{BASE}/chat/completions", data=body,
                                     headers={"Content-Type": "application/json",
                                              "Authorization": f"Bearer {_rail_key()}"})
        buf = ""
        started = time.time()
        try:
            with urllib.request.urlopen(req, timeout=25) as r:
                for raw in r:
                    line = raw.decode("utf-8", "replace").strip()
                    if not line.startswith("data:"):
                        continue
                    payload = line[5:].strip()
                    if payload == "[DONE]":
                        break
                    try:
                        piece = json.loads(payload)["choices"][0].get("delta", {}).get("content") or ""
                    except Exception:
                        continue
                    buf += piece
                    if time.time() - started > 20 and not buf.strip():
                        yield "I will come back to that, Allfather."
                        return
                    while True:
                        m = re.search(r"^(.*?[.!?])(\s|$)", buf)
                        if not m or len(m.group(1).strip().split()) < 3:
                            break
                        clause = m.group(1).strip()
                        buf = buf[m.end():]
                        yield clause
            if buf.strip():
                yield buf.strip()
        except Exception as exc:
            yield f"I cannot reach the model just now ({type(exc).__name__})."
        return

    def _old_compose_and_speak(self, heard: str, t0: float):
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
        if re.search(r"\b(look (it )?up|search|research|find out|google|check online|"
                     r"what.s online)\b", heard, re.I):
            log(stage="research", question=heard[:90])
            for clause in sentences(self.research(heard)):
                yield clause
            return
        for claim in digest_match(heard):
            log(stage="digest_hit", fact=claim[:70])
            for clause in sentences(re.sub(r"[*_`#>]", "", claim)):
                yield clause
            return
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
                           "temperature": 0.3, "max_tokens": 120, "stream": True}).encode()
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

    def push(self, pcm48: bytes, pace: bool = True, wait: bool = True):
        if muted():
            log(stage="muted_push")
            return
        """Push PCM into the page's microphone, paced so it sounds like speech."""
        frame = 480 * 2 * 10         # 100 ms of 16-bit mono at 48 kHz, one CDP call each
        for i in range(0, len(pcm48), frame):
            b64 = base64.b64encode(pcm48[i:i + frame]).decode()
            try:
                with self.wslock:
                    self.ws.js("window.__skirnir.push(%s)" % json.dumps(b64), await_promise=False)
            except Exception:
                return
            if pace:
                time.sleep(0.10)
        if not wait:
            return
        while True:
            try:
                with self.wslock:
                    left = self.ws.js("window.__skirnir.queued()") or 0
            except Exception:
                return
            if left <= 0:
                return
            time.sleep(0.1)

    def warm(self):
        """Pay the cold cost before the meeting needs it: the first Kokoro call after an
        idle-stop measured 8.0 s against 0.43 s warm, and whisper's first call is slower
        than its warm 0.16 s. Both are warmed here, on a throwaway sentence."""
        try:
            synth("Warm.")
        except Exception:
            pass
        try:
            transcribe(b"\x00\x00" * ASR_RATE // 2)
        except Exception:
            pass
        # the rail is the fallback for anything the digest does not hold; its first call
        # is a model load (measured 9.9 s into first_pcm). Pay it here.
        try:
            body = json.dumps({"model": self.args.model, "messages": [
                {"role": "user", "content": "Say ok."}], "max_tokens": 4, "stream": False}).encode()
            req = urllib.request.Request(f"{BASE}/chat/completions", data=body,
                                         headers={"Content-Type": "application/json",
                                                  "Authorization": f"Bearer {_rail_key()}"})
            urllib.request.urlopen(req, timeout=180).read()
        except Exception:
            pass

    def run(self):
        ensure_voice()
        self.warm()
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
    ap.add_argument("--hop", type=float, default=0.10, help="capture drain interval (s)")
    ap.add_argument("--step", type=float, default=0.25, help="ASR interval (s)")
    ap.add_argument("--window", type=float, default=6.0, help="rolling ASR window (s)")
    ap.add_argument("--silence", type=float, default=120.0, help="RMS below this is silence")
    ap.add_argument("--hangover", type=float, default=0.5, help="silence before a turn ends (s)")
    ap.add_argument("--cooldown", type=float, default=6.0, help="do not answer twice within (s)")
    ap.add_argument("--floor-window", type=float, default=30.0,
                    help="after an address, how long the floor stays open without repeating the name")
    args = ap.parse_args(argv)
    Voice(args).run()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
