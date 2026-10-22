#!/usr/bin/env python3
"""snotra-cdp.py — a seat browser as the meeting's mouth and ear, with no OS mixer.

Why this exists (measured 2026-10-22, plan 87 appendix): every PulseAudio route on
this seat reported success and carried silence — null-sink monitors read zeros,
`pw-record --target` was ignored, a joined browser participant was never heard in
the room's own recording. So the audio is taken away from the OS mixer entirely:

  MOUTH   the page's `getUserMedia` is wrapped before Meet's own scripts run, and
          the microphone it hands to Meet is a MediaStreamDestination we fill from
          a ring buffer. We push PCM into that buffer over CDP.
  EAR     the page's remote tracks (the room) are teed into a second destination,
          and their PCM is drained over CDP as base64.

No PulseAudio, no virtual sink, no third-party client library: a small RFC 6455
client (text frames, client masking) and Chromium's DevTools protocol.

    snotra-cdp.py launch [--url U] [--profile P] [--port N] [--headed]
    snotra-cdp.py attach [--port N]
    snotra-cdp.py install                      # prepare the page (before Meet loads)
    snotra-cdp.py join --name NAME [--url U]   # name field + ask-to-join
    snotra-cdp.py say --wav FILE               # push a wav into the meeting mic
    snotra-cdp.py hear --seconds N --out FILE  # drain the room's audio to a wav
    snotra-cdp.py state                        # in the room? muted? participant count

Exit: 0 ok · 2 usage · 3 not in a call · 4 bridge missing
"""
from __future__ import annotations

import base64
import json
import os
import socket
import struct
import subprocess
import sys
import time
import urllib.request
import wave

# --------------------------------------------------------------------- websocket
class WS:
    """A minimal RFC 6455 client: enough for CDP (text frames, no extensions)."""

    def __init__(self, url: str, timeout: float = 30.0):
        assert url.startswith("ws://"), url
        rest = url[5:]
        hostport, _, path = rest.partition("/")
        host, _, port = hostport.partition(":")
        self.sock = socket.create_connection((host, int(port or 80)), timeout=timeout)
        key = base64.b64encode(os.urandom(16)).decode()
        req = (f"GET /{path} HTTP/1.1\r\nHost: {hostport}\r\nUpgrade: websocket\r\n"
               f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
               f"Sec-WebSocket-Version: 13\r\n\r\n")
        self.sock.sendall(req.encode())
        buf = b""
        while b"\r\n\r\n" not in buf:
            buf += self.sock.recv(4096)
        if b" 101 " not in buf.split(b"\r\n")[0]:
            raise RuntimeError(f"websocket handshake failed: {buf[:120]!r}")
        self.buf = buf.split(b"\r\n\r\n", 1)[1]
        self.id = 0

    def _read(self, n: int) -> bytes:
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("cdp closed")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def _frame(self, payload: bytes) -> bytes:
        mask = os.urandom(4)
        n = len(payload)
        head = b"\x81"
        if n < 126:
            head += bytes([0x80 | n])
        elif n < (1 << 16):
            head += bytes([0x80 | 126]) + struct.pack(">H", n)
        else:
            head += bytes([0x80 | 127]) + struct.pack(">Q", n)
        return head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload))

    def send(self, obj: dict) -> None:
        self.sock.sendall(self._frame(json.dumps(obj).encode()))

    def recv(self) -> dict:
        b1, b2 = self._read(2)
        n = b2 & 0x7F
        if n == 126:
            n = struct.unpack(">H", self._read(2))[0]
        elif n == 127:
            n = struct.unpack(">Q", self._read(8))[0]
        payload = self._read(n)
        return json.loads(payload.decode("utf-8", "replace"))

    def call(self, method: str, **params):
        self.id += 1
        self.send({"id": self.id, "method": method, "params": params})
        deadline = time.time() + 60
        while time.time() < deadline:
            msg = self.recv()
            if msg.get("id") == self.id:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result", {})
        raise TimeoutError(method)

    def js(self, expr: str, await_promise: bool = True):
        r = self.call("Runtime.evaluate", expression=expr, returnByValue=True,
                      awaitPromise=await_promise)
        return r.get("result", {}).get("value")

    def close(self):
        try:
            self.sock.close()
        except Exception:
            pass


