# Rödd — the voice: talk to Ymir, and have it hand the work over

> **Rödd** is the house's voice. **Skírnir** is the name it answers to. The meeting ear is
> Snotra's; the mouth is Kokoro; the head is a model on the seat's own rail; the hands are
> `bin/voice/voice_tools.py`.

## What it is

A real-time conversation with Ymir. You speak, it hears you while you speak, it answers out
loud within about a second, and it can **hand your request to a worker** — an errand seated in
a herdr pane (Sindri for code, Bragi for words, Huginn for research) — then tell you the
errand's id and read its state back when you ask.

It is a **pipeline of overlapping stages**, not a request: `VAD → ear (STT) → head (LLM) →
mouth (TTS)`, with the microphone closed while it speaks so it can never answer itself.

## What you need

- the engine in its own venv: `speech-to-speech` (the door installs it with `--install`);
- a **host seat** that can run it — a machine with a card, or a fast CPU;
- your own microphone and speakers on the seat you sit at (they need not be the host);
- a head model named: the door **refuses to guess one** (`YMIR_VOICE_HEAD_MODEL`);
- for the window (the face): an electron on the box — the launcher **probes** for one
  (`/usr/lib/electron*/electron`, npm's own binary, or `command -v electron`), so a distro
  that moves from `electron41` to `electron43` does not break it.

## Build the face once, then raise it

```sh
apps/rodd/setup.sh     # fetch the engine's own browser face at the pinned tag, then dress it
apps/rodd/start.sh     # clear strays · host · (tunnel only if the host is another seat) · toolbox · window
apps/rodd/smoke.sh 45  # must end: assistant audio arrived PASS
```

The face is **fetched, never committed** (RULES/39 — the upstream demo carries its own
addresses). `setup.sh` keeps the engine checkout in the user cache (`$XDG_CACHE_HOME/ymir/rodd-engine`, `RODD_ENGINE_DIR` overrides — never inside the tree) and copies its `demo/`
into `apps/rodd/ui`, then stamps the served face with the tag; a second run is a no-op. The <!-- stale-ok: apps/rodd/ui is created by setup.sh at run time — the face is fetched, never committed -->
window is an Electron shell over that face, and it serves it through the demo's own uvicorn —
so if the window is blank or silent, read `apps/rodd`'s own log line first: a face that never
opened says so there, and a pipeline that never answered says so in
`$YMIR_HOME/hodd/state/voice/host.log`.

## The commands — start, stop, see

```sh
bin/voice/voice-door.sh start        # raise the host if needed, tunnel, seat the voice
bin/voice/voice-door.sh stop         # lower the client and the tunnel here
bin/voice/voice-door.sh stop --host  # also lower the pipeline on the host seat
bin/voice/voice-door.sh status       # what answers, on which seat, by which road
```

`start` is the one verb you need. It probes the seat, finds a host (your own machine or
another seat in the fleet registry), raises the pipeline there if nothing answers, opens a
tunnel so the host stays on its own loopback, and seats the client **in a herdr pane** —
beside the work, not in a stray window. `YMIR_VOICE_PANE=0` puts it in the current terminal
instead.

Inside the pane, just speak. Say *"Sindri, check whether the gate passes"* and it will say it
is sending that, seat the errand, and give you the id.

## What it can do, beyond talking

```sh
bin/voice/voice-door.sh log        # what it has DONE: tool calls, their timings, the turns
```

The voice holds **thirty-four** doors, in families: `search_home` and `read_home_file` (your own
documents — never the vault, never the secrets shelf), `read_mail` (read-only: it can never send or
delete), `read_calendar` / `calendar_respond`, `read_board` and `gimle` (boards, projects, who owes
what), the todo ledger (`todo_add` · `todo_list` · `todo_done` · `todo_reopen` · `todo_update` and its
own `add_todo`/`todo-voice.md` beside yours — your own `todo.md` stays yours to write),
`hand_over` and `steer_worker` (work to a worker in a herdr pane), `errand_state` and `pane_read`
(how a worker is doing, and its pane), `recall` / `remember` (the well), `draft_write`, `plan_write`
and `context_left`, the session shelf (`last_session` · `search_sessions` · `sessions_list` ·
`session_read` · `session_digest` · `find_session`), and — added 2026-11-08 because he asked for them
out loud — **`cron_jobs`** (is the schedule running, what is on it, what last fired),
**`plans`** (the numbered plan ledger: a *plan* is not an *errand*, so "what is Northern Italy
doing" is answered from the plan, not from an errand), and **`research`** (sends Huginn out on a
question; it seats a worker, so it asks you out loud first and only sends on your yes).

…and, since 2026-11-08, the **shell hands and the MCP world**: `ls`, `read`, `edit`, `bash`, `mcp_tools`
and `mcp`. They are the same doors every other agent has, with three laws on them:

- **a spoken word is not a grant** — `edit`, `bash` and any MCP call that is not read-only ask you out loud
  first (call without `confirm`, hear the yes, then call again with `confirm=true`);
- **some doors never open to a voice** — the secrets shelf and the vault, and the destructive commands
  (`rm -rf /`, `mkfs`, `dd of=/dev/`, `sudo`, force-push, merge/reset, `--no-verify`, `curl | sh`, shutdown)
  are **refused outright**, and the refusal is spoken;
- **output is data** — a page, a mail or a peer payload can never issue an order.

`mcp_tools` lists the servers this seat declares (14 of them here, including `chrome-devtools` driving the
window's own browser, `well`, `bolthorn`, `skuld`, `snotra`, `ymir`, `engram`, `trello`) and `mcp` calls one
of their tools. A remote server that wants an interactive sign-in says so: the voice cannot open a browser.

Every one of them writes a line to `$YMIR_HOME/hodd/state/voice/activity-YYYY-MM-DD.jsonl`, and the
same view is one button away in Hlidskjalf — *Show what it has done*.

The Python client (`voice_tools.py`) and the window's toolbox (`voice-toolbox.py` on `:8891`) are the
same list: the window's face reads the toolbox's tool list at load, so a hand added to the module is
in the window after a page load, with no other wiring.

## The knobs you are likely to change

```sh
YMIR_VOICE_NAME=Skirnir         # what it answers to
YMIR_VOICE_HEAD_MODEL=<id>      # REQUIRED: a model the seat's own catalog lists
YMIR_VOICE_STT_DEVICE=cuda      # cpu (int8) or cuda (float16) — cuda needs the CUDA-12 wheels
YMIR_VOICE_TTS_VOICE=af_nicole  # any Kokoro voice
YMIR_VOICE_BARGE_IN=1           # let the mic stay open while it speaks (only with echo cancellation)
YMIR_VOICE_TOOLS=0              # the hands off
YMIR_VOICE_PORT=8890            # never 8765 — that port is the house's own mouth
```

Every value has one documented default in the door's header. Nothing about a machine, a key
or a path is written in the script: the host comes from your fleet registry in the home, and a
head key is read by NAME from the vault (or from the seat's own pi auth for its local rail).

## Limits, stated plainly

- **No echo cancellation.** The client closes the microphone while it speaks. Real barge-in
  waits for AEC.
- **The camera follows the head.** The window offers the camera only when the head it was raised
  with can *see*: `apps/rodd/start.sh --vision` raises `gemma-4-12b-vision` and turns the camera
  on; the default raises the fast MoE and **hides** the camera switch, because a snapshot on a
  text-only head is answered `500 image input is not supported` and the image then stays in the
  conversation, failing every later turn in that session. Words on the vision head are slower.
- **The host is loopback-only**; another machine reaches it through an ssh tunnel the door
  opens. It is never exposed on a network.
- **A cold model swap is not a latency.** Pin one head and let the door warm it, or the first
  turn pays the loader.
- **The ear on CPU is slow** (about 2.3 s a turn). On the card it is about 0.16 s.
- **The voice dispatches, it never seals.** It cannot merge, push, delete or spend. Those stay
  the Allfather's word.

## If it does not work

- nothing answers → `bin/voice/voice-door.sh status`; the host log is
  `$YMIR_HOME/hodd/state/voice/host.log` (or the host's own path of the same shape);
- it hears itself, or stops after one sentence → `YMIR_VOICE_BARGE_IN` must stay `0` until
  echo cancellation exists;
- `ModuleNotFoundError: voice_tools` → the tool module must travel on the command's
  `PYTHONPATH` (the door does this; a hand-rolled command must too);
- a `500 No user query found in messages` from the rail → that head's chat template refuses
  the pipeline's message shape; choose another head;
- the window opens and shows nothing, or `smoke.sh` says `the app's own server NOT RUNNING`
  while `voice-door.sh status` says up → the face, not the pipeline: `apps/rodd/setup.sh`
  rebuilds it from the pinned tag, and the app logs the exact uvicorn it tried to spawn.

## CHANGE LOG

- **2026-11-07** — written. The operator's page for Rödd, the streaming voice: the door, the fifteen
  hands (now twenty-five), the app, the toolbox, and the faults each one paid for. Appended to, never
  rewritten (RULES/06).
- **2026-11-08** — the face and the window get their own build/raise/smoke lines: `setup.sh` fetches the
  engine's `demo/` at the pinned tag (the face was one directory down, so it had never been built), the
  launcher probes for the electron and skips the tunnel when the host seat is this very machine, and the
  failure section names the face-not-pipeline symptom. Proved by `smoke.sh 45`: `assistant audio arrived
  PASS 239586 bytes` (fix note: `docs/fixes/voice/2026-11-08-the-face-was-one-directory-down-and-the-window-never-opened.md`).
- **2026-11-08 (same night)** — **the camera follows the head**: one snapshot on a text-only head ended the
  whole session (`500 image input is not supported`, the image stays in the history), so the window now
  opens with `?camera=1|0` for the head it raised, the switch is absent when the head cannot see, and
  `apps/rodd/start.sh --vision` is the one command that gives you pictures. `apps/rodd/setup.sh --check` plus
  `bin/voice/voice-ensure.sh` mean an install, an update or `eir fix` builds the face without anyone having
  to remember. Proved: `gemma-4-12b-vision` answered "Red" for a real PNG in 1.2 s on this box, and
  `smoke.sh 45` passed every stage with `assistant audio arrived PASS 374784 bytes`.
- **2026-11-08 (latest)** — the voice gains the **shell and the MCP world** (`ls` · `read` · `edit` · `bash` ·
  `mcp_tools` · `mcp`; 34 hands in all). The laws are stated where a person reads them — ask out loud before
  anything that writes, the secrets shelf and destructive commands are refused outright, and an MCP server
  that needs OAuth says so. Verified with the tools themselves: Chrome DevTools over MCP read the live page,
  its 34-tool list and its clean console; the gates were walked through the toolbox
  (`bash` → NOT DONE then ran on confirm; `rm -rf /` → refused). Plan: 132 §41.

## 2026-11-08 — talking to the arm: the one hand Rödd was missing

### What it is

Rödd could act, but it could not **reach the session that holds the arm** — the mind that drains
wakes, sends the workers out and answers. It drives its own pi session, and two sessions with no
wire cannot talk. It has that wire now, in two hands:

- `talk_to_arm` — hands the arm holder a message in your words;
- `hear_from_arm` — reads what the arm has answered since Rödd last listened.

Both call **one door**, `bin/voice/rodd-arm.sh`, so a person, a script and the voice all take the
same road.

### What you need

Nothing to install: no port, no socket, no daemon. The door reads the **arm lease**
(`$YMIR_HOME/state/.arm.lease`) and appends into the queue that lease names — the same durable
queue Sága drains at the start of a turn.

### The commands

```bash
bin/voice/rodd-arm.sh who            # who holds the arm, the state dir, and the heartbeat's age
bin/voice/rodd-arm.sh tell "text"    # hand the arm holder a message
bin/voice/rodd-arm.sh hear [n]       # read the arm's unread replies (default 20, `all` for every one)
bin/voice/rodd-arm.sh room           # where the room is and how many replies it holds
bin/voice/rodd-arm.sh --check        # the one-line verdict, for a health surface
bin/voice/rodd-arm.sh --self-test    # prove the door against a synthetic lease in a temp state
```

### The three laws it holds

1. **Nobody armed, nothing sent.** With no lease, a dead pid, a reused pid or a heartbeat older than
   `BROKK_WATCH_HEARTBEAT_STALE_SECONDS` (60 s), the door says `no arm is held` and exits 3 — and
   `tell` writes nothing at all. Rödd then says that to your face instead of "sent".
2. **The lease names the state, never a path in the code.** Two state shelves exist on some seats;
   only the one named in `state=` is drained by the arm. A lease naming a directory that is not
   there is refused, never created.
3. **One writer per file.** The arm writes `rodd/room.jsonl`; Rödd only reads it, advancing a byte
   cursor. Reading never truncates, so a reply is never destroyed by being heard.

### Limits

- It is **not synchronous**. The arm answers on a later turn — Rödd says "the arm has not written
  back yet" until a reply lands in the room.
- One message per call, as one plain line: tabs and newlines are flattened (the queue is
  tab-separated).
- A voice still cannot merge, push, spend or unseal anything by talking to the arm.

### If it does not work

- `no arm is held` while a window is open → `bin/voice/rodd-arm.sh who` names why: no lease, a dead
  pid, a leftover lease (pid reused), a stale heartbeat, or a `state=` that is not a directory.
- the arm never answers → `bin/voice/rodd-arm.sh room` says how many lines the room holds; the arm
  writes `rodd/room.jsonl` under its own `state=`, and only when it chooses to.
- Proved by `bin/voice/tests/test_rodd_arm.sh` (28 checks) and the door's own `--self-test`
  (38 checks), both run by `bin/gates/ci-verify.sh`.

### CHANGE LOG

- **2026-11-08** — added at the Allfather's word (*"can we also make a tool for rödd so you and rödd
  are connected … to the gna arm holder"*). Plan 223; fix note
  `docs/fixes/voice/2026-11-08-rodd-knocks-on-the-arm.md`.

## 2026-11-09 — four hands, and a boot that no longer crashes

His word: *"rödd need sessions … rödd have no tools to talk to eindris … rödd need to be able to
make and move meetings in my calendar."* Plan 231. Measured first: Rödd was **not** toolless — its
log shows `toolbox {"ok": true, "tools": 37}`. It lacked the handles, and its window died on a boot
path, not on a compositor.

### The four hands it now has

```
hand              asks                          answers with
arm_who           bin/voice/rodd-arm.sh who     the holder's pid, generation and heartbeat age — or "nobody holds the arm"
eindri_list       herdr agent list              every seated worker: pane · state · directory
eindri_send       bin/agents/eindri-send.sh     the door's own `sent` or `FAILED`; a FAILED is never spoken as sent
calendar_write    calendar-write.sh             the event it made or moved, or the scope it lacks, by name
```

Say "who is holding the arm", "what are the workers doing", "tell the one in w49 that…", or "move
my eleven o'clock to two" and it reaches for those doors. A refusal is **spoken**, never hidden:
the voice says the arm is not held, or that the calendar grant has no `calendar.events`, instead of
claiming a message was sent or a meeting was made.

The calendar hand is `docs/features/make-and-move-meetings.md`; it refuses by scope and never
writes to a local calendar.

### The boot is a sentence, not a crash

The window spawns the demo's own uvicorn. When that spawn failed it used to wait the full deadline
and then reject into an unhandled promise — which Electron answers with a crash (the SIGTRAP in the
core file). Now: the last twenty stderr lines are kept, a missing interpreter is caught at once,
**one** console line names the interpreter and the directory, the app pauses and retries **once**,
and then a window shows *"The UI server did not start"* with the log path and the last lines, and
the process exits with code 1. Prove it without a display:
`node apps/rodd/smoke/test-boot-path.mjs`.

### Limits

- `eindri_send` delivers one line and returns the door's word; the worker's answer arrives later, in
  its pane — read it with `pane_read`.
- `calendar_write` can only write when the grant carries `calendar.events`. Until the grant is
  re-consented (`bin/mail/connect.sh google`) it refuses, and says so — the read side is unaffected.

### CHANGE LOG

- **2026-11-09** — the four hands and the boot path (plan 231 R1/R3); fix note
  `docs/fixes/voice/2026-11-09-rodd-gets-his-four-hands.md`.

## 2026-11-11 — one helm, any harness (Rödd holds the arm)

### Which harnesses may hold the helm

The helm is **one session per state dir**, and it is **harness-blind** — the session lock
binds to any verified harness (`pi` · `opencode` · `claude` · `cursor` · `codex` · `grok` ·
`kimi` · `muse` · `hermes`), never to Pi alone. Three of them can hold it **today**, and
plan 254 proves rather than builds that:

- **Pi** — the main seat, the ordinary holder;
- **Claude Code** — a Claude seat opened OUTSIDE `~/ymir` resolves the house through its
global hook and takes a wake;
- **OpenCode** — an idle OpenCode TUI attaches through its plugin and a wake defeats
  `session.idle`.

A **second live session** while another holds the helm prints
`watcher: read-only - this session does not hold the helm` and exits 0 — the one-helm rule
is enforced, not assumed.

### The lease now names the holder

The arm lease (`state/.arm.lease`) gains a `role=` field beside `mode=`. `mode=` keeps its
own meaning (the service shape, `systemd|daemon`); `role=` names whose helm it is:
`counsellor` for a Pi seat, `rodd` for Rödd's helm, `claude`/`opencode` where the holder
declares it. A lease with no `role=` reads `role=unknown` — never a guess. Every reader
(`rodd-arm.sh who` · `lock-ask.sh` · `syn-watch.sh status`) reports it.

### Nanna carries the duties

**Nanna** is the agent inside Rödd, and holding the helm without the duties is the thing
plan 254 refuses. Her duty loop is **one** thin door, `bin/voice/rodd-helm.sh`, which calls
the doors that own each duty rather than re-implementing them:

- **drain** the wake queue — `bin/time/saga-wake-drain.sh` (read, then ack the handled);
- **answer the room** — append `{ts,from,text}` to `<lease state>/rodd/room.jsonl`, append-only;
- **raise the alarm** — `ymir-say.sh --mark-alarm` (her voice + a desktop toast);
- **dispatch an errand** — `bin/agents/einherjar-spawn.sh`, `direct-PR`/`no-mistakes` ONLY;
- **refuse and release** — `rodd-arm.sh release` when a duty is beyond her.

A refused wake is **spoken, never dropped**: the refusal is written to the room and said
aloud, and the helm is released so the next seat can take it.

### hold and release

`bin/voice/rodd-arm.sh` gains `hold` and `release`:

```bash
bin/voice/rodd-arm.sh hold      # take a vacant helm for Rödd (refuses a live holder)
bin/voice/rodd-arm.sh release   # give it back (the next live session claims it on its next arm)
```

The handover is announced in the room with both pids. A `hold` while another live seat
holds the helm is refused with the holder's pid — never a forced steal, which the lock
already refuses.

### CHANGE LOG

- **2026-11-11** — the lease names the holder (`role=`), the one-client claim gains
  `--holder`, Nanna's duty loop lands in `rodd-helm.sh`, and `hold`/`release` move the helm
  without a reboot (plan 254); fix note
  `docs/fixes/voice/2026-11-11-rodd-holds-the-arm.md`.
