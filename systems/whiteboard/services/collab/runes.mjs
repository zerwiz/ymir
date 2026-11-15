/**
 * Runes — one line per save, list and open.
 *
 * The ledger has ONE writer (`bin/records/runes-append.sh`, which is a shim over
 * the engine's chain), and this module is a caller, never a second
 * implementation. A board that was saved and cannot be found in the ledger is a
 * board nobody can account for, so the three save doors each carve a line.
 *
 * A refused open carves a line too: a refusal is an action, and the person whose
 * save it was is entitled to a record that somebody asked.
 *
 * The line carries identity, save id, room and time — never a scene, never a
 * room key, never a header's raw value.
 *
 * `tickets/open/feature-0036-uw-save-to-server-and-choose-a-session.md`.
 */

import { execFile } from "node:child_process";
import { accessSync, constants } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/** This file's own directory, so the default door can be found without a machine path. */
const here = dirname(fileURLToPath(import.meta.url));

/**
 * The door, in order of authority:
 *   1. `COLLAB_RUNES_DOOR` — an operator naming it explicitly;
 *   2. the pinned runtime's door (`YMIR_RUNTIME_DIR`), which is where a deployed
 *      seat keeps Ymir — the whiteboard is deployed OUTSIDE the repo, so the
 *      repo-relative door below is not reachable from it;
 *   3. the checkout this file sits in, for a run from the tree itself.
 */
export const resolveDoor = (env = process.env) => {
  if (env.COLLAB_RUNES_DOOR) {
    return env.COLLAB_RUNES_DOOR;
  }
  const candidates = [];
  if (env.YMIR_RUNTIME_DIR) {
    candidates.push(join(env.YMIR_RUNTIME_DIR, "bin", "records", "runes-append.sh"));
  }
  // systems/whiteboard/services/collab → repo root is four levels up
  candidates.push(resolve(here, "..", "..", "..", "..", "bin", "records", "runes-append.sh"));
  candidates.push(join(env.HOME ?? "", "ymir-runtime", "bin", "records", "runes-append.sh"));
  for (const candidate of candidates) {
    try {
      accessSync(candidate, constants.X_OK);
      return candidate;
    } catch {
      continue;
    }
  }
  return "";
};

/** One Rune. Fire-and-forget: a ledger that is slow must not fail a save. */
export const carveRune = (door, { actor, event, message }) => {
  if (!door) {
    return { ok: false, error: "no runes door on this seat" };
  }
  const safeActor = String(actor ?? "whiteboard").replace(/[^A-Za-z0-9._@-]/g, "-");
  const safeEvent = String(event ?? "board").replace(/[^A-Za-z0-9._-]/g, "-");
  try {
    const child = execFile(
      door,
      [safeActor, safeEvent, "--message", String(message ?? "")],
      { timeout: 5000 },
      () => {},
    );
    child.unref?.();
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error?.message ?? String(error) };
  }
};

export const readConfig = (env = process.env) => ({
  door: resolveDoor(env),
});