# ------------------------------------------------------------------ the bridge JS
# Installed with Page.addScriptToEvaluateOnNewDocument, so it is in place before
# Meet calls getUserMedia. It is deliberately small and self-contained.
BRIDGE = r"""
(() => {
  if (window.__skirnir) return;
  const RATE = 48000, BLOCK = 512;              // ~10.7 ms; a ScriptProcessor needs a power of two
  const state = { rate: RATE, queue: [], head: new Float32Array(0), heard: [],
                  meter: 0, remote: 0, ctx: null, dest: null, ready: false,
                  tracks: 0, proc: 0, err: '' };

  const ctx = new (window.AudioContext || window.webkitAudioContext)({sampleRate: RATE});
  state.ctx = ctx;
  ctx.resume && ctx.resume();

  // ---------- the mouth: a destination that becomes Meet's microphone ----------
  const dest = ctx.createMediaStreamDestination();
  state.dest = dest;

  const mouth = ctx.createScriptProcessor ? ctx.createScriptProcessor(BLOCK, 1, 1) : null;
  if (mouth) {
    mouth.onaudioprocess = (e) => {
      const out = e.outputBuffer.getChannelData(0);
      // drain the pushed queue into the destination by summing into `gate`
      let i = 0;
      while (i < out.length) {
        if (state.head.length === 0) {
          if (!state.queue.length) { out[i++] = 0; continue; }
          state.head = state.queue.shift();
        }
        const take = Math.min(out.length - i, state.head.length);
        for (let k = 0; k < take; k++) out[i + k] = state.head[k];
        state.head = state.head.subarray(take);
        i += take;
      }
      let peak = 0;
      for (let k = 0; k < out.length; k++) peak = Math.max(peak, Math.abs(out[k]));
      state.meter = peak;
    };
    // The processor's output IS the microphone: it must reach the destination, and
    // must also touch ctx.destination through a muted gain or the graph stops pulling.
    mouth.connect(dest);
    const keep = ctx.createGain(); keep.gain.value = 0.0;
    mouth.connect(keep); keep.connect(ctx.destination);
  }

  const origGUM = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
  navigator.mediaDevices.getUserMedia = async (constraints) => {
    if (constraints && constraints.audio) {
      try { await ctx.resume(); } catch (e) {}
      return dest.stream;
    }
    return origGUM(constraints);
  };
  navigator.mediaDevices.enumerateDevices = async () => ([
    {deviceId: 'skirnir-mic', kind: 'audioinput', label: 'Skirnir Mic', groupId: 'skirnir'},
  ]);

  // ---------- the ear: tee every remote track Meet receives ----------
  const hearers = [];
  const origRTCPC = window.RTCPeerConnection;
  if (origRTCPC) {
    window.RTCPeerConnection = function (...a) {
      const pc = new origRTCPC(...a);
      pc.addEventListener('track', (ev) => {
        if (ev.track.kind !== 'audio') return;
        state.tracks++;
        try {
          const stream = new MediaStream([ev.track]);
          try { ctx.resume(); } catch (e) {}
          const src = ctx.createMediaStreamSource(stream);
          const proc = ctx.createScriptProcessor ? ctx.createScriptProcessor(BLOCK, 1, 1) : null;
          state.proc++;
          if (proc) {
            proc.onaudioprocess = (e) => {
              const inp = e.inputBuffer.getChannelData(0);
              let peak = 0;
              const copy = new Float32Array(inp.length);
              for (let k = 0; k < inp.length; k++) { copy[k] = inp[k]; peak = Math.max(peak, Math.abs(inp[k])); }
              state.remote = peak;
              if (peak > 0.0005) state.heard.push(copy);
              e.outputBuffer.getChannelData(0).fill(0);
            };
            src.connect(proc);
            const mute = ctx.createGain(); mute.gain.value = 0.0;
            proc.connect(mute); mute.connect(ctx.destination);
          }
          hearers.push(stream);
        } catch (e) { state.err = String(e && e.message || e); }
      });
      return pc;
    };
    window.RTCPeerConnection.prototype = origRTCPC.prototype;
  }

  // ---------- the API we drive over CDP ----------
  const b64ToF32 = (b64) => {
    const bin = atob(b64);
    const n = bin.length >> 1;
    const out = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const v = (bin.charCodeAt(i * 2) | (bin.charCodeAt(i * 2 + 1) << 8));
      out[i] = ((v << 16) >> 16) / 32768;
    }
    return out;
  };
  const f32ToB64 = (f32) => {
    const n = f32.length;
    const bytes = new Uint8Array(n * 2);
    for (let i = 0; i < n; i++) {
      let v = Math.max(-1, Math.min(1, f32[i]));
      v = v < 0 ? v * 0x8000 : v * 0x7fff;
      const s = v | 0;
      bytes[i * 2] = s & 0xff; bytes[i * 2 + 1] = (s >> 8) & 0xff;
    }
    let bin = '';
    for (let i = 0; i < bytes.length; i += 8192)
      bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 8192));
    return btoa(bin);
  };

  // A suspended context (no user gesture) is why a remote track can arrive and be
  // discarded: resume on the first gesture and whenever a track appears.
  ['click','keydown','pointerdown'].forEach(ev =>
    window.addEventListener(ev, () => { try { ctx.resume(); } catch (e) {} }, {once: true}));

  window.__skirnir = {
    ready: true,
    rate: RATE,
    push(b64) { state.queue.push(b64ToF32(b64)); return state.queue.length; },
    queued() { return state.queue.length; },
    meter() { return state.meter; },
    remote() { return state.remote; },
    // drain the room's audio as 16-bit PCM base64, in RATE-sized chunks
    drain(maxBlocks) {
      const chunks = state.heard.splice(0, maxBlocks || state.heard.length);
      const total = chunks.reduce((a, c) => a + c.length, 0);
      const all = new Float32Array(total);
      let o = 0;
      for (const c of chunks) { all.set(c, o); o += c.length; }
      return { blocks: chunks.length, frames: total, b64: f32ToB64(all) };
    },
    hears() { return state.heard.length; },
    // The oracle: what does the microphone stream ITSELF carry? start it, push a
    // sentence, stop it and compare. No timers in the page (a background tab
    // throttles them), no AudioContext that never resumes: the bridge's own context
    // is already running, and we decide when to stop.
    startSide() {
      if (state.side) return 'already';
      const src = ctx.createMediaStreamSource(dest.stream);
      const proc = ctx.createScriptProcessor(BLOCK, 1, 1);
      state.side = { blocks: [], peak: 0, src: src, proc: proc };
      proc.onaudioprocess = (e) => {
        const d = e.inputBuffer.getChannelData(0);
        state.side.blocks.push(new Float32Array(d));
        for (let i = 0; i < d.length; i++) state.side.peak = Math.max(state.side.peak, Math.abs(d[i]));
        e.outputBuffer.getChannelData(0).fill(0);
      };
      src.connect(proc);
      const mute = ctx.createGain(); mute.gain.value = 0;
      proc.connect(mute); mute.connect(ctx.destination);
      return 'recording';
    },
    stopSide() {
      const side = state.side;
      if (!side) return { frames: 0, peak: 0, b64: '' };
      try { side.proc.disconnect(); side.src.disconnect(); } catch (e) {}
      const total = side.blocks.length * BLOCK;
      const all = new Float32Array(total);
      let o = 0;
      for (const b of side.blocks) { all.set(b, o); o += b.length; }
      state.side = null;
      return { frames: o, peak: side.peak, b64: f32ToB64(all) };
    },
    stats() { return { tracks: state.tracks, proc: state.proc, err: state.err,
                        ctx: state.ctx.state, heard: state.heard.length,
                        remote: state.remote, meter: state.meter }; },
    reset() { state.queue.length = 0; state.head = new Float32Array(0); state.heard.length = 0;
              state.meter = 0; state.remote = 0; },
  };
})();
"""


