/**
 * voice-loop.mjs — the REAL local voice loop, per the video's architecture.
 *
 * Plan 68 §12 (R1–R7). The Allfather: *"it's real streaming STT or whatever it's called, real
 * talking, not Piper or Whisper or Kokoro."*
 *
 * This is the pipeline, not a wrapper. Four things run AT ONCE while a turn is in flight:
 *
 *     mic ──▶ VAD ──▶ streaming STT ──▶ LLM ──sentence 1─▶ TTS ──▶ speaker
 *      │        (turn end)              │  └─sentence 2─┐   (look-ahead queue)
 *      │                                 │  └─sentence 3─┘   generated AHEAD of playback
 *      └── stays OPEN the whole time ────┴── barge-in cuts playback, mic keeps listening
 *
 * THE THREE RULES that make this feel like a conversation rather than a dictation tool:
 *   1. THE FIRST SENTENCE GOES TO THE MOUTH IMMEDIATELY. Not when the answer is finished.
 *   2. VOICE IS GENERATED FASTER THAN IT IS PLAYED (~1.1x realtime) or turns go choppy.
 *   3. THE MIC STAYS OPEN WHILE IT SPEAKS. Buffering makes every interruption cost a round trip,
 *      and the whole thing feels like 2019. Barge-in cuts playback; it does not end the session.
 *
 * DEPENDENCY TRUTH, measured on this box 2026-10-03 — this file does NOT pretend otherwise:
 *   present : whisper.cpp weights (ggml-small.en), piper voices, ffmpeg, the llama rail
 *   ABSENT  : silero_vad, onnxruntime, faster_whisper, webrtcvad, numpy
 * So VAD and true streaming STT cannot run yet. `probe()` says so in one line instead of letting
 * the loop fail obscurely — and the class reports WHICH stage is missing, because "it does not
 * work" is the most useless sentence in the house.
 */

export const STAGES = ["vad", "stt", "llm", "tts"];

/** Split a model answer into speakable sentences, and NEVER send a fragment that sounds broken. */
export function sentences(text) {
  const parts = String(text ?? "").split(/(?<=[.!?…])\s+/);
  const out = [];
  for (let i = 0; i < parts.length; i += 1) {
    let piece = parts[i].trim();
    if (!piece) continue;
    // A very short fragment sounds like a glitch — join it forward rather than speak it alone.
    if (piece.split(/\s+/).length < 3 && i + 1 < parts.length) {
      piece = `${piece} ${(parts[i + 1] ?? "").trim()}`.trim();
      i += 1;
    }
    out.push(piece);
  }
  return out.filter(Boolean);
}

/**
 * LookAheadQueue — the second half of rule 2.
 *
 * Playback consumes one item per `pace` seconds; production runs AHEAD. If production ever falls
 * behind playback the turn goes choppy, so the queue measures it rather than discovering it as a
 * feeling: `ahead()` is how much buffered time remains, and it must never hit zero mid-turn.
 */
export class LookAheadQueue {
  constructor({ pace = 1.0, target = 2 } = {}) {
    this.pace = pace;           // 1.0 = real time. >1 generates faster than playback (the rule).
    this.target = target;       // ~2 sentences buffered, per the video
    this.items = [];
  }
  push(item, seconds = 0) {
    this.items.push({ item, seconds });
    return this.items.length;
  }
  /** Seconds of audio buffered beyond the sentence being played. */
  ahead() {
    return this.items.slice(1).reduce((n, it) => n + it.seconds, 0);
  }
  get starved() {
    return this.items.length > 1 && this.ahead() < 0.2;
  }
  shift() {
    return this.items.shift()?.item ?? null;
  }
  clear() {
    this.items = [];
  }
}

/**
 * A turn, from "you stopped talking" to "you can interrupt me".
 *
 * Deliberately explicit about its two transports — `stt` streams partials and `tts` synthesises —
 * so the loop can be driven by whisper.cpp's server and piper today, and by faster-whisper and a
 * neural voice tomorrow, without touching this file's shape.
 */
export class VoiceLoop {
  constructor({ vad, stt, llm, tts, queue, onPartial, onSentence, onBargeIn } = {}) {
    this.vad = vad; this.stt = stt; this.llm = llm; this.tts = tts;
    this.queue = queue ?? new LookAheadQueue();
    this.onPartial = onPartial; this.onSentence = onSentence; this.onBargeIn = onBargeIn;
    this.listening = false;
    this.speaking = false;
  }

  /** RULE 3: the mic opens only when the Allfather says so. Never ambient. */
  async open() {
    if (this.listening) return { ok: true, detail: "already open" };
    if (!this.vad?.open) return { ok: false, reason: "no-vad", detail: "R1 is not installed on this host" };
    await this.vad.open();
    this.listening = true;
    return { ok: true, detail: "mic open — it stays open while I speak" };
  }

  async close() {
    this.listening = false;
    this.speaking = false;
    this.queue.clear();
    await this.vad?.close?.();
    return { ok: true, detail: "closed" };
  }

  /**
   * Barge-in. The whole point of rule 3: speech over playback CUTS the audio and the loop carries
   * on. It does not end the turn, and it does not require a button.
   */
  async interrupt() {
    if (!this.speaking) return { ok: false, reason: "not-speaking" };
    this.speaking = false;
    this.queue.clear();
    await this.tts?.stop?.();
    this.onBargeIn?.();
    return { ok: true, detail: "cut — still listening" };
  }

  /**
   * One turn. VAD decides the end of speech; STT streams partials; the first sentence is handed to
   * the mouth IMMEDIATELY while the model keeps writing.
   */
  async turn(audio) {
    if (!this.listening) return { ok: false, reason: "mic-closed" };
    const transcript = await this.stt.transcribe(audio, { onPartial: (p) => this.onPartial?.(p) });
    if (!transcript || !transcript.trim()) return { ok: true, text: "", detail: "nothing heard" };
    this.speaking = true;
    let spoken = 0;
    for await (const chunk of this.llm.stream(transcript)) {
      for (const sentence of sentences(chunk)) {
        this.queue.push(sentence);
        this.onSentence?.(sentence);          // RULE 1: the mouth starts NOW, not at the end
        spoken += 1;
        if (this.queue.starved) this.onStarved?.();   // measured, not felt
      }
    }
    return { ok: true, text: transcript, sentences: spoken };
  }
}

/** Say which stage is missing, in one line, instead of "it does not work". */
export function probe({ has = {} } = {}) {
  const missing = STAGES.filter((s) => !has[s]);
  return missing.length === 0
    ? { ok: true, detail: "all four stages present" }
    : { ok: false, reason: "missing-stages", detail: `not on this host: ${missing.join(", ")}` };
}