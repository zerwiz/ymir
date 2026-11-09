## voice · 2026-11-09 — the voice host will not take the microphone from a live call

### His words

"why are we uing the mic at all??? we should lissen internally" · "the mic should not be used".

### What was already true, and what was not

The **ear** already obeys that law and has since 2026-10-31 — `snotra-detect.sh` and `snotra-capture.sh` both refuse unless
`SNOTRA_LOCAL_ROOM=1`, with the reason written at the call site: *"the microphone is NEVER used to hear an online meeting …
an online meeting is heard by the bot, which joins the call and needs no microphone on this box at all."* Verified tonight:
the unit carries no `SNOTRA_LOCAL_ROOM`, so the ear cannot arm into a call.

The **voice door** did not. `bin/voice/voice-door.sh` raises the streaming host (`systemd-run --unit=ymir-voice-host … serve`)
which opens the default source for VAD. It is not in autoboot and it is transient — but while it runs it holds the microphone,
and a client that renegotiates the device mid-call starves the other. That is the `[Chromium input] underrun … avail:0` we
watched, and the disconnect loop that followed.

### The fix

Before raising the host, ask `pactl` who is capturing. If any client other than the voice pipeline itself holds a source-output,
**refuse with its name**:

```
refused: 'Chromium input' holds the microphone — the voice host will not take it from a live call
hint: leave the call first, or stop it, then raise the voice door again
```

Exit 3. The guard measures rather than assumes, and it names the holder so the refusal is actionable.

### Also landed tonight, and worth recording with it

- `snotra-detect`'s drop-in now points the capture at the **sink monitor** (`SNOTRA_MONITOR=<default sink>.monitor`) with
  `SNOTRA_MIC` empty: the ear listens internally and opens no microphone at all.
- The Bluetooth card was moved from `a2dp-sink` (output only, no microphone, with a suspended `bluez_input` node a client could
  fall into) to `headset-head-unit`, so the headset has a real microphone instead of a dead node.

### Verified

- `bash -n bin/voice/voice-door.sh` — syntax clean.
- The guard evaluated live against this seat returns `Chromium input` — refused, which is correct while Discord holds the mic.

## CHANGE LOG

- **2026-11-09** — Carved: the voice host refuses to take the microphone from a live call, naming the holder.
