// why.js — Rödd says WHY, in a sentence and one action (plan 271 piece 3).
//
// A failed connect used to print `[object Event]`: a WebSocket error is an Event, not an Error,
// and String() of it says nothing. This maps every failure to ONE sentence and ONE action.
// `explain` is pure (so it can be tested headless with node); `roddWhy` asks the toolbox's
// /desk door for the two facts a browser cannot know: is the engine answering, and who holds
// the microphone.
//
// Causes: engine down · microphone held · microphone refused/missing · head refused · seat busy.

const TOOLBOX = "http://127.0.0.1:8891";

/** @param {unknown} err @param {{engine_up?: boolean, engine_port?: number, mic_holder?: string, mic_bluetooth?: boolean}} [desk] */
export function explain(err, desk = {}) {
  const raw = err instanceof Error ? `${err.name}: ${err.message}` : (err && err.type ? `event:${err.type}` : String(err));
  const name = err && err.name ? String(err.name) : "";
  const holder = desk.mic_holder || "";

  // the engine allows one session; a leaked slot refuses every newcomer
  if (/session_limit_reached|session limit|busy/i.test(raw)) {
    return { cause: "seat-busy",
      sentence: "The voice's one seat is already taken — another Rödd window, or a session that never closed, still holds it.",
      action: "Close the other Rödd window, or restart the engine: apps/rodd/start.sh" };
  }
  // the head (the model behind the voice) said no
  if (/\b(401|403)\b|unauthori[sz]ed|forbidden|invalid api key|api key/i.test(raw)) {
    return { cause: "head-refused",
      sentence: "The model behind the voice refused the key it was given.",
      action: "Open Settings → the head, and pick or re-enter its key." };
  }
  if (/\b(400|404|500|502|503)\b|model not found|failed to load/i.test(raw) && !/transport|socket/i.test(raw)) {
    return { cause: "head-refused",
      sentence: "The model behind the voice would not answer (it may be loading, or the name is not one the rail serves).",
      action: "Open Settings → the head, and pick another model, or try again in a few seconds." };
  }
  // rule 1 (plan 259 B2e): never assume a device. No input at all is a STATE, said as one — a missing
  // stream looks exactly like a mute, and Rödd must not pretend to be recording.
  if (desk.inputs === 0 || (name === "NotFoundError" && desk.inputs === 0)) {
    return { cause: "no-input",
      sentence: "There is no microphone on this machine right now, so nothing is being recorded.",
      action: "Plug in or switch on a microphone; Rödd will re-open the stream on its own." };
  }
  if (/microphone stream lost|track ended/i.test(raw)) {
    return { cause: "mic-lost",
      sentence: holder ? `The microphone stream ended while ${holder} also holds a microphone.` : "The microphone stream ended by itself.",
      action: "Rödd is re-opening it; nothing needs restarting (never the sound server)." };
  }
  // the microphone: the page's own getUserMedia failures carry a DOMException name
  if (name === "NotReadableError" || name === "AbortError" || /could not start audio source|device in use/i.test(raw)) {
    return { cause: "mic-held",
      sentence: holder ? `The microphone is held by ${holder}.` : "Another program is holding the microphone.",
      action: holder ? `Mute or leave ${holder}, then click the orb again.` : "Close the program using the microphone, then click the orb again." };
  }
  if (name === "NotAllowedError" || name === "SecurityError" || /permission denied|not allowed/i.test(raw)) {
    return { cause: "mic-refused",
      sentence: "This window was not allowed to use the microphone.",
      action: "Allow the microphone for Rödd in the system's privacy settings, then click the orb again." };
  }
  if (name === "NotFoundError" || name === "OverconstrainedError" || /requested device not found/i.test(raw)) {
    return { cause: "mic-missing",
      sentence: "No microphone was found" + (desk.mic_bluetooth ? " (the headset may have switched profile)" : "") + ".",
      action: "Plug in or select a microphone in Settings → audio, then click the orb again." };
  }
  // a socket that would not open or dropped, with nothing else said: ask who is at fault
  if (desk.engine_up === false) {
    return { cause: "engine-down",
      sentence: "The voice engine is not running, so there is nothing to talk to.",
      action: "Start it: apps/rodd/start.sh (or ask the helm to raise it)." };
  }
  if (/transport|socket|event|disconnected|network|failed to fetch/i.test(raw)) {
    return { cause: "line-dropped",
      sentence: "The line to the voice engine dropped, though the engine is still answering.",
      action: "Click the orb to connect again; if it repeats, restart the engine: apps/rodd/start.sh" };
  }
  const clean = raw.replace(/^Error: /, "").slice(0, 160);
  return { cause: "unknown", sentence: `Rödd stopped: ${clean}`, action: "Click the orb to try again." };
}

