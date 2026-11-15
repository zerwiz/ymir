/**
 * Snapshots — the room's scene written down while it is being drawn.
 *
 * The server **cannot read a snapshot**. A room's scene arrives already
 * encrypted with a key that lives in the URL fragment, and this module keeps the
 * ciphertext beside its iv. That is not a limitation, it is the property the
 * whole room server is built on: the file on disk is exactly the pair of buffers
 * the server would replay to a joiner from memory, so a room restored from disk
 * behaves identically to a room restored from memory.
 *
 * One file per room per save, the stamp in the name, append-only: a later
 * snapshot SUPERSEDES an earlier one, it never overwrites it.
 *
 * `tickets/open/feature-0033-uw-every-room-keeps-its-scene.md`.
 */

import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";

/** The snapshot file's own version, so a reader can refuse a shape it does not know. */
export const SNAPSHOT_VERSION = 1;

/** A snapshot is the scene plus its iv; the same bound the room store keeps. */
export const MAX_SNAPSHOT_BYTES = 16 * 1024 * 1024;

/** How often a room with an unseen scene is written down while people are drawing. */
export const DEFAULT_EVERY_MS = 60_000;

/**
 * A sortable, filesystem-safe stamp: `20261114T002534.123Z`. Sorting these
 * strings sorts them in time order, which is what makes "the newest snapshot"
 * a directory listing rather than a database query.
 */
export const stampOf = (ms = Date.now()) => {
  const iso = new Date(ms).toISOString(); // 2026-11-14T00:25:34.123Z
  return iso.replace(/[-:]/g, "").replace(/\.(\d{3})Z$/, ".$1Z");
};

/** The room id is already bounded by the protocol; it is also a directory name. */
const safeRoom = (roomId) =>
  typeof roomId === "string" && /^[A-Za-z0-9_-]{6,64}$/.test(roomId) ? roomId : null;

export const roomDir = (root, roomId) => {
  const room = safeRoom(roomId);
  return room ? join(root, room) : null;
};

/**
 * Writes one snapshot and returns what it wrote.
 *
 * `writeFileSync` with the `wx` flag is the append-only guarantee made
 * mechanical: the kernel refuses to replace an existing file, so two writers
 * racing for the same millisecond produce two files rather than one lost scene.
 */
export const writeSnapshot = (root, { roomId, data, iv }, { at = Date.now() } = {}) => {
  const dir = roomDir(root, roomId);
  if (!dir || !root) {
    return { ok: false, error: "no snapshot store configured for this room" };
  }
  if (!(data instanceof Uint8Array) || data.byteLength === 0) {
    return { ok: false, error: "the scene is empty" };
  }
  if (data.byteLength > MAX_SNAPSHOT_BYTES) {
    return { ok: false, error: `the scene exceeds ${MAX_SNAPSHOT_BYTES} bytes` };
  }
  const ivBytes = iv instanceof Uint8Array ? iv : new Uint8Array(iv ?? []);
  const stamp = stampOf(at);
  const body = JSON.stringify({
    version: SNAPSHOT_VERSION,
    kind: "whiteboard-scene",
    room: roomId,
    at: new Date(at).toISOString(),
    stamp,
    // base64, because these are bytes the server must not interpret
    iv: Buffer.from(ivBytes).toString("base64"),
    data: Buffer.from(data).toString("base64"),
  });

  mkdirSync(dir, { recursive: true });

  // Never overwrite: the first free name wins, and a collision in the same
  // millisecond appends a counter rather than replacing a scene.
  for (let attempt = 0; attempt < 1000; attempt += 1) {
    const name = `${stamp}${attempt === 0 ? "" : `-${attempt}`}.scene.json`;
    const path = join(dir, name);
    try {
      writeFileSync(path, body, { flag: "wx", mode: 0o600 });
      return { ok: true, path, name, stamp, bytes: body.length };
    } catch (error) {
      if (error?.code === "EEXIST") {
        continue;
      }
      return { ok: false, error: error?.message ?? String(error) };
    }
  }
  return { ok: false, error: "could not find a free snapshot name" };
};

