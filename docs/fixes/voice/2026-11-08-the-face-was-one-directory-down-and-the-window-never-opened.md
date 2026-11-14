# voice · unversioned · 2026-11-08 — the face was one directory down, and the window never opened

## What

Rödd could not be set up on a second seat, and its window had never opened anywhere. Three faults, all
in `apps/rodd/`, each invisible in a different way:

- **`apps/rodd/setup.sh` cloned the engine where the face should be.** At the pinned tag (`v1.1.0`) the
  browser face is the engine's own `demo/` directory (`index.html` · `server.py` · `main.js` · `worklets/`);
  the setup cloned the *engine* into `ui/` and then ran `npm ci` there against a root that carries no
  `package.json`. The run printed `bundle missing` and `patch-ui: no UI at …/ui` and still exited 0, so a
  broken face looked like a finished one. It now clones into the user cache (`$XDG_CACHE_HOME/ymir/rodd-engine`), copies
  `demo/.` into `ui/`, stamps the served face with the tag (`ui/.rodd-face`), and skips `npm ci` when
  `ui/node_modules` already stands.
- **`apps/rodd/src/main.js` swallowed its own first argument.** The interpreter expression ended with a
  line comment that carried the comma —
  `process.env.RODD_PYTHON || path.join(…)   // allow-home-default: …,` — so what followed was parsed as a
  member access on the path string: `path.join(…)['-m','uvicorn',…]`. That evaluates to `undefined`, and
  `execFile` refused it with `TypeError [ERR_INVALID_ARG_TYPE]: The "file" argument must be of type string.
  Received undefined`. The promise rejected unhandled, the UI server was never spawned, the window was
  never created: **the app ran and showed nothing at all**, which is why `smoke.sh` reported
  `the app's own server NOT RUNNING` while the pipeline itself was healthy. The interpreter is now named
  once, on its own line, and the exact spawn is logged (`[rodd] ui server: <python> -m uvicorn --app-dir
  <ui> port <n>`) so the next silent death is readable from the shell.
- **`apps/rodd/start.sh` was pinned to `electron41` and to an ssh round-trip to itself.** This box moved
  to `electron43`, so `ELECTRON=/usr/lib/electron41/electron` was `No such file`; and on a dev seat with a
  card — where the host seat in `fleet.json` IS this machine — the script still opened an ssh tunnel and
  raised the pipeline over ssh, which fails on a box with no key seated for its own login. Electron is now
  **probed** (`$RODD_ELECTRON` → npm's own `node_modules/electron/dist/electron` → the newest
  `/usr/lib/electron*/electron` → `command -v electron`), a local host seat opens **no tunnel**, and the
  host is raised in-process through `bin/voice/voice-door.sh host` instead of over ssh. The `strays()`
  pattern that clears a leaked client learned the same lesson (`electron[0-9]*`, not `electron41`).

## Why

His word: *"pull latest and run groa and set up rödd"*. Pulling brought plan 132's app; setting it up
proved the face had never been built on this seat, and the window had never been opened on any. The
pipeline was never the fault — `voice-door.sh host` answered on `127.0.0.1:8890` throughout, Kokoro warm,
the fast MoE head named — so the silence was entirely in the two files that dress and open the face.

## Verified

- `apps/rodd/setup.sh` — `ui/index.html`, `ui/server.py`, `ui/house.css`, `ui/ember.js` and
  `ui/vendor/openai-realtime-agents.umd.js` all present; `patch-ui: … dressed as Rödd`; a second run is a
  clean no-op (`face already fetched` · `dependencies already installed`).
- the UI server answers on its own: `GET /api/config` → 200, `GET /` → 200.
- the window: DevTools target `Rödd · the voice of Ymir` at `http://127.0.0.1:7877/`, spawned by
  `electron43` picked by the probe.
- `apps/rodd/smoke.sh 45` — **every stage PASS**, ending
  `assistant audio arrived PASS 239586 bytes` and
  `live window (socket · accepted · audio) PASS`.