export async function roddWhy(err) {
  let desk = {};
  try {
    const r = await fetch(`${TOOLBOX}/desk`, { cache: "no-store" });
    if (r.ok) desk = await r.json();
  } catch { /* the toolbox itself being away is a fact explain() can use: desk stays {} */ }
  return explain(err, desk);
}

/** the one line the caption shows: sentence, then the action */
export function sayWhy(why) {
  return `${why.sentence} ${why.action}`;
}

// ── rules 2–4 of plan 259 B2e: reconnect on its own, say what was lost with the time, one record ──
//
// Rödd re-opens a lost stream IN PLACE — bounded: three tries inside five seconds — before asking a
// person to do anything. It never restarts pipewire, wireplumber or any audio unit: the sound
// server is shared, and that remedy drops every other client in the same second.

/** causes where the stream, not the setup, went away — worth re-opening on our own */
export const RECOVERABLE = new Set(["line-dropped", "mic-lost", "mic-held", "mic-missing", "no-input", "engine-down"]);
export const RETRY_DELAYS_MS = [800, 2200, 4000]; // the last attempt starts before the 5 s mark

export const clock = (d = new Date()) => d.toTimeString().slice(0, 8);

/** the sentence a person reads, with the times */
export function lossSentence(what, lostAt, reopenedAt) {
  return reopenedAt
    ? `${what} lost at ${lostAt}, re-opened at ${reopenedAt}.`
    : `${what} lost at ${lostAt} and could not be re-opened.`;
}

let recovering = false;
let failedThisTry = false;
/** the fatal-error path calls this when a re-open attempt itself failed */
export function noteFatalDuringRecovery() { if (recovering) { failedThisTry = true; return true; } return false; }

/**
 * @param {{err: unknown, why: {cause: string, sentence: string, action: string},
 *          restart: () => Promise<unknown>, say: (text: string, kind?: string) => void,
 *          post?: (row: object) => Promise<unknown>, sleep?: (ms: number) => Promise<void>, now?: () => Date}} o
 * @returns {Promise<boolean>} whether the stream came back
 */
export async function recover(o) {
  if (recovering || !RECOVERABLE.has(o.why.cause)) return false;
  const sleep = o.sleep || ((ms) => new Promise((r) => setTimeout(r, ms)));
  const now = o.now || (() => new Date());
  const lostD = now(), lostAt = clock(lostD), what = "Microphone stream";
  recovering = true;
  let reopenedAt = null, tries = 0, prev = 0;
  try {
    for (const at of RETRY_DELAYS_MS) {
      await sleep(at - prev); prev = at; tries += 1;
      failedThisTry = false;
      try { await o.restart(); } catch { failedThisTry = true; }
      await sleep(300);
      if (!failedThisTry) { reopenedAt = clock(now()); break; }
    }
  } finally { recovering = false; }
  const said = lossSentence(what, lostAt, reopenedAt);
  o.say(reopenedAt ? said : `${said} ${o.why.action}`, reopenedAt ? "muted" : "error");
  console.log("[rodd] " + said + ` (${tries} attempt${tries === 1 ? "" : "s"})`);
  if (o.post) {
    try { await o.post({ id: lostD.toISOString().slice(0, 19), what, cause: o.why.cause, lost_at: lostAt,
                          reopened_at: reopenedAt, attempts: tries, said }); } catch { /* the record is best-effort; the log line above stands */ }
  }
  return reopenedAt !== null;
}

/** POST one loss record to the toolbox */
export function postLoss(row) {
  return fetch(`${TOOLBOX}/loss`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(row) });
}