def _cdp_http(port: int, path: str):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}{path}", timeout=5) as r:
        return json.loads(r.read().decode())


def meet_page(port: int):
    for _ in range(30):
        try:
            tabs = _cdp_http(port, "/json")
        except Exception:
            time.sleep(1)
            continue
        pages = [t for t in tabs if t.get("type") == "page"]
        page = next((t for t in pages if "meet.google.com" in t.get("url", "")),
                    pages[0] if pages else None)
        if page:
            return page
        time.sleep(1)
    return None


def attach(port: int) -> WS:
    page = meet_page(port)
    if not page:
        raise SystemExit("cdp: no meet tab")
    ws = WS(page["webSocketDebuggerUrl"])
    ws.call("Runtime.enable")
    return ws


def cmd_launch(args) -> int:
    url = args.get("url", "https://meet.google.com/")
    profile = args.get("profile", "/tmp/skirnir-profile")
    port = args.get("port", 9222)
    headed = args.get("headed", False)
    os.makedirs(profile, exist_ok=True)
    cmd = ["chromium", f"--user-data-dir={profile}", f"--remote-debugging-port={port}",
           "--remote-allow-origins=*", "--no-first-run", "--no-default-browser-check",
           "--use-fake-ui-for-media-stream", "--autoplay-policy=no-user-gesture-required",
           "--window-size=960,720"]
    if not headed:
        cmd.append("--headless=new")
    cmd.append(url)
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(8)
    print(f"launched\tport={port}\tprofile={profile}\theaded={headed}")
    return 0


