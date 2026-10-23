## snotra · 2026-10-23 — the instrument, the shim, the seat and the lease

Four things that were built in one night of silent failures, and the reason each exists.

### 1 · `bin/assistant/smoke.sh` — the answer to "are we working?"

**Twenty-one real paths in one command**, each PASS / SKIP / FAIL, exit 1 on any fault. A skip is PRINTED
(`Rule 25`): *"not tested here"* must never read as *"passes"*. It covers the engine, the matcher, the Ymir
pitch, the digest, the canaries, kokoro, the TTS lease, the mouth, the ear, the calendar, research, the ask
ledger, the handoff naming, the Trello resolve, the seat guard, the idle-stop lease, the backup, the group
door and the far-side ear's chain. **Tonight: 21 pass · 1 skip · 0 fail**, and a cron row at 07:25 notifies
the Allfather when it goes red.

Two behaviours it deliberately has: it **wakes** the TTS before testing it (the idle-stop is right to lower
an unused voice — a voice that cannot be *raised* is the fault), and it **skips** the meeting chain with the
reason instead of pretending.

### 2 · `bin/time/snotra/stt-shim.py` — the contract the whisper does not speak

The meeting stack appends `/v1/audio/transcriptions`; whisper.cpp answers only `/inference`. The shim is
that one path and nothing else: `POST /v1/audio/transcriptions` (multipart `file`) → decode to **16 kHz
mono** → forward to whisper → `{"text": …}`; `GET /health` → ok. **It keeps no copy of the audio and holds
no credential.** Measured: `smoke-voice.ogg` → `{"text": "smoke test of The Voice."}`.

### 3 · `bin/time/snotra/stt-wire.sh` — the chain, in the only order that works

whisper → shim → **container reachability** → env → restart. `check` prints the honest state and names the
remedy; `wire` **refuses to flip the environment while the path is closed** (replacing a 503 with a
probe-refused spawn is a different lie, not an improvement). The blocked link tonight is the host firewall:
`ufw` denies the docker bridge, proven because the host's own sshd, the rail and the shim are all `000`
from a container on `vexa-v012_vexa`.

### 4 · `bin/time/snotra/tts-lease.sh` + the seat guard — the two silent deaths

- **the voice**: `kokoro-idle-stop` stopped a healthy server five minutes after every start because **no
  caller touched its stamp**. Every synthesis now touches it, Skírnir's conversations hold a 15-minute
  lease, and the idle-stop consults both.
- **the seat**: `snotra-meet.sh seat` enforces **launch about:blank → install the bridge → navigate → join
  → unmute → verify `in_call && bridge`**, and returns 4 with a sentence otherwise. A seat that would use
  the host's microphone is a refusal now, not a success.

**Also in this branch:** Rule 30 (audio is ephemeral) with its index row, `audio-retention.sh` (Opus, three
tiers), `trello-map.sh` (the map, list ARIs, resolve-by-name), and the assistant's **Ymir pitch** — asked
about Ymir he now teaches in paragraphs, naming only the figures the facts name.
