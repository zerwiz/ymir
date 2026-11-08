#!/usr/bin/env python3
"""live.py — Rödd's live smoke: does the window actually reach the pipeline and hear it back?

Run by ../smoke.sh, which starts the app with --remote-debugging-port and then calls this.
It proves, in order, with the page's own socket:

  1. the page opened a socket to the pipeline            (session.created)
  2. the server accepted the session                     (session.updated)
  3. the server sent assistant audio                     (response.output_audio.delta > 0)

The third is the one that matters: a client that connects and never receives audio is
exactly the failure this suite exists to catch. Speech is not required — the engine's
startup greeting produces a response by itself when it is enabled.
"""
import asyncio, json, sys, urllib.request

import websockets

CDP_PORT = 9222
HOOK = """
(() => {
  const O = window.WebSocket;
  window.__rodd = { types: {}, audioBytes: 0, error: null, url: null };
  window.WebSocket = function(...a) {
    const s = new O(...a);
    window.__rodd.url = a[0];
    s.addEventListener('message', (e) => {
      try {
        const m = JSON.parse(e.data);
        const t = m.type || '?';
        window.__rodd.types[t] = (window.__rodd.types[t] || 0) + 1;
        if (m.error) window.__rodd.error = JSON.stringify(m.error).slice(0, 200);
        if (t === 'response.output_audio.delta' && m.delta) {
          window.__rodd.audioBytes += Math.floor(m.delta.length * 0.75);
        }
      } catch (_) {}
    });
    return s;
  };
  window.WebSocket.prototype = O.prototype;
  Object.assign(window.WebSocket, O);
})();
"""


def page_url() -> str:
    with urllib.request.urlopen(f"http://127.0.0.1:{CDP_PORT}/json/list", timeout=5) as r:
        for p in json.loads(r.read()):
            if p.get("type") == "page":
                return p["webSocketDebuggerUrl"]
    raise SystemExit("live: no page on the debug port")


async def run(seconds: int) -> int:
    async with websockets.connect(page_url(), max_size=20_000_000) as ws:
        seq = 0

        async def call(method, params=None):
            nonlocal seq
            seq += 1
            await ws.send(json.dumps({"id": seq, "method": method, "params": params or {}}))
            while True:
                msg = json.loads(await ws.recv())
                if msg.get("id") == seq:
                    return msg

        await call("Page.enable")
        await call("Runtime.enable")
        await call("Page.addScriptToEvaluateOnNewDocument", {"source": HOOK})
        await call("Page.reload", {"ignoreCache": True})
        await asyncio.sleep(6)

        # tap the orb — the demo does not connect until the operator starts the conversation
        r = await call("Runtime.evaluate", {"expression":
            "(() => { const el = document.querySelector('#main-circle');"
            " if (!el) return 'no-orb'; const b = el.getBoundingClientRect();"
            " return JSON.stringify({x: Math.round(b.x+b.width/2), y: Math.round(b.y+b.height/2)}); })()",
            "returnByValue": True})
        where = r["result"]["result"].get("value")
        if where == "no-orb":
            print("live: FAIL — the page has no #main-circle")
            return 1
        box = json.loads(where)
        for kind in ("mousePressed", "mouseReleased"):
            await call("Input.dispatchMouseEvent", {"type": kind, "x": box["x"], "y": box["y"],
                                                    "button": "left", "clickCount": 1})

        deadline = asyncio.get_event_loop().time() + seconds
        state = {}
        while asyncio.get_event_loop().time() < deadline:
            await asyncio.sleep(2)
            r = await call("Runtime.evaluate", {"expression": "JSON.stringify(window.__rodd || {})",
                                                "returnByValue": True})
            state = json.loads(r["result"]["result"].get("value") or "{}")
            if state.get("audioBytes"):
                break

        types = state.get("types") or {}
        ok_session = types.get("session.created", 0) > 0
        ok_accepted = types.get("session.updated", 0) > 0
        ok_audio = (state.get("audioBytes") or 0) > 0

        def line(label, passed, detail=""):
            print(f"{label:44} {'PASS' if passed else 'FAIL'}  {detail}")

        line("the page opened a socket to the pipeline", ok_session, state.get("url") or "")
        line("the server accepted the session", ok_accepted)
        line("assistant audio arrived", ok_audio, f"{state.get('audioBytes') or 0} bytes")
        if state.get("error"):
            print("server said:", state["error"])
        print("events:", json.dumps(types)[:400])
        return 0 if (ok_session and ok_accepted and ok_audio) else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(run(int(sys.argv[1]) if len(sys.argv) > 1 else 40)))
