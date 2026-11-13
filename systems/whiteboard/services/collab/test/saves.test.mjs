import assert from "node:assert/strict";
import { mkdtempSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, describe, it } from "node:test";

import { isPlausibleIdentity, identityFrom, readConfig } from "../identity.mjs";
import { isPlausibleSaveId, listSaves, looksLikeScene, readSave, writeSave } from "../saves.mjs";

const roots = [];
const scratch = () => {
  const root = mkdtempSync(join(tmpdir(), "wb-saves-"));
  roots.push(root);
  return root;
};
after(() => roots.forEach((root) => rmSync(root, { recursive: true, force: true })));

const scene = (label = "Start") => ({
  type: "excalidraw",
  version: 2,
  elements: [{ id: "n1", type: "rectangle", text: label }],
  appState: { viewBackgroundColor: "#ffffff" },
});

describe("identity — the owner is the gate's word, never the client's", () => {
  const config = readConfig({});

  it("reads the header the proxy sets", () => {
    assert.deepEqual(identityFrom({ "remote-user": "seat-one" }, config), {
      ok: true,
      identity: "seat-one",
    });
  });

  it("refuses an absent header with a sentence about the gate", () => {
    const refused = identityFrom({}, config);
    assert.equal(refused.ok, false);
    assert.match(refused.reason, /gate/);
  });

  it("refuses the values a proxy substitutes for nobody", () => {
    for (const value of ["", "-", "anonymous", "unknown", "null"]) {
      const refused = identityFrom({ "remote-user": value }, config);
      assert.equal(refused.ok, false, `${value} must not own a board`);
    }
  });

  it("refuses an identity that could walk the disk", () => {
    for (const value of ["../etc", "a/b", "a b", ".hidden", "a\u0000b"]) {
      assert.equal(identityFrom({ "remote-user": value }, config).ok, false, value);
      assert.equal(isPlausibleIdentity(value), false, value);
    }
  });
});

describe("saves — one file per save, owned by the asserted identity", () => {
  it("keeps the app's own JSON, under the identity, with the stamp in the name", () => {
    const root = scratch();
    const written = writeSave(root, { identity: "seat-one", roomId: "room-abc123", scene: scene() });
    assert.equal(written.ok, true);
    assert.match(written.id, /^room-abc123-\d{8}T\d{6}\.\d{3}Z$/);
    assert.deepEqual(readdirSync(join(root, "seat-one")), [`${written.id}.excalidraw`]);
    const opened = readSave(root, { identity: "seat-one", id: written.id });
    assert.equal(opened.ok, true);
    assert.equal(opened.scene.elements[0].text, "Start");
  });

  it("a later save supersedes an earlier one and never overwrites it", () => {
    const root = scratch();
    const first = writeSave(
      root,
      { identity: "seat-one", roomId: "room-abc123", scene: scene("One") },
      { at: 1_700_000_000_000 },
    );
    const second = writeSave(
      root,
      { identity: "seat-one", roomId: "room-abc123", scene: scene("Two") },
      { at: 1_700_000_060_000 },
    );
    assert.notEqual(first.id, second.id);
    assert.equal(listSaves(root, "seat-one").length, 2);
    // newest first
    assert.equal(listSaves(root, "seat-one")[0].id, second.id);
  });

  it("lists only the caller's saves", () => {
    const root = scratch();
    writeSave(root, { identity: "seat-one", roomId: "room-abc123", scene: scene() });
    writeSave(root, { identity: "seat-two", roomId: "room-def456", scene: scene() });
    const mine = listSaves(root, "seat-one");
    assert.equal(mine.length, 1);
    assert.match(mine[0].id, /^room-abc123-/);
  });

  it("refuses another identity's save BY NAME, not with an empty answer", () => {
    const root = scratch();
    const theirs = writeSave(root, { identity: "seat-two", roomId: "room-def456", scene: scene() });
    const refused = readSave(root, { identity: "seat-one", id: theirs.id });
    assert.equal(refused.ok, false);
    assert.equal(refused.status, 403);
    assert.equal(refused.reason, "not-yours");
    assert.match(refused.error, /not yours/);
    // It never names the owner.
    assert.doesNotMatch(refused.error, /seat-two/);
  });

  it("answers 'no such save' for a save that exists nowhere", () => {
    const root = scratch();
    writeSave(root, { identity: "seat-one", roomId: "room-abc123", scene: scene() });
    const missing = readSave(root, { identity: "seat-one", id: "room-zzz999-20260101T000000.000Z" });
    assert.equal(missing.status, 404);
  });

  it("refuses a body that is not a board, and a room that is not a room", () => {
    const root = scratch();
    assert.equal(writeSave(root, { identity: "seat-one", roomId: "room-abc123", scene: { hi: 1 } }).status, 400);
    assert.equal(
      writeSave(root, { identity: "seat-one", roomId: "not a room", scene: scene() }).status,
      400,
    );
    assert.equal(writeSave("", { identity: "seat-one", roomId: "room-abc123", scene: scene() }).status, 503);
  });

  it("requires a usable identity before it will name a directory", () => {
    const root = scratch();
    assert.equal(writeSave(root, { identity: "../evil", roomId: "room-abc123", scene: scene() }).status, 503);
    assert.deepEqual(listSaves(root, "../evil"), []);
  });

  it("keeps the save id's grammar narrow", () => {
    assert.equal(isPlausibleSaveId("room-abc123-20261114T002534.123Z"), true);
    for (const bad of ["", "../../etc", "room-abc123", "a-b", "room-abc123-../../x"]) {
      assert.equal(isPlausibleSaveId(bad), false, bad);
    }
  });

  it("recognises the app's export and refuses a foreign blob", () => {
    assert.equal(looksLikeScene({ type: "excalidraw", elements: [] }), true);
    assert.equal(looksLikeScene({ elements: [] }), true);
    assert.equal(looksLikeScene({ type: "not-excalidraw", elements: [] }), false);
    assert.equal(looksLikeScene([]), false);
    assert.equal(looksLikeScene(null), false);
  });
});
