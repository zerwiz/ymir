// chat-ladder.ts — which model answers when the one we asked for cannot load, and how the
// chat says so (plan 275 item 23).
//
// WHAT BROKE (measured 2026-11-14 03:16): the rail failed to load `qwen3.6-35b-a3b`
// (cudaMalloc of 1,184 MiB) and `apodex-1.0-mini` (3,314 MiB) — out of memory — while Rödd's
// voice engine held 2,762 MiB of the same 16 GiB card. Bifrost was pointed at a retired LM
// Studio, so the chat's other road answered 500 too, and the operator was told only
// "no model backend answered".
//
// Two duties live here, as pure functions so they can be proved without a server:
//
//   1. THE LADDER: after the models the operator asked for, the chat tries the ones that
//      FIT — the small local preset that runs beside the voice, then the online road.
//   2. THE WORDS: when a different model answered, the reply says which one and why; when
//      nothing could load and the card was full, it says *the card is busy with the voice*
//      instead of showing a bare 500.
//
// This module holds no opinion about which models exist — the catalogue does.

export type ChatKind = 'local' | 'online';

export interface Target {
  base: string;
  model: string;
  key?: string;
  label: string;
  kind: ChatKind;
}

export interface CatalogEntry extends Target {
  id: string;
  name: string;
  provider: string;
}

// The words a full card uses. llama.cpp says `cudaMalloc failed: out of memory`, CUDA says
// `CUDA error: out of memory`, and a smaller build says `failed to allocate`. A chat that
// reads any of them knows the fault is the CARD, not the model.
const STARVED = [
  /cudaMalloc/i,
  /out of memory/i,
  /CUDA error/i,
  /failed to allocate/i,
  /unable to allocate/i,
  /not enough memory/i,
  /GGML_ASSERT[^\n]*alloc/i,
];

/** Did the rail refuse because the card could not hold the model? */
export function vramStarved(text: string): boolean {
  if (!text) return false;
  return STARVED.some((re) => re.test(text));
}

/** The models that fit when the one asked for cannot load, in the order they are tried. */
export function fitsTargets(
  catalog: CatalogEntry[],
  opts: { fitsModel?: string; exclude?: Target[] } = {},
): Target[] {
  const fitsModel = (opts.fitsModel ?? '').trim();
  const exclude = opts.exclude ?? [];
  const seen = new Set(exclude.map((t) => `${t.base}|${t.model}`));
  const out: Target[] = [];
  const push = (t: Target) => {
    const key = `${t.base}|${t.model}`;
    if (!t.base || !t.model || seen.has(key)) return;
    seen.add(key);
    out.push({ base: t.base, model: t.model, key: t.key, label: t.label, kind: t.kind });
  };
  if (fitsModel) {
    // The named small one, the seat's own local copy first: a preset beside the voice is
    // worth more than a second copy of the same model on someone else's rail.
    const named = catalog.filter((e) => e.model === fitsModel || e.id === fitsModel || e.name === fitsModel);
    for (const e of named.filter((e) => e.kind === 'local')) push(e);
    for (const e of named.filter((e) => e.kind !== 'local')) push(e);
  }
  // Then every online road: it costs the card nothing at all.
  for (const e of catalog) if (e.kind === 'online') push(e);
  return out;
}

/** Saying which model answered, and why it was not the one asked for. */
export function answeredNote(
  asked: string,
  used: Target,
  opts: { starved?: boolean; voiceMib?: number } = {},
): string {
  const what = used.model || used.label || used.base;
  const askedFor = asked && asked !== what ? asked : '';
  const why = opts.starved
    ? opts.voiceMib && opts.voiceMib > 0
      ? `the card is busy with the voice (${fmtMiB(opts.voiceMib)} held by the voice engine)`
      : 'the card was full and the bigger model could not be loaded'
    : used.kind === 'online'
      ? 'the local card could not serve it'
      : 'it was the first model that could answer';
  const askedBit = askedFor ? `the one asked for (${askedFor}) could not be loaded, so ` : '';
  return `Answered by ${what} — ${askedBit}${why}.`;
}

/** When no model answered at all: name the real fault, never a bare status code. */
export function noAnswerMessage(
  lastErr: string,
  opts: { starved?: boolean; voiceMib?: number; totalMib?: number; asked?: string } = {},
): string {
  const asked = opts.asked ? `${opts.asked} ` : 'the model ';
  if (opts.starved) {
    const card = opts.totalMib ? ` of the ${fmtMiB(opts.totalMib)} card` : '';
    if (opts.voiceMib && opts.voiceMib > 0) {
      return (
        `The card is busy with the voice — the voice engine holds ${fmtMiB(opts.voiceMib)}${card}, so the rail ` +
        `could not load ${asked.trim()}. The engine lets go after a quiet window (bin/voice/voice-idle.sh status); ` +
        'ask again then. Recall ran.'
      );
    }
    return (
      `The card is full${card}, so the rail could not load ${asked.trim()} (out of memory). ` +
      'Free the card, or pick a smaller model. Recall ran.'
    );
  }
  return `The well is local; no model backend answered (${lastErr}). Recall ran; for a reply, raise a local model (llama-server on :8080) or the Bifrost bridge (\`bin/bridge/bifrost-bridge.sh\`).`;
}

/** 2,762 MiB — thousands separators, because 2762 is a number and 2,762 is a fact. */
export function fmtMiB(mib: number): string {
  const n = Math.round(Number(mib) || 0);
  return `${n.toLocaleString('en-US')} MiB`;
}

/** The deduplicated ladder: what was asked for first, what fits after it. */
export function chatLadder(primary: Target[], fits: Target[]): Target[] {
  const out: Target[] = [];
  const seen = new Set<string>();
  for (const t of [...primary, ...fits]) {
    const key = `${t.base}|${t.model}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(t);
  }
  return out;
}
