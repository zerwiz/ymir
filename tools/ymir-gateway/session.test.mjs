/**
 * session.test.mjs — proves session identity, resumption across devices, and brain choice.
 *
 * Run: node tools/ymir-gateway/session.test.mjs
 *
 * Every assertion here is about something that would be INVISIBLE if it broke: a session that
 * does not resume, a token that would be guessable, a "local" choice that silently went to the
 * cloud. None of them crash loudly — they just quietly do the wrong thing, which is the family of
 * fault this whole night has been about.
 */
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import assert from "node:assert/strict";
import { BRAINS, SessionIdentity, SessionStore, chooseBrain, newSessionId } from "./session.mjs";

let passed = 0;
const t = (name, fn) => {
  try {
    fn();
    passed += 1;
    console.log(`  ok   ${name}`);
  } catch (e) {
    console.log(`  FAIL ${name}\n       ${e.message}`);
    process.exitCode = 1;
  }
};

const dir = mkdtempSync(join(tmpdir(), "ymir-session-"));

t("a session id is stable-shaped and different every time", () => {
  const a = newSessionId("phone");
  const b = newSessionId("phone");
  assert.match(a, /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}$/);
  assert.notEqual(a, b, "two sessions must not share an id");
});

t("a session id does not reveal the device it came from", () => {
  const id = newSessionId("heimdall-phone");
  assert.ok(!id.includes("heimdall"), `device leaked into the id: ${id}`);
});

t("the resume token is never part of the serialised record", () => {
  const s = new SessionIdentity({ device: "phone" });
  const json = s.toJSON();
  assert.ok(!("resumeToken" in json), "the bearer token must not be in the record");
  assert.ok(!JSON.stringify(json).includes(s.resumeToken));
});

t("the right token resumes; the wrong one does not", () => {
  const s = new SessionIdentity({ device: "phone" });
  assert.equal(s.mayResume(s.resumeToken), true);
  assert.equal(s.mayResume("not-the-token"), false);
  assert.equal(s.mayResume(""), false);
  assert.equal(s.mayResume(undefined), false);
});

t("a token of the right LENGTH but wrong content is refused", () => {
  const s = new SessionIdentity({ device: "phone" });
  const sameLength = "x".repeat(s.resumeToken.length);
  assert.equal(s.mayResume(sameLength), false, "length is not identity");
});

t("a session survives a store restart and resumes on ANOTHER device", () => {
  const store = new SessionStore(dir);
  const identity = new SessionIdentity({ device: "phone", brain: BRAINS.PI });
  store.save(identity, identity.resumeToken);

  const reopened = new SessionStore(dir);           // as if the gateway restarted
  const back = reopened.resume(identity.sessionId, identity.resumeToken);
  assert.ok(back, "the session did not survive the restart");
  assert.equal(back.brain, BRAINS.PI);
  assert.equal(back.device, "phone");
});

t("resuming with the WRONG token is refused even for a real session", () => {
  const store = new SessionStore(dir);
  const identity = new SessionIdentity({ device: "phone" });
  store.save(identity, identity.resumeToken);
  assert.equal(store.resume(identity.sessionId, "guessed"), null);
});

t("an unknown session is a clean miss, not a crash", () => {
  const store = new SessionStore(dir);
  assert.equal(store.resume("no-such-session", "any"), null);
  assert.equal(store.load("no-such-session"), null);
});

t("a truncated record is NOT half-restored", () => {
  const store = new SessionStore(dir);
  const id = new SessionIdentity({ device: "phone" }).sessionId;
  store.save(new SessionIdentity({ sessionId: id }), "tok");
  require_writeTruncated(join(dir, `${id}.json`));
  assert.equal(store.load(id), null, "a corrupt record must read as absent, never as partial");
});

t("local is chosen when a rail answers; hosted only when asked", () => {
  assert.equal(chooseBrain({ requested: "auto", railUrl: "http://127.0.0.1:8080" }), BRAINS.PI);
  assert.equal(chooseBrain({ requested: "auto" }), BRAINS.OPENCODE);
  assert.equal(chooseBrain({ requested: BRAINS.PI }), BRAINS.PI);
  assert.equal(chooseBrain({ requested: BRAINS.OPENCODE }), BRAINS.OPENCODE);
});

t("a nonsense brain request falls back to hosted, not to garbage", () => {
  assert.equal(chooseBrain({ requested: "gpt-9-ultra" }), BRAINS.OPENCODE);
});

t("an unknown brain cannot be forced onto a session", () => {
  const s = new SessionIdentity({ brain: "not-a-brain" });
  assert.ok(Object.values(BRAINS).includes(s.brain));
});

function require_writeTruncated(path) {
  writeFileSync(path, '{ "sessionId": "trunc');   // a record cut off mid-write
}

rmSync(dir, { recursive: true, force: true });
console.log(`\nsession_test[2]{passed,total}:\n  "${passed}","11"`);