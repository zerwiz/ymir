# Snotra — the meeting ear

## What it is

**Snotra** is Ymir's meeting ear: it **captures** a call, **transcribes** it locally, and
**mines the minutes** into the hoard. On the meeting seat it watches for the call edges,
records, transcribes with whisper.cpp, extracts action items, and exposes a **read‑only**
face so an agent can read meetings without writing them.

## What you need

- A seat with a **microphone** (a call seat); a headless heart reports a clean skip.
- The engine: `bin/time/snotra/snotra-ensure.sh` discovers it and installs what is
  missing (whisper.cpp + one model); Arch: `pacman -S whisper-cpp`.

## Do it

```bash
bin/time/snotra/snotra-ensure.sh status            # engine + model present?
bin/time/snotra/snotra-ensure.sh ensure --install  # install what is missing
```

- **The watch** (`snotra-detect`) is raised by capability on any seat with a mic; it is
  what notices the call.
- **The MCP face** is read‑only, on `:8321` (the heart) — an agent reads meetings; it
  cannot post.
- **The minutes** land in the hoard (`$YMIR_HOME/hodd/...`), never the tree.

## Notes and limits

- **Local and private.** Transcription is whisper.cpp on the seat — audio does not go to
  a cloud by default.
- **Read‑only face.** The MCP lets an agent *read*; writing minutes is the pipeline's, not
  the agent's.
- **Capability‑gated.** No microphone, no watch — and the seat says so rather than
  pretending.

## If it does not work

| What you see | What to do |
|---|---|
| `status` shows the engine missing | `snotra-ensure.sh ensure --install` (per‑OS road printed). |
| The watch never fires | The seat has no mic — expected on a headless seat; check the `fleet` step's capability raise. |
| No minutes in the hoard | The pipeline did not complete — check the job log and the hoard's minutes path. |
