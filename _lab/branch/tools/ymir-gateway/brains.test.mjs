/**
 * brains.test.mjs — both brains, ONE interface.
 *
 * The point of a seam is that the caller cannot tell which brain it has. That claim is only worth
 * anything if BOTH sides are driven through it — a seam exercised in one direction is a seam
 * nobody has tested, which is the fault this whole project has been collecting all night.
 *
 * Run: node tools/ymir-gateway/brains.test.mjs            (no rail, no agent, no network)
 * Run: YMIR_LIVE=1 node tools/ymir-gateway/brains.test.mjs  (also exercise the real local rail)
 */
import assert from "node:assert/strict";
import { Brain } from "./acp.mjs";
import { BRAINS } from "./session.mjs";
import { LocalBrain, pickBrain } from "./pi.mjs";

let passed = 0;
let failed = 0;
const t = async (name, fn) => {
  try {
    await fn();
    passed += 1;
    console.log(`  ok   ${name}`);
  } catch (e) {
    failed += 1;
    console.log(`  FAIL ${name}\n       ${e.message}`);
  }
};

/** A stand-in hosted brain. Same shape, no agent required. */
class FakeApiBrain extends Brain {
  constructor(reply = "hosted reply") {
    super(BRAINS.OPENCODE);
    this.reply = reply;
    this.calls = 0;
  }
  async ask() {
    this.calls += 1;
    return { ok: true, text: this.reply };
  }
}

/** A fake fetch for the local rail, so the local half is testable with nothing running. */
const fakeFetch = (handler) => async (url, opts = {}) => {
  const body = handler(url, opts);
  return {
    ok: body.ok ?? true,
    status: body.status ?? 200,
    json: async () => body.json,
    text: async () => body.text ?? "",
  };
};

await t("both brains expose the SAME method and answer the same shape", async () => {
  const api = new FakeApiBrain("hello from hosted");
  const local = new LocalBrain({ fetchImpl: fakeFetch(() => ({ json: { choices: [{ message: { content: "hello from local" } }] } })) });
  const a = await api.ask("hi");
  const b = await local.ask("hi");
  assert.deepEqual(Object.keys(a).sort(), ["ok", "text"]);
  assert.deepEqual(Object.keys(b).sort(), ["ok", "text"]);
  assert.equal(a.text, "hello from hosted");
  assert.equal(b.text, "hello from local");
});

await t("the base Brain refuses a brain the house does not allow", () => {
  assert.throws(() => new Brain("gpt-9-ultra"), /unknown brain/);
  assert.doesNotThrow(() => new Brain(BRAINS.PI));
});

await t("a DEAD rail is reported, never thrown — a voice loop cannot catch", async () => {
  const local = new LocalBrain({ fetchImpl: async () => { throw new Error("ECONNREFUSED"); } });
  const r = await local.ask("hi");
  assert.equal(r.ok, false);
  assert.equal(r.reason, "rail-unreachable");
  assert.ok(r.detail.includes("ECONNREFUSED"));
});

await t("HTTP 200 with an EMPTY completion is a failure, not a success", async () => {
  // measured on this box: reasoning on burns the token budget and returns an empty summary with 200
  const local = new LocalBrain({ fetchImpl: fakeFetch(() => ({ ok: true, json: { choices: [{ message: { content: "" } }] } })) });
  const r = await local.ask("hi");
  assert.equal(r.ok, false);
  assert.equal(r.reason, "empty-completion");
});

await t("a non-200 from the rail is reported with the server's own words", async () => {
  const local = new LocalBrain({ fetchImpl: fakeFetch(() => ({ ok: false, status: 503, text: "model resident limit" })) });
  const r = await local.ask("hi");
  assert.equal(r.reason, "rail-503");
  assert.ok(r.detail.includes("resident"));
});

await t("a slow rail times out into a typed result", async () => {
  const local = new LocalBrain({ timeoutMs: 30, fetchImpl: (_u, o) => new Promise((_res, rej) => {
    o.signal.addEventListener("abort", () => rej(Object.assign(new Error("aborted"), { name: "AbortError" })));
  }) });
  const r = await local.ask("hi", { timeoutMs: 30 });
  assert.equal(r.ok, false);
  assert.equal(r.reason, "timeout");
});

await t("availability is a health probe, never a completion", async () => {
  let sawCompletion = false;
  const local = new LocalBrain({ fetchImpl: fakeFetch((url) => {
    if (url.endsWith("/models")) return { json: { data: [] } };
    sawCompletion = true;
    return { json: {} };
  }) });
  assert.equal(await local.available(), true);
  assert.equal(sawCompletion, false, "the probe must not spend a generation");
});

await t("auto prefers LOCAL when the rail answers — privacy by default", async () => {
  const local = new LocalBrain({ fetchImpl: fakeFetch(() => ({ json: {} })) });
  const api = new FakeApiBrain();
  const picked = await pickBrain({ requested: "auto", apiBrain: api, localBrain: local });
  assert.equal(picked.brain, local);
  assert.match(picked.reason, /local by default/);
});

await t("auto falls back to hosted when there is no rail, and says so", async () => {
  const local = new LocalBrain({ fetchImpl: async () => { throw new Error("no rail"); } });
  const api = new FakeApiBrain();
  const picked = await pickBrain({ requested: "auto", apiBrain: api, localBrain: local });
  assert.equal(picked.brain, api);
  assert.match(picked.reason, /no local rail/);
});

await t("asking for local with no rail REFUSES rather than silently going to the cloud", async () => {
  const local = new LocalBrain({ fetchImpl: async () => { throw new Error("no rail"); } });
  const api = new FakeApiBrain();
  const picked = await pickBrain({ requested: BRAINS.PI, apiBrain: api, localBrain: local });
  assert.equal(picked.brain, null, "a silent cloud fallback is the failure this guards against");
  assert.match(picked.reason, /no-rail/);
  assert.equal(api.calls, 0, "the hosted brain must not have been used");
});

if (process.env.YMIR_LIVE === "1") {
  const live = new LocalBrain();
  await t("LIVE: the real rail on this box answers", async () => {
    const up = await live.available();
    assert.equal(up, true, "the rail did not answer /models — is llama-swap running?");
    const r = await live.ask("Say the single word: ready.", { timeoutMs: 60_000 });
    assert.equal(r.ok, true, `live ask failed: ${r.reason} ${r.detail}`);
    assert.ok(r.text.length > 0);
  });
}

console.log(`\nbrains_test[2]{passed,failed}:\n  "${passed}","${failed}"`);
process.exit(failed ? 1 : 0);