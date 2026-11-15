import assert from "node:assert/strict";
import { mkdtempSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, describe, it } from "node:test";

import {
  MAX_SNAPSHOT_BYTES,
  SnapshotWriter,
  latestSnapshot,
  listSnapshots,
  stampOf,
  writeSnapshot,
} from "../snapshots.mjs";

const roots = [];
const scratch = () => {
  const root = mkdtempSync(join(tmpdir(), "wb-snap-"));
  roots.push(root);
  return root;
};
after(() => roots.forEach((root) => rmSync(root, { recursive: true, force: true })));

const bytes = (n, fill = 7) => new Uint8Array(n).fill(fill);

describe("snapshots", () => {
  it("writes one file per save and never overwrites", () => {
    const root = scratch();
    const first = writeSnapshot(root, { roomId: "room-abc123", data: bytes(4), iv: bytes(2) }, { at: 1000 });
    const second = writeSnapshot(root, { roomId: "room-abc123", data: bytes(8, 9), iv: bytes(2) }, { at: 1000 });
    assert.equal(first.ok, true);
    assert.equal(second.ok, true);
    // same millisecond, two files: a scene is superseded, never replaced
    assert.notEqual(first.path, second.path);
    assert.equal(listSnapshots(root, "room-abc123").length, 2);
  });

  it("round-trips the ciphertext and its iv as the buffers a joiner needs", () => {
    const root = scratch();
    const stated = { data: bytes(6, 3), iv: bytes(4, 5) };
    writeSnapshot(root, { roomId: "room-abc123", ...stated });
    const latest = latestSnapshot(root, "room-abc123");
    assert.ok(latest);
    assert.deepEqual([...latest.data], [...stated.data]);
    assert.deepEqual([...latest.iv], [...stated.iv]);
  });

  it("answers the newest snapshot, and a torn file is skipped rather than fatal", () => {
    const root = scratch();
    writeSnapshot(root, { roomId: "room-abc123", data: bytes(3, 1), iv: bytes(1) }, { at: 1000 });
    writeSnapshot(root, { roomId: "room-abc123", data: bytes(3, 2), iv: bytes(1) }, { at: 2000 });
    const dir = join(root, "room-abc123");
    // A torn newest file (a crash mid-write) must not cost the true scene behind it.
    writeFileSync(join(dir, `${stampOf(3000)}.scene.json`), '{"version":1,');
    const latest = latestSnapshot(root, "room-abc123");
    assert.equal(latest.data[0], 2);
  });

  it("refuses an empty scene, an oversized scene, and a room that is not a room", () => {
    const root = scratch();
    assert.equal(writeSnapshot(root, { roomId: "room-abc123", data: bytes(0), iv: bytes(1) }).ok, false);
    assert.equal(
      writeSnapshot(root, { roomId: "room-abc123", data: new Uint8Array(0), iv: bytes(1) }).ok,
      false,
    );
    assert.equal(
      writeSnapshot(root, { roomId: "../etc/passwd", data: bytes(2), iv: bytes(1) }).ok,
      false,
    );
    const huge = new Uint8Array(MAX_SNAPSHOT_BYTES + 1);
    const oversized = writeSnapshot(root, {
      roomId: "room-abc123",
      data: huge,
      iv: bytes(1),
    });
    assert.equal(oversized.ok, false);
  });

  it("a missing store is a refusal, not a silent loss", () => {
    const result = writeSnapshot("", { roomId: "room-abc123", data: bytes(2), iv: bytes(1) });
    assert.equal(result.ok, false);
    assert.match(result.error, /no snapshot store/);
    assert.equal(latestSnapshot("", "room-abc123"), null);
  });

  it("collapses a busy minute into one file and writes on the last hand leaving", () => {
    const root = scratch();
    const writer = new SnapshotWriter({ root, everyMs: 0 });
    writer.note("room-abc123", bytes(2, 1), bytes(1));
    writer.note("room-abc123", bytes(2, 2), bytes(1));
    writer.note("room-abc123", bytes(2, 3), bytes(1));
    assert.equal(listSnapshots(root, "room-abc123").length, 0, "nothing is written until the cadence or the leave");
    const flushed = writer.flush("room-abc123");
    assert.equal(flushed.ok, true);
    assert.equal(listSnapshots(root, "room-abc123").length, 1);
    // The last scene noted is the one written down.
    assert.equal(latestSnapshot(root, "room-abc123").data[0], 3);
  });

  it("orders stamps by time, so 'newest' is a directory listing", () => {
    assert.ok(stampOf(1000) < stampOf(2000));
    assert.ok(stampOf(1_700_000_000_000) > stampOf(1_600_000_000_000));
    assert.match(stampOf(0), /^\d{8}T\d{6}\.\d{3}Z$/);
  });

  it("names every snapshot of a room, oldest first", () => {
    const root = scratch();
    writeSnapshot(root, { roomId: "room-abc123", data: bytes(2), iv: bytes(1) }, { at: 2000 });
    writeSnapshot(root, { roomId: "room-abc123", data: bytes(2), iv: bytes(1) }, { at: 1000 });
    const names = readdirSync(join(root, "room-abc123"));
    const listed = listSnapshots(root, "room-abc123").map((entry) => entry.name);
    assert.deepEqual(listed, [...names].sort());
  });
});
