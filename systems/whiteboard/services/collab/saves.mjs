/**
 * Saves — a board stored on the house's disks, owned by the identity the GATE
 * asserted.
 *
 * Read the ownership rule before changing a line here, because it is the whole
 * design: the owner is **never** a value the client sends. The gate admits a
 * person and the proxy tells the room server who that was (`identity.mjs`), and
 * that name decides which directory is the person's. So a person can only ever
 * reach their own shelf, and a request for another's save is **refused by name**
 * — "that save is not yours" — rather than answered with an empty list, which
 * would read as "you saved nothing" and be a lie.
 *
 * The file is the app's own JSON, unencrypted on our own disks (the vault rules
 * already govern who may read the home). One file per save with the stamp in the
 * name, so a later save supersedes an earlier one and never overwrites it.
 *
 * `tickets/open/feature-0036-uw-save-to-server-and-choose-a-session.md`.
 */

import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join, resolve, sep } from "node:path";

import { isPlausibleIdentity } from "./identity.mjs";
import { stampOf } from "./snapshots.mjs";

/** The largest board we accept. A scene of 16 MiB is already enormous. */
export const MAX_SAVE_BYTES = 16 * 1024 * 1024;

export const SAVE_EXTENSION = ".excalidraw";

const safeRoom = (roomId) =>
  typeof roomId === "string" && /^[A-Za-z0-9_-]{6,64}$/.test(roomId) ? roomId : null;

/**
 * A save id is `<room>-<stamp>`: the room it came from and when it was taken,
 * and nothing about who owns it. The owner is the caller — a save id never
 * carries an identity, so a leaked id cannot be used to name somebody.
 */
export const SAVE_ID = /^[A-Za-z0-9_-]{6,64}-[0-9TZ.]+$/;

export const isPlausibleSaveId = (id) =>
  typeof id === "string" && id.length <= 128 && SAVE_ID.test(id);

const isInside = (root, path) => {
  const target = resolve(path);
  const base = resolve(root);
  return target === base || target.startsWith(base + sep);
};

/** `<root>/<identity>/` — the person's own shelf, or `null` if the name is unusable. */
export const identityDir = (root, identity) => {
  if (!root || !isPlausibleIdentity(identity)) {
    return null;
  }
  const dir = join(root, identity);
  return isInside(root, dir) ? dir : null;
};

/**
 * Whether a body is a board. The app's export is `{type:"excalidraw", elements:[]}`
 * but a client may send only the scene — so either is accepted and anything else
 * is refused with a sentence, because storing an unrecognised blob under a name
 * that promises a board is a silent corruption.
 */
export const looksLikeScene = (scene) => {
  if (!scene || typeof scene !== "object" || Array.isArray(scene)) {
    return false;
  }
  if (scene.type && scene.type !== "excalidraw") {
    return false;
  }
  return Array.isArray(scene.elements);
};

/**
 * Writes a save and returns what it wrote — never the body of the board.
 *
 * `wx` is the append-only guarantee: an existing file is refused by the kernel,
 * so two presses of Save in the same millisecond produce two saves rather than
 * one lost board.
 */
export const writeSave = (root, { identity, roomId, scene }, { at = Date.now() } = {}) => {
  const dir = identityDir(root, identity);
  if (!dir) {
    return { ok: false, status: 503, error: "no board shelf is configured on this server" };
  }
  const room = safeRoom(roomId);
  if (!room) {
    return { ok: false, status: 400, error: "the room id is not a room id" };
  }
  if (!looksLikeScene(scene)) {
    return {
      ok: false,
      status: 400,
      error: "the body is not a board — it needs an elements list",
    };
  }

  const body = JSON.stringify(scene);
  const bytes = Buffer.byteLength(body);
  if (bytes > MAX_SAVE_BYTES) {
    return { ok: false, status: 413, error: `the board exceeds ${MAX_SAVE_BYTES} bytes` };
  }

  const stamp = stampOf(at);
  mkdirSync(dir, { recursive: true, mode: 0o700 });

  for (let attempt = 0; attempt < 1000; attempt += 1) {
    const id = `${room}-${stamp}${attempt === 0 ? "" : `-${attempt}`}`;
    const path = join(dir, `${id}${SAVE_EXTENSION}`);
    try {
      writeFileSync(path, body, { flag: "wx", mode: 0o600 });
      return { ok: true, id, room, stamp, bytes, path };
    } catch (error) {
      if (error?.code === "EEXIST") {
        continue;
      }
      return { ok: false, status: 500, error: error?.message ?? String(error) };
    }
  }
  return { ok: false, status: 500, error: "could not find a free save name" };
};

