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
process.exit(bad);