/** Every snapshot of a room, oldest first. Missing directory is an empty list. */
export const listSnapshots = (root, roomId) => {
  const dir = roomDir(root, roomId);
  if (!dir) {
    return [];
  }
  let names;
  try {
    names = readdirSync(dir);
  } catch {
    return [];
  }
  return names
    .filter((name) => name.endsWith(".scene.json"))
    .sort()
    .map((name) => {
      const path = join(dir, name);
      let bytes = 0;
      try {
        bytes = statSync(path).size;
      } catch {
        bytes = 0;
      }
      return { name, path, stamp: name.replace(/\.scene\.json$/, ""), bytes };
    });
};

/**
 * The newest snapshot of a room, as the buffers a joiner needs — or `null`.
 *
 * Returns exactly the shape the in-memory store hands back (`{data, iv}`), so the
 * join path does not care where a scene came from.
 */
export const latestSnapshot = (root, roomId) => {
  const all = listSnapshots(root, roomId);
  for (let index = all.length - 1; index >= 0; index -= 1) {
    const entry = all[index];
    try {
      const parsed = JSON.parse(readFileSync(entry.path, "utf8"));
      if (parsed?.version !== SNAPSHOT_VERSION || parsed?.kind !== "whiteboard-scene") {
        continue;
      }
      const data = Buffer.from(String(parsed.data ?? ""), "base64");
      if (data.byteLength === 0) {
        continue;
      }
      return {
        data: new Uint8Array(data),
        iv: new Uint8Array(Buffer.from(String(parsed.iv ?? ""), "base64")),
        stamp: entry.stamp,
      };
    } catch {
      // a torn or foreign file is skipped, never fatal: the next one back is
      // still a true scene
      continue;
    }
  }
  return null;
};

/**
 * The writer: a cadence, and a write when the last hand leaves.
 *
 * It holds only the LATEST scene per room in memory and only until it is
 * written, so the cadence collapses a busy minute into one file rather than
 * sixty. `flush(roomId)` is called on the last client leaving; `flushAll()` on
 * shutdown. Nothing here prunes: a snapshot is a record, and records are
 * append-only (Rule 06).
 */
export class SnapshotWriter {
  constructor({ root, everyMs = DEFAULT_EVERY_MS, now = () => Date.now(), write = writeSnapshot } = {}) {
    this.root = root;
    this.everyMs = everyMs;
    this.now = now;
    this.write = write;
    /** roomId -> {data, iv, seenAt} */
    this.dirty = new Map();
    this.timer = null;
    this.written = 0;
    this.lastError = null;
  }

  /** Notes the room's newest scene. Cheap: it only replaces a pointer pair. */
  note(roomId, data, iv) {
    if (!this.root) {
      return false;
    }
    this.dirty.set(roomId, { data, iv, seenAt: this.now() });
    return true;
  }

  /** Writes one room now, if it has an unwritten scene. */
  flush(roomId) {
    const pending = this.dirty.get(roomId);
    if (!pending) {
      return null;
    }
    this.dirty.delete(roomId);
    const result = this.write(
      this.root,
      { roomId, data: pending.data, iv: pending.iv },
      { at: pending.seenAt },
    );
    if (result.ok) {
      this.written += 1;
    } else {
      this.lastError = result.error ?? "unknown";
    }
    return result;
  }

  flushAll() {
    const results = [];
    for (const roomId of [...this.dirty.keys()]) {
      const result = this.flush(roomId);
      if (result) {
        results.push({ roomId, ...result });
      }
    }
    return results;
  }

  /** Starts the cadence. `unref` so a test or a shutdown never waits on it. */
  start() {
    if (this.timer || !this.root || this.everyMs <= 0) {
      return this;
    }
    this.timer = setInterval(() => this.flushAll(), this.everyMs);
    this.timer.unref?.();
    return this;
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    return this.flushAll();
  }

  stats() {
    return { rooms: this.dirty.size, written: this.written, lastError: this.lastError };
  }
}

export const readConfig = (env = process.env) => ({
  /**
   * Where snapshots live. Empty disables them with a sentence, the same way the
   * blob store behaves: a seat without a board shelf is a clean skip.
   */
  dir: env.COLLAB_SNAPSHOT_DIR ?? "",
  everyMs: Number(env.COLLAB_SNAPSHOT_EVERY_MS ?? DEFAULT_EVERY_MS),
});
