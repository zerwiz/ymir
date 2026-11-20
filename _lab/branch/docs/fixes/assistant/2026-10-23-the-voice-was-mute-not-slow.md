## assistant · 2026-10-23 — the voice was mute, not slow: a template read as four commands

### Why

Every Telegram voice reply from Brokk failed, for at least a day. The bridge log carried three
lines per turn and nothing else:

```
multipart  Unable to open file as blob   {"method":"sendVoice","fileName":"<uuid>-voice.ogg"}
voice      Unable to open file as blob   {"phase":"template-handler-send"}
delivery   Failed to send voice reply: every voice synthesis provider failed.
```

The mouth was healthy — it sang an eleven-kilobyte note in one second when driven by hand. The
fault was in `~/.pi/agent/telegram.json`:

```json
"template": ["bash", "/home/heimdall/ymir/bin/assistant/mouth.sh", "{text}", "{ogg}"]
```

pi-telegram's command-template standard reads an **array as a sequence of commands**, not one
command split into words (`docs/command-templates.md`, `docs/voice.md`). So the bridge ran four
steps: `bash` with the reply on stdin, then the mouth **with no arguments** (usage error, exit 2),
then the reply text as a command name, then the output path. No ogg was ever written, while
`output: "ogg"` still told the sender to upload `{ogg}`.

**Proved, not guessed:** a probe wrapper around the mouth logged `argc=0` — the handler was
invoked empty.

### The fix

1. **`bin/assistant/voice-handler.sh`** — one step. The reply arrives on **stdin** and is handed to
   the same one mouth (`mouth.sh`). A long sentence with an apostrophe is data now, not shell.
   Config becomes:
   `"template": "bash /home/heimdall/ymir/bin/assistant/voice-handler.sh {ogg}"`, `"output": "ogg"`.
2. **`bin/assistant/ear.sh` raises the mouth the instant his voice lands** (plan 121, phase 2).
   The synthesiser is idle-lowered after five quiet minutes and costs up to 30 s to raise — paid
   *before the first word* until now. The raise runs in the background, overlapping transcription
   and the head's thinking, and writes nothing to stdout (that stdout is the transcript).

The inbound `inboundHandlers[].template` is the **other** shape — a flat array of command parts —
and is correct as it stands. Do not "fix" it to match the outbound one.

### Verified

- `voice-handler.sh` with text on stdin: a 10 KB ogg in ~1 s.
- Live through the bridge (22:14): a 154 KB `…-voice.ogg` written in the attachments dir and **no
  failure event** — a successful `sendVoice` is silent, only refusals are recorded.
- `ear.sh` with kokoro **stopped**: transcript returned in 1.10 s, kokoro `active` seconds later.

### Owed

The extension that makes the lane *fast* rather than merely working — mouth warm from arrival,
`voice_speak` mid-turn, and a per-turn stopwatch — is plan 121's phase 3 and is not in this change.
