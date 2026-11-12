// why.test.mjs — every failure Rödd can meet becomes a sentence and one action, headless (plan 271).
import { explain, sayWhy } from "../patch/why.js";
const cases = [
  ["the raw WebSocket error that used to read [object Event]", { type: "error" }, { engine_up: false }, "engine-down"],
  ["a dropped line while the engine answers", { type: "close" }, { engine_up: true }, "line-dropped"],
  ["a dropped line is never blamed on a call it did not prove", new Error("Realtime transport disconnected"), { engine_up: true, mic_holder: "Discord" }, "line-dropped"],
  ["getUserMedia: device busy", Object.assign(new Error("Could not start audio source"), { name: "NotReadableError" }), { mic_holder: "Discord" }, "mic-held"],
  ["getUserMedia: refused", Object.assign(new Error("x"), { name: "NotAllowedError" }), {}, "mic-refused"],
  ["getUserMedia: none", Object.assign(new Error("x"), { name: "NotFoundError" }), {}, "mic-missing"],
  ["the head refused the key", new Error("401 Unauthorized"), {}, "head-refused"],
  ["the one seat is taken", new Error("session_limit_reached"), {}, "seat-busy"],
];
let bad = 0;
for (const [what, err, desk, want] of cases) {
  const w = explain(err, desk), line = sayWhy(w);
  const ok = w.cause === want && !/object Event/.test(line) && w.sentence && w.action;
  console.log(`${ok ? "ok  " : "FAIL"} ${what} -> ${w.cause}: ${line}`);
  if (!ok) bad = 1;
}

// ── plan 259 B2e: the four rules, on a virtual clock ──
import { recover, explain as ex, noteFatalDuringRecovery } from "../patch/why.js";
import { execSync } from "node:child_process";
let bad2 = 0; const chk = (ok, what) => { console.log(`${ok ? "ok  " : "FAIL"} ${what}`); if (!ok) bad2 = 1; };
const vclock = () => { let t = 0; return { sleep: async (ms) => { t += ms; }, at: () => t, now: () => new Date(2026, 10, 12, 14, 5, 3 + Math.floor(t / 1000)) }; };

chk(ex({ name: "NotFoundError" }, { inputs: 0 }).cause === "no-input", "rule 1: no microphone is shown as a state ('no-input'), not a mute");

{ // lost once, the second try works: within 5 s, said with the time, ONE record
  const c = vclock(); let n = 0; const said = [], posted = [];
  const ok = await recover({ err: { type: "close" }, why: ex({ type: "close" }, { engine_up: true }),
    restart: async () => { n += 1; if (n === 1) noteFatalDuringRecovery(); }, say: (t) => said.push(t),
    post: async (r) => posted.push(r), sleep: c.sleep, now: c.now });
  chk(ok && n === 2 && c.at() < 5000, `rule 2: re-opened on its own on try ${n}, at ${c.at()} ms (< 5000)`);
  chk(/lost at 14:05:03, re-opened at 14:05:0\d\./.test(said[0] || ""), `rule 3: named in words with the time: "${said[0]}"`);
  chk(posted.length === 1 && posted[0].reopened_at, "rule 4: exactly one record for the loss");
}
{ // never comes back: three tries, honest words, still one record, no loop
  const c = vclock(); let n = 0; const said = [], posted = [];
  const ok = await recover({ err: 1, why: ex({ type: "close" }, { engine_up: true }),
    restart: async () => { n += 1; noteFatalDuringRecovery(); }, say: (t) => said.push(t),
    post: async (r) => posted.push(r), sleep: c.sleep, now: c.now });
  chk(!ok && n === 3 && posted.length === 1 && /could not be re-opened/.test(said[0]), "a stream that never returns: 3 tries, said plainly, one record, no endless loop");
}
{ let n = 0;
  const ok = await recover({ err: 1, why: ex(new Error("401 Unauthorized"), {}), restart: async () => { n += 1; }, say() {}, sleep: async () => {} });
  chk(!ok && n === 0, "a refused key is not 'a lost stream': no blind retries");
}
let hits = "";
try { hits = execSync("grep -rnE '(restart|stop|kill).*(pipewire|wireplumber)' bin/voice bin/desk apps/rodd/start.sh apps/rodd/src apps/rodd/patch scripts/electron.sh --include=*.sh --include=*.js --include=*.py --include=*.mjs | grep -v -E 'never|NEVER|test|law|LAW|//|#' || true", { encoding: "utf8" }); } catch {}
chk(hits.trim() === "", "never restarts pipewire or wireplumber as a remedy (searched Rödd, the voice door, the guard)");
process.exit(bad || bad2);
