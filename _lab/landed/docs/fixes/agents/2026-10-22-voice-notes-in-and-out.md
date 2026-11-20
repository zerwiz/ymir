## agents · 2026-10-22 — a voice note in, a voice note out

**His question:** *"cant he her voice messeges in telegram? and answer with voice messeges?"* He could not: the
adapter read `message.text` only, so a voice note was an empty message and was dropped.

```
built[4]{piece,what_it_does,measured}:
  "`bin/assistant/ear.sh`","downloads the note, decodes to 16 kHz mono, and asks **Snotra's whisper server** (:10300, small.en, CUDA) — the same ear a meeting uses, so the house has ONE transcription path. `whisper-cli` is the fallback","round trip: 'Skirnir, what is OptiCat? The inspection is on Friday.' → heard back with the product name and the day"
  "`bin/assistant/mouth.sh`","speaks with Kokoro in the switcher's voice, normalises the text with `speech-text.py`, closes short gaps with `audio-tighten.py`, and encodes **OGG/Opus** — the only format `sendVoice` accepts","19,437 bytes for one sentence"
  "`telegram.py` — in","a `voice`, `audio` or `video_note` message is fetched with `getFile`, transcribed, and treated **exactly like typed words**: same tiers, same walls, same gate. A voice note bypasses nothing","the words are logged like any other question"
  "`telegram.py` — out","if the message was a voice note, the answer goes back as a voice note with the text as its caption; if the synthesiser fails, it falls back to a text message","proved live: a voice note arrived in his DM"
```

**Two faults caught by his own paste:** the first two notes he sent (21:40, 21:42) hit the **old process** —
the restart came at 21:43 — and the caption of the first outbound note arrived **URL-encoded**
(*"This%20is%20Sk%C3%ADrnir…"*) because the code quoted a multipart field that curl already encodes. Both
are fixed: the caption is plain text now.

**Verified:** `walls-test` holds, and now includes *"the mouth makes a Telegram voice note"* and *"the ear
hears it back"* (with clean skips when the synthesiser or the ear is absent).