const entriesOf = (dir) => {
  try {
    return readdirSync(dir);
  } catch {
    return [];
  }
};

/** The caller's own saves, newest first. Never another person's, never a count of them. */
export const listSaves = (root, identity) => {
  const dir = identityDir(root, identity);
  if (!dir) {
    return [];
  }
  return entriesOf(dir)
    .filter((name) => name.endsWith(SAVE_EXTENSION))
    .sort()
    .reverse()
    .map((name) => {
      const path = join(dir, name);
      const id = name.slice(0, -SAVE_EXTENSION.length);
      const dash = id.indexOf("-", id.length - 20);
      let bytes = 0;
      let at = null;
      try {
        const info = statSync(path);
        bytes = info.size;
        at = info.mtime.toISOString();
      } catch {
        bytes = 0;
      }
      return {
        id,
        room: dash > 0 ? id.slice(0, dash) : id,
        stamp: dash > 0 ? id.slice(dash + 1) : "",
        bytes,
        at,
      };
    });
};

/**
 * Opens one of the caller's saves.
 *
 * Three answers, and they are different on purpose:
 *   `{ok:true, scene, …}`          — yours
 *   `{ok:false, status:403, …}`    — a real save, and it is NOT yours: refused by
 *                                    name, because an empty answer would claim
 *                                    you never saved it
 *   `{ok:false, status:404, …}`    — no such save anywhere
 *
 * The refusal never names the owner: the caller learns "not yours", which is the
 * whole truth they are owed.
 */
export const readSave = (root, { identity, id }) => {
  const dir = identityDir(root, identity);
  if (!dir) {
    return { ok: false, status: 503, error: "no board shelf is configured on this server" };
  }
  if (!isPlausibleSaveId(id)) {
    return { ok: false, status: 400, error: "that is not a save id" };
  }

  const own = join(dir, `${id}${SAVE_EXTENSION}`);
  if (isInside(dir, own)) {
    try {
      const raw = readFileSync(own, "utf8");
      return { ok: true, id, scene: JSON.parse(raw), path: own };
    } catch (error) {
      if (error?.code !== "ENOENT") {
        return { ok: false, status: 500, error: "the save could not be read" };
      }
    }
  }

  // It is not on this person's shelf. Does it exist at all?
  for (const name of entriesOf(root)) {
    if (name === identity) {
      continue;
    }
    const other = identityDir(root, name);
    if (!other) {
      continue;
    }
    if (entriesOf(other).includes(`${id}${SAVE_EXTENSION}`)) {
      return {
        ok: false,
        status: 403,
        reason: "not-yours",
        error: "that save is not yours — a board belongs to the person who saved it",
      };
    }
  }

  return { ok: false, status: 404, error: "there is no save with that id" };
};

export const readConfig = (env = process.env) => {
  const home = env.YMIR_HOME ?? "";
  return {
    /**
     * The board shelf. It is in the HOME, not in the repo (Rule 04): `hodd/life/boards`.
     * Unset home means the shelf is off, and the door says so instead of writing
     * a board into whatever directory the process happened to start in.
     */
    dir: env.COLLAB_SAVES_DIR ?? (home ? join(home, "hodd", "life", "boards") : ""),
    maxBytes: Number(env.COLLAB_MAX_SAVE_BYTES ?? MAX_SAVE_BYTES),
  };
};