## Not verified / owed

- The camera head (`--vision` → `gemma-4-12b-vision`) was not exercised this session.
- A real spoken turn from the operator's own microphone (the smoke proves the socket, the session, and
  audio bytes; it does not prove the room).
- `apps/rodd/node_modules` carries an npm `electron` 33 with an empty `dist/` — the probe still prefers a
  dist binary that is not there, so it lands on the system package. Harmless, but the postinstall that
  would fetch it has not been run on this seat.

Plan: `svartalfaheim/whynotproductions/projects/ymir/plans/132-skirnir-fleet-connectivity.md`.

## CHANGE LOG

- **2026-11-08** — written. The setup, the spawn, and the launcher: three silent failures, repaired and
  proved by the smoke's own last line.

## Correction and addition (2026-11-08, later the same night) — the picture that ended a whole session

His word, spoken into the window itself: *"what is going on now"* → the face said *"I'm having trouble
responding right now. Please try again."* — twice, after a `camera_snapshot` tool call. Then: **"fix so the
pictures work"** and **"rödd must work on updates and installations"**.

### What was actually wrong, read from `host.log`

```
2026-11-08 02:54:07 lamp: openai.InternalServerError: Error code: 500 -
  {'message': 'image input is not supported - hint: … you may need to provide the mmproj'}
```

The window had been raised on the **text-only** head (`qwen3.6-35b-a3b@iq3_s-fast`), the page offered the
demo's own camera tool anyway, and one snapshot put an image part into the conversation. From that moment
**every** turn in the session failed — the image never leaves the history — and the face could only say
"try again". The pipeline was healthy the whole time: `stt=0.16s llm=1.26s tts_ttfa=0.19s e2e=2.15s`.

The rail was never broken. Proved directly, on this box, with a real PNG:

```
gemma-4-12b-vision · "What colour is this square? One word." → "Red" · 1.2 s
```

(its `mmproj` is the BF16 projector at `~/models/HauhauCS/…mmproj-…-BF16.gguf`, the one the
2026-11-07 vision proof used; the F32 projectors are what crash `clip_model_loader`.)

### The rule this adds

**The camera follows the head.** A face may offer a picture only when the head behind it can see:

- `apps/rodd/start.sh` decides the head AND the camera together — the fast MoE (`RODD_CAMERA=0`, camera
  absent) or `--vision` → `gemma-4-12b-vision` (`RODD_CAMERA=1`, camera on) — and logs which it chose.
