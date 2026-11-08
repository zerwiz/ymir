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
- a head model named: the door **refuses to guess one** (`YMIR_VOICE_HEAD_MODEL`).

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

The voice holds seven doors: `search_home` and `read_home_file` (your own documents — never the
vault, never the secrets shelf), `read_mail` (read-only: it can never send or delete), `add_todo`
(its own `todo-voice.md` beside yours; your own `todo.md` stays yours to write), `hand_over` and
`steer_worker` (work to a worker in a herdr pane), and `recall` / `remember` (the well).

Every one of them writes a line to `$YMIR_HOME/hodd/state/voice/activity-YYYY-MM-DD.jsonl`, and the
same view is one button away in Hlidskjalf — *Show what it has done*.

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
  the pipeline's message shape; choose another head.

## CHANGE LOG

- **2026-11-07** — written. The operator's page for Rödd, the streaming voice: the door, the fifteen
  hands (now twenty-five), the app, the toolbox, and the faults each one paid for. Appended to, never
  rewritten (RULES/06).