def cmd_install(args) -> int:
    ws = attach(args.get("port", 9222))
    ws.call("Page.enable")
    ws.call("Page.addScriptToEvaluateOnNewDocument", source=BRIDGE)
    # and in the page that is already open
    ws.js(BRIDGE, await_promise=False)
    time.sleep(0.5)
    print("installed\t", "ready" if ws.js("!!window.__skirnir") else "NOT READY")
    return 0 if ws.js("!!window.__skirnir") else 4


def cmd_join(args) -> int:
    name = args.get("name", "Skírnir")
    ws = attach(args.get("port", 9222))
    typed = ws.js("""(() => {const i=document.querySelector('input[type=text]');
        if(!i) return 'no-field'; i.focus(); i.value=%s;
        i.dispatchEvent(new Event('input',{bubbles:true})); return i.value;})()"""
                  % json.dumps(name))
    cam = ws.js("""(() => {const b=Array.from(document.querySelectorAll('button,[role=button]'))
        .find(e=>/turn off camera/i.test(e.getAttribute('aria-label')||''));
        if(!b) return 'none'; b.click(); return 'off';})()""")
    pressed = ws.js("""(() => {const b=Array.from(document.querySelectorAll('button'))
        .find(e=>/ask to join|join now/i.test((e.innerText||'').trim()));
        if(!b) return 'no-button'; b.click(); return 'pressed';})()""")
    print(f"join\tname={typed}\tcamera={cam}\tbutton={pressed}")
    for _ in range(6):
        time.sleep(4)
        st = cmd_state(args)
        if st == 0:
            return 0
    return 3


def _in_call(ws: WS) -> bool:
    body = ws.js("document.body.innerText") or ""
    return "leave call" in body.lower()


def cmd_state(args) -> int:
    ws = attach(args.get("port", 9222))
    in_call = _in_call(ws)
    bridge = bool(ws.js("!!window.__skirnir"))
    meter = ws.js("window.__skirnir ? window.__skirnir.meter() : null")
    remote = ws.js("window.__skirnir ? window.__skirnir.remote() : null")
    print(f"state\tin_call={in_call}\tbridge={bridge}\tmeter={meter}\tremote={remote}")
    return 0 if in_call else 3


def wav_to_pcm(path: str):
    with wave.open(path) as w:
        ch, width, rate = w.getnchannels(), w.getsampwidth(), w.getframerate()
        raw = w.readframes(w.getnframes())
    if width != 2:
        raise SystemExit("say: only 16-bit wav is accepted")
    if ch > 1:
        import array
        a = array.array("h")
        a.frombytes(raw[: len(raw) - len(raw) % (2 * ch)])
        mono = array.array("h", a[0::ch])
        raw = mono.tobytes()
    return raw, rate


def resample(raw: bytes, src: int, dst: int = 48000) -> bytes:
    if src == dst:
        return raw
    import array
    a = array.array("h")
    a.frombytes(raw)
    n = int(len(a) * dst / src)
    out = array.array("h", bytes(2 * n))
    for i in range(n):
        pos = i * src / dst
        i0 = int(pos)
        i1 = min(i0 + 1, len(a) - 1)
        frac = pos - i0
        out[i] = int(a[i0] * (1 - frac) + a[i1] * frac)
    return out.tobytes()


def cmd_say(args) -> int:
    path = args.get("wav")
    if not path:
        raise SystemExit("say needs --wav")
    raw, rate = wav_to_pcm(path)
    raw = resample(raw, rate, 48000)
    ws = attach(args.get("port", 9222))
    if not ws.js("!!window.__skirnir"):
        raise SystemExit("say: bridge missing — run install first")
    block = 512 * 2                      # one ScriptProcessor block of 16-bit mono
    sent = 0
    for i in range(0, len(raw), block):
        b64 = base64.b64encode(raw[i:i + block]).decode()
        ws.js("window.__skirnir.push(%s)" % json.dumps(b64), await_promise=False)
        sent += 1
        if sent % 20 == 0:               # keep the page's queue shallow (real time)
            time.sleep(0.2)
    while (ws.js("window.__skirnir.queued()") or 0) > 0:
        time.sleep(0.2)
        if time.time() % 30 < 0.3:
            break
    print(f"said\tblocks={sent}\tseconds={len(raw)/2/48000:.1f}")
    return 0