- `apps/rodd/src/main.js` opens the face with `?camera=1|0`, and logs the mode.
- `patch/patch-ui.py` injects one classic inline script at the top of `<head>` (before the app's module):
  it writes `localStorage["s2s.ws.tools"].camera_snapshot` from the query param and marks
  `<html class="rodd-text-only">`.
- `patch/house.css` hides `#tool-cam-row`, `#tool-cam-hint` and `#cam-pip` when that class is set — the
  switch is **absent**, not disabled, because a switch that poisons the session is a trap, not a control.

### Install and update — so no seat has to remember this

- `apps/rodd/setup.sh --check` answers `present` / `missing` / `stale:<tag>` (exit 1 unless present).
- `apps/rodd/start.sh` builds the face first when it is missing or stale — one command always ends in a
  working window, on a fresh clone and after an update that moved the pinned tag.
- `bin/voice/voice-ensure.sh` now reports the face (`rodd[1]{face,means}`) and builds it in
  `install_all`, so the `voice` install step of `bin/engine/ymir-install.sh` and `eir-doctor.sh fix` both
  produce it; `status` no longer calls voice whole while the window is absent.

### Verified

- `apps/rodd/setup.sh` re-run → `patch-ui: … dressed as Rödd`, `grep -c "camera follows the head"`
  in `ui/index.html` = 1, `rodd-text-only` rules in `ui/house.css` = 4.
- `apps/rodd/start.sh --vision` → `head vision — the camera is on (turns are slower)`,
  `[rodd] camera on (the head can see)`, `host up on 127.0.0.1:8890`, toolbox `{"ok": true, "tools": 25}`.
- `apps/rodd/smoke.sh 45` → every stage PASS, `assistant audio arrived PASS 374784 bytes`,
  `live window (socket · accepted · audio) PASS`.
- `bin/voice/voice-ensure.sh status` → `rodd["present"]`.

### Not verified / owed

- A **snapshot through the pipeline** (the operator pressing the camera) was not exercised from here: the
  rail's vision answer and the mode wiring are proved, the browser's tool round-trip is not.
- Words on the vision head are slower than on the fast MoE; the window's default is still the fast MoE, so
  pictures require `apps/rodd/start.sh --vision`. A single session that is quick for words AND able to see
  needs either a smaller vision head on the rail or an engine that can swap the head mid-session.

## Addition (2026-11-08, the same evening, from the window itself) — three hands he kept asking for

Speaking into the working window, the Allfather kept hitting the edge of what the voice could reach:

- *"What is going on on the cron jobs? … are they running?"* — the voice had no schedule door, guessed at
  a memory, and got the answer wrong.
- *"Now that was the errands, what is Northern Italy doing?"* — it wrote a **plan** (`plan_write`) and then
  tried to research, because "plan" and "errand" were one word to it.
- *"Can you do online research?"* — it could only promise Huginn, never send him.

His word: **"we still missing alot of tools … we are going to give you the tool."**

Three were added to `bin/voice/voice_tools.py`, each a **door the terminal already had** (no second
implementation), and each declared in `TOOLS` and registered in `NEW_TOOLS` — the toolbox reads that list,
so the window's face gained all three with no other wiring:

```
new_hands[3]{tool,what_it_reads,kind}:
  "cron_jobs","nornir-cron-start.sh --status · <home>/config/cron.yaml (role-gated lines: `@heart 06:00 bin/…`) · state/.cron-fired mtimes · the log's tail","read-only"
  "plans","the plan ledger in the home — every shelf's *.md, newest number first; `query` finds a subject, `number` reads one plan","read-only"
  "research","seats Huginn (role researcher, from .agents/roles.yaml) on the question through bin/agents/eindri-seat.sh","dispatch, two-phase gate"
```

`research` carries the **same gate as `hand_over`**: without `confirm` it writes
`hodd/state/voice/pending-research.json` and answers *NOT SENT — ask him out loud*; a confirm whose
question does not match the pending record is refused. The standing word is that no worker leaves on a
spoken word alone.

Both house briefs (the patched `DEFAULT_INSTRUCTIONS` and the shell's `HOUSE_INSTRUCTIONS`) now name the
three, and say the thing the voice kept getting wrong: **a PLAN is not an ERRAND**.

### Verified

- module: `tools: 28 | new: ['cron_jobs', 'plans', 'research']`.
- `cron_jobs` → `cron: running pid=171685 jobs=32` and all 32 schedule lines with their role gates.
- `plans(query='voice')` → plans **206**, **132**, **121**; `plans(number='121')` → the plan's own opening.
- `research(question=…)` without confirm → `NOT SENT. Ask him out loud …`.
- the toolbox after restart: `{"ok": true, "tools": 28}` and `/tools` lists all three; the window reloaded
  at `http://127.0.0.1:7869/?camera=1` with `[rodd] camera on (the head can see)`.

### Owed

- A confirmed `research` dispatch through the window was not exercised end to end (the gate's refusal was).
- `plans` reads every shelf on every call: on a large ledger that is fine at speech speed, but it is a
  directory walk, not an index — a ledger index door would be the right next step.

## Addition (2026-11-08, last of the night) — the shell hands and the MCP adapter: 25 → 34

His word: *"can we give it the tools ls, read, edit, and bash also, an mcp adapter so we can connect chrome
devtools and the gimle mcp and more … after that build it. use dev tools until you know all works."*

### What landed

- **`bin/voice/voice_mcp.py` (new)** — the MCP adapter, a client for both transports MCP uses: stdio
  (newline JSON-RPC over a child process) and streamable HTTP (JSON-RPC or SSE over POST). It keeps no table
  of its own: the servers are the seat's own declaration, merged later-wins from `.pi/mcp-adapter.json` →
  `~/.pi/agent/mcp.json` → `<home>/config/voice-mcp.json`. **14 servers** resolve; `chrome-devtools` (added
  to the home config, attached to the window's own CDP port) reports **32 tools**. A server that will not
  start, and a tool that refuses, are said in words; a remote OAuth server says it needs an interactive
  sign-in the voice cannot perform.
- **Six hands in `voice_tools.py`** (34 tools now): `ls`, `read`, `edit`, `bash`, `mcp_tools`, `mcp`.
- **Three laws, enforced in code, not in the brief:**
  1. *a spoken word is not a grant* — `edit`, `bash` and any MCP call that is not read-only write a
     `pending-action.json` and answer **NOT DONE, ask him out loud**; a confirm that does not match the
     pending record is refused;
  2. *some doors never open to a voice* — the secrets shelf, `.ssh`, `.age`, and the destructive commands are
     refused outright, and the refusal is a spoken sentence (`_bash_refusal`);
  3. *output is data* — every call is a line in `hodd/state/voice/activity-*.jsonl`.

### Verified with the tools themselves (Chrome DevTools over MCP)

```
measurements[5]{what,result}:
  "devtools → the page","list_pages: Rödd · the voice of Ymir at http://127.0.0.1:7830/?camera=1"
  "devtools → the page's own tool list","the live page fetched the toolbox: `34 tools | shell: ls,read,edit,bash,mcp_tools,mcp`"
  "devtools → the camera law in the live DOM","text-only=none · vision=flex (the switch is absent when the head cannot see)"
  "devtools → console","<no console messages found> on a clean load"
  "the gates, through the toolbox (the window's own path)","`bash` without confirm → NOT DONE; with confirm → ran (exit 0); `rm -rf /` → refused outright; `mcp list_pages` (read-only) → ran; `mcp navigate_page` (write) → NOT DONE"
```

`apps/rodd/smoke.sh 45` after all of it: every stage PASS, `assistant audio arrived PASS 337920 bytes`,
`live window (socket · accepted · audio) PASS`.

### Owed

- Gimlé's MCP (`bin/gimle/mcp-read.py`, deployed to the heart behind a bearer token) is not yet in the
  voice's server list — its URL and token must be read, not guessed.
- A spoken end-to-end confirm for `edit`/`bash`/`mcp` (his voice → the tool) was not exercised.
- The OAuth servers (trello · gmail · drive · docs) need a harness-side grant the voice cannot do.

## Addition (2026-11-08, after the calendar grant) — Google's MCP, borrowed not re-consented

His word: *"can't we just connect google's MCP also to him"*. The servers were already declared
(gmail · drive · docs · trello), but the adapter had no way to authenticate to them: it only knew a token
from an environment variable.

`bin/voice/voice_mcp.py` now reads the harness's own store, `~/.pi/agent/mcp-auth.json` (keyed
`mcp__<name>|<url>`), uses the access token while it is live, and **refreshes it in memory for that process
only** when it has expired — the store stays Pi's to rewrite, and nothing is copied into the tree.

```
measured[4]{server,tools,what_answered}:
  "gmail","23","authenticated, list returned; a CALL is refused by Google until Cloud project 463322445860 is enrolled in the Workspace Developer Preview Program"
  "drive","8","authenticated, list returned; `search_files` → `The caller does not have permission` (same wall)"
  "docs","2","authenticated, list returned; not exercised"
  "trello","—","token live to 15:45 today; same refresh path available"
```

So the road is open and the wall is Google's, not ours: the enrolment is the operator's grant to give in a
browser. Proved through the toolbox (the window's path): `mcp_tools gmail` → `gmail: 23 tools`.
