## agents · 2026-10-23 — the voice came back as text for seven hours

**His question:** *"why are skirnoitr not answering back in telegram he dont make cvoice back or typing"* — then
*"he should answer with voice back on voice messages"*. Two faults, both silent, both his.

```
measured[4]{fact,evidence}:
  "the voice was lowered at 12:29 and never raised","`kokoro-serve.service`: `Stopping … 12:29:18`. From then to 19:30 every voice answer was text"
  "the mouth was the ONE speaking door that never raised it","`snotra-meet.sh` has `ensure_voice()`, `snotra-talk.py` and `snotra-voice.py` both start the unit; `bin/assistant/mouth.sh` only POSTed to a server it assumed was up"
  "one `sendChatAction` is not a typing indicator","Telegram lapses it in ~5 s; the 19:28 answer took 61 s, so he saw a dead bot while it thought"
  "a slow answer killed the bot","01:55:11 `subprocess.TimeoutExpired` escaped `main()` → exit 1 → systemd restart; his message was dropped with no sentence"
```

**The fixes, each a guard:**

- `mouth.sh` — takes the TTS **lease first** (so the stop-rule cannot lower the voice in the gap), then
  `systemctl --user start kokoro-serve.service` and waits up to `MOUTH_WAIT_SECONDS` (30) for :8765; if
  the card is full (500 CUBLAS) it frees the rail through `~/.local/bin/voice-gpu-lib.sh` and retries
  once. Only a voice that cannot be raised exits 3, with the sentence and the host:port.
- `telegram.py` — the indicator is **kept alive** every 4 s while the engine thinks, `record_voice` is
  shown for a voice note, and `ANSWER_TIMEOUT` (120 s) is caught so a slow engine *says* it is slow
  instead of killing the adapter.
- `smoke.sh` — section F used to prove *"a dead synthesiser fails loudly"*, which the fix makes false.
  It now proves both: a stopped kokoro is **raised and spoken from**, and a synthesiser that cannot be
  raised (`KOKORO_URL` → a closed port) exits 3 without hanging.
- `bin/time/housewatch.sh` — the watcher meant to catch this was itself **dead** (its unit ran a bash
  script with `python3`, `SyntaxError` at line 23, failed every 15 min). Now runs, and gained the voice
  surface: kokoro down while the TTS lease is fresh is a HIGH; kokoro down with no lease is
  *idle-lowered, as designed*.

**Measured after:** mouth from a stopped kokoro → 12 235 B in 4 s, rc 0 · unraisable voice → rc 3 in 3 s ·
`bin/assistant/smoke.sh` → 38 pass · 0 skip · 1 fail · a real `sendVoice` to his DM → `ok: true`,
`audio/ogg`, 8 s. The one fail is the far-side ear, which names `snotra-whisper.service` — a unit that
does not exist on this box; the ear still hears through the `whisper-cli` fallback (~1 s).

**The rule this earns:** *a service a door depends on may be idle-lowered only if the SAME door can
raise it.* The lease guard protected the middle of a conversation; a conversation that *starts* after
the idle-stop is the common case, not the edge.
