# 28 — Streaming voice: Skírnir speaks in real time, or he does not speak

**Appended 2026-10-22** at the Allfather's word: *"it need to be streaming ai … make a rule. its law
that skirmir are streaming ai voice talking."*

**Why it exists, from this day's own wounds.** A meeting voice was built in two-second blocks: it
drained the room, transcribed the block, composed an answer, rendered the whole answer, then played
it. It joined the room twice, it was admitted beside the ear, and it said nothing for an hour — the
compose took **19.7 s cold**, the answer was **muzzled to two sentences**, and when the card was full
the synthesiser returned **500 with CUBLAS failure 3 and the loop counted 0.0 s of audio** as if it had
spoken. Nothing failed loudly, because nothing was required to be fast, and nothing was required to
prove that sound arrived.

The published numbers say the same thing from outside: perceived willingness drops after **600 ms** and
the exchange feels broken at about **1 s** (Deepgram, 2026); time-to-first-audio is the whole pipeline,
the largest line items are the model's time-to-first-token and endpointing, and **overlapping the stages
rather than running them in series recovers most of the budget** (ElevenLabs, 2026); production voice
agents run as a **pipeline over a transport** — `input → STT → context → LLM → TTS → output` — with the
speech streamed text-in, audio-out (Pipecat/LiveKit), and the groups that tried a blocking pipeline
rebuilt onto exactly that (SAP Architecture Center, 2026-10-20).

```
streaming_law[9]{rule,what it means}:
  "THE VOICE IS A PIPELINE, NOT A REQUEST","every speaking agent runs five stages that OVERLAP: continuous capture · incremental ASR · endpointing · token-streamed answer · sentence-pipelined TTS. A stage that waits for the previous one to finish is a phone call with a delay on it, not a conversation."
  "CAPTURE IS CONTINUOUS","audio is drained from the transport as it arrives (≲250 ms hops). A capture loop that sleeps for whole seconds is a transcription service, not an ear."
  "ASR IS INCREMENTAL","a rolling window is transcribed repeatedly and only the DELTA is kept, so the transcript forms while the human is still speaking. Silence is not the trigger for transcribing; it is the trigger for ending a turn."
  "ENDPOINTING IS ITS OWN STAGE","a deliberately short silence window (VAD with a hangover, ~700 ms) ends the turn. Waiting for a long quiet to be sure is a bug, not caution."
  "THE ANSWER STREAMS","the model's tokens are cut at sentence boundaries as they arrive, and the FIRST sentence goes to the synthesiser immediately. A voice that renders the whole reply before the first word is spoken has failed this rule even if every other part works."
  "THE MOUTH IS PACED, NOT DUMPED","synthesised audio is pushed into the meeting's microphone in real-time frames. Handing a client a whole file is not speaking."
  "TEXT LENGTH IS CONTENT, NOT A MUZZLE","the voice may read long text when the matter needs it; what is forbidden is a LONG SILENCE while it is prepared. Stream it sentence by sentence and the answer may run to the subject's length (the current ceiling: 8 sentences / 120 s before yielding the floor)."
  "LATENCY IS A CONTRACT, AND IT IS MEASURED","every turn records stt_ms, ttft_ms, first_audio_ms and turn_ms in the voice log. Target: first audio ≤ 1.5 s after the addressed utterance ends on this hardware; a reported P50/P95 is part of the feature. A turn with no numbers is not done."
  "A SILENT FAILURE IS A VIOLATION","a dead synthesiser, a full GPU, a refused request or an empty audio buffer MUST be reported by name. The failure that wrote this rule is the one that returned 0.0 s of audio and looked like success."
```

```
the_two_gates[2]{gate,pass_condition}:
  "the oracle, on the bench","render a sentence → push it into the microphone path → record that same path → transcribe → the words must match. No meeting is touched until this passes."
  "the room, before any claim","the meeting's own recording must contain the sentence. 'The stream reported success' is not evidence that a human heard anything."
```

**The mouth and the ear never depend on the operating system mixer.** Measured on 2026-10-22: a
PipeWire null sink's monitor read digital silence while a sink-input played, `pw-record --target` was
ignored and recorded the default microphone instead, and a joined browser participant was never heard
in the room. The working path replaces `getUserMedia` inside the meeting client and tees its remote
tracks — the client is the audio device, and behaviour is measured, never assumed.

**Enforced by:**

- **`systems/snotra/services/ear/snotra-voice.py`** — the streaming loop (capture → ASR → endpointing → streamed
  answer → sentence TTS → paced push), writing its own latency per turn to
  `$YMIR_HOME/hodd/state/snotra/voice-stream.log`.
- **`systems/snotra/services/ear/snotra-cdp.py selftest`** — the oracle. A voice path that has not passed it may not
  be pointed at a meeting.
- **`systems/snotra/services/ear/snotra-meet.sh`** — the door that joins, tests and runs; it refuses to run without
  a voice engine and frees the GPU before speaking.
- **the room's recording** (Vexa `GET /recordings/<id>/media/<fid>/raw?type=audio`) — the judge of every
  audibility claim, transcribed, not assumed.

**The duty, in one sentence:** *if Skírnir is in a room, he is streaming — hearing while they speak, and
answering as the first sentence forms — and the numbers that prove it are in the log.*

---

## Correction (2026-10-24) — the paths above moved to Snotra's own shelf

Appended, not rewritten (Rule 06). Plan 129 moved the meeting system out of the time shelf on 2026-10-24:
`bin/time/snotra/<door>` became `systems/snotra/services/<service>/<door>`. The command examples in this rule were
repointed on the same day and are live; the move's own record is `.agents/paths-ledger.yaml` (migration
`0014-systems-shelf`) and the fix note `docs/fixes/snotra/2026-10-24-snotra-becomes-a-system.md`.

What this rule names, in its new spelling:
- the streaming loop, the CDP oracle and the door that joins them: `snotra-voice.py`, `snotra-cdp.py selftest`, `snotra-meet.sh`

A shim survives at the old path so nothing breaks while callers are repointed; it is retired by that dated fix
note, never silently. The law in this file is unchanged — only the shelf the doors are kept on.
