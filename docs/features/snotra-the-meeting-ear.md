# Snotra — the meeting ear

## What it is

**Snotra** is Ymir's meeting ear: it **captures** a call, **transcribes** it locally, and
**mines the minutes** into the hoard. On the meeting seat it watches for the call edges,
records, transcribes with whisper.cpp, extracts action items, and exposes a **read‑only**
face so an agent can read meetings without writing them.

## What you need

- A seat with a **microphone** (a call seat); a headless heart reports a clean skip.
- The engine: `systems/snotra/services/ear/snotra-ensure.sh` discovers it and installs what is
  missing (whisper.cpp + one model). Arch: `pacman -S whisper-cpp`. Debian/Ubuntu: the same
  packages are unpacked **without root** into `~/.local/opt/whisper.cpp` (needs only
  `apt-get download` and `dpkg-deb`), so a seat whose `sudo` wants a password still gets an
  engine. If neither road can finish, the installer prints the one command for you and exits
  3 — it never claims success.

## Do it

```bash
systems/snotra/services/ear/snotra-ensure.sh status            # engine + model present?
systems/snotra/services/ear/snotra-ensure.sh ensure --install  # install what is missing
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
| The installer exits 3 | It needs your hand: run the one command it printed (usually `sudo apt-get install -y whisper.cpp`), then `status`. |
| The engine is found but nothing transcribes | Check the audio is 16 kHz mono; the door normalises with `ffmpeg` when present and copies otherwise. |
| The watch never fires | The seat has no mic — expected on a headless seat; check the `fleet` step's capability raise. |
| No minutes in the hoard | The pipeline did not complete — check the job log and the hoard's minutes path. |

## Is it listening? — the ear's own voice

**What it is.** `bin/records/snotra-what.sh` — Snotra says what it is doing, in the sentence
it never used to say. Before this door the ear took the microphone for three days and said
nothing, and a watch that had stopped was indistinguishable from one that worked.

**What you need.** Nothing beyond `$YMIR_HOME`. It reads the state files the watch already
writes (`.snotra-detect.json`, its decision log, the capture's pid/outfile markers) and the
meeting folders — it keeps no record of its own.

```sh
bin/records/snotra-what.sh now            # armed/idle · the rule that decided · since · until
bin/records/snotra-what.sh now --brief    # the one line the 07:00 daily brief carries
bin/records/snotra-what.sh last           # the last capture: when, how long, who, where the minutes are,
                                          # and whether the pipeline FINISHED or STOPPED AT a step
bin/records/snotra-what.sh plan <id>      # the four rungs, and the one it is blocked at
bin/records/snotra-what.sh week           # the last 7 days: captures, meetings, minutes, promises
bin/records/snotra-what.sh off --reason "…"   # his hand: the watch will not arm; the reason is recorded
bin/records/snotra-what.sh on             # his hand lifted
```

**Every step speaks.** The ear sends seven events to the hotline
(`bin/notify/send.sh --source snotra`): it **armed** · it **left** · the **capture started** ·
the **capture stopped** · the **transcript is ready** · the **minutes were filed** · and any step
that **FAILED** (with the reason). Before this, two of the seven were wired to a door whose root
was computed wrongly, so the whole set was silent.

**A silent ear is reported as silent.** A watch that is active with nothing captured in 24 hours
prints `no call seen in 24h` in `now` and in the daily brief — the sentence that would have
saved three days of dropped calls.

**What it refuses to do.** It never opens a microphone to say what it is doing, and `off` never
edits the unit: the reason is written into the state file (`$YMIR_HOME/state/.snotra-off`) and
the watch reads it and refuses to arm.

**If it does not work.** `bin/records/snotra-what.sh --self-test` builds a fixture state and
proves every verb (including `off`/`on` and the silence line) without touching the house's own
state. If `now` says `not watching`, the unit is not running: `systemctl --user status
snotra-detect.service` (the unit name is `SNOTRA_WATCH_UNIT` if yours differs).

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