def cmd_hear(args) -> int:
    seconds = float(args.get("seconds", 10))
    out = args.get("out", "/tmp/snotra-hear.wav")
    ws = attach(args.get("port", 9222))
    if not ws.js("!!window.__skirnir"):
        raise SystemExit("hear: bridge missing — run install first")
    ws.js("window.__skirnir.reset()")
    time.sleep(seconds)
    got = ws.js("window.__skirnir.drain(0)") or {}
    pcm = base64.b64decode(got.get("b64") or "")
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(48000)
        w.writeframes(pcm)
    print(f"heard\tframes={got.get('frames', 0)}\tseconds={got.get('frames',0)/48000:.1f}\t{out}")
    return 0


def cmd_selftest(args) -> int:
    """THE ORACLE. Push a sentence into the microphone stream, read it back from that
    same stream, transcribe it, and compare. If the words do not match, nothing else
    about this path is true — no meeting, no claim."""
    import difflib
    port = args.get("port", 9222)
    text = args.get("text", "The mouth carries these words into the room.")
    tts = args.get("wav")
    if not tts:
        tts = "/tmp/snotra-selftest.wav"
        body = json.dumps({"model": "kokoro", "input": text, "voice": "af_nicole",
                           "response_format": "wav"}).encode()
        req = urllib.request.Request(
            os.environ.get("KOKORO_URL", "http://127.0.0.1:8765").rstrip("/")
            + "/v1/audio/speech", data=body, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=120) as r, open(tts, "wb") as f:
            f.write(r.read())
    ws = attach(port)
    if not ws.js("!!window.__skirnir"):
        print("selftest\tbridge missing", file=sys.stderr)
        return 4
    ws.js("window.__skirnir.startSide()", await_promise=False)
    time.sleep(0.3)
    cmd_say({"wav": tts, "port": port})
    time.sleep(0.6)
    got = ws.js("window.__skirnir.stopSide()")
    pcm = base64.b64decode(got.get("b64") or "")
    out = "/tmp/snotra-selftest-heard.wav"
    with wave.open(out, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(48000)
        w.writeframes(pcm)
    heard = _transcribe(out)
    a = " ".join(text.lower().split()); b = " ".join(heard.lower().split())
    ratio = difflib.SequenceMatcher(None, a, b).ratio()
    ok = ratio >= 0.6 or (a and a in b)
    print(f"selftest\tpeak={got.get('peak', 0):.3f}\tframes={got.get('frames', 0)}"
          f"\tmatch={ratio:.2f}\tverdict={'PASS' if ok else 'FAIL'}")
    print(f"  said: {text}")
    print(f"  heard: {heard or '(silence)'}")
    return 0 if ok else 1


def _transcribe(path: str) -> str:
    boundary = "----snotra%d" % int(time.time() * 1000)
    with open(path, "rb") as fh:
        audio = fh.read()
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
        f"filename=\"a.wav\"\r\nContent-Type: audio/wav\r\n\r\n".encode(), audio,
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"temperature\"\r\n\r\n0.0"
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"response_format\"\r\n\r\njson"
        f"\r\n--{boundary}--\r\n".encode()])
    base = os.environ.get("SNOTRA_WHISPER_URL", "http://127.0.0.1:10300").rstrip("/")
    req = urllib.request.Request(f"{base}/inference", data=body,
                                 headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return (json.loads(r.read().decode()).get("text") or "").strip()
    except Exception as exc:
        return f"(transcribe failed: {exc})"


CMDS = {"launch": cmd_launch, "attach": lambda a: (attach(a.get("port", 9222)), 0)[1],
        "install": cmd_install, "join": cmd_join, "state": cmd_state,
        "say": cmd_say, "hear": cmd_hear, "selftest": cmd_selftest}


def main(argv) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    cmd, rest = argv[0], argv[1:]
    args, i = {}, 0
    while i < len(rest):
        a = rest[i]
        if a == "--headed":
            args["headed"] = True; i += 1; continue
        if a.startswith("--"):
            args[a[2:].replace("-", "_")] = rest[i + 1]; i += 2; continue
        i += 1
    if cmd not in CMDS:
        print(f"error: unknown command {cmd}", file=sys.stderr)
        return 2
    if "port" in args and isinstance(args["port"], str):
        args["port"] = int(args["port"])
    return CMDS[cmd](args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
