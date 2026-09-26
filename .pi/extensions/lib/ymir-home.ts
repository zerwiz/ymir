/**
 * ymir-home.ts — where the distro lives, as seen from a DEPLOYED extension.
 *
 * Pi extensions are deployed to ONE global home (`${HOME}/.pi/agent/extensions/`;
 * see `bin/valknut-load.sh` and the harness-integration asset). Deployed away from
 * the tree that owns `bin/`, a copy cannot find it by walking up: the old
 * `resolve(extensionDir, "../..")` reached `${HOME}/.pi`, which holds pi's own
 * config and no `bin/` at all. Every extension that then exec'd `${root}/bin/…`
 * exec'd a path that does not exist, and the failure was silent by construction —
 * the Gná arm child died with exit 127 before its first poll, no
 * `state/.watch.heartbeat` was ever written, and the watch was dead while every
 * file listing looked correct. A deploy that copies an extension without telling
 * it where its own `bin/` lives is not a deploy.
 *
 * So the root is RECORDED at deploy time: `bin/valknut-load.sh --pi` writes one
 * absolute root per line, most recent first, to `.ymir-root` beside the deployed
 * extensions, and this module reads it back. Resolution order:
 *
 *   1. BROKK_ROOT_OVERRIDE · BROKK_HOME · YMIR_ROOT — an explicit word wins
 *   2. the recorded roots, first one that verifies
 *   3. `resolve(extensionDir, "../..")` — the pre-pointer contract, unchanged
 *
 * A candidate only counts if it really holds `bin/syn-watch-arm.sh`, so a root
 * that no longer exists (a merged-and-removed Yggdrasil worktree, an uninstalled
 * npm prefix) is skipped rather than trusted. Nothing here is hardcoded: the
 * record is written by the loader that performed the deploy (Rule 07).
 *
 * Note the deliberate split it enables: the ROOT owns `bin/`, the HOME owns
 * `state/` and `config/`. They are usually the same tree and need not be — a
 * private `$YMIR_HOME` has no `bin/` of its own, and conflating the two is what
 * made the deployed copy exec a path that never existed.
 */
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

/** The deploy-time root record, written beside the deployed extensions. */
export const YMIR_ROOT_POINTER = ".ymir-root";

/** A root is usable only when the arm script it will exec is really there. */
export function isYmirRoot(candidate: string | undefined): boolean {
  if (!candidate) return false;
  return existsSync(resolve(candidate, "bin", "syn-watch-arm.sh"));
}

function recordedRoots(extensionDir: string): string[] {
  try {
    return readFileSync(resolve(extensionDir, YMIR_ROOT_POINTER), "utf8")
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean);
  } catch {
    // No record — a session that started before the pointer contract.
    return [];
  }
}

/**
 * The distro root: the tree that owns `bin/`. Never the session home.
 */
export function resolveYmirRoot(extensionDir: string): string {
  const explicit = [
    process.env.BROKK_ROOT_OVERRIDE,
    process.env.BROKK_HOME,
    process.env.YMIR_ROOT,
  ].filter((value): value is string => Boolean(value));
  const legacy = resolve(extensionDir, "../..");
  for (const candidate of [...explicit, ...recordedRoots(extensionDir), legacy]) {
    if (isYmirRoot(candidate)) return resolve(candidate);
  }
  // Nothing verified. Name the first candidate we were given, so the failure
  // surfaces as a missing bin/ at that exact path — never hidden behind another.
  return resolve(explicit[0] ?? legacy);
}

/**
 * The session's HOME: the operator's private root that owns `state/` and
 * `config/`. Resolved the SAME way every shell tool resolves it, through
 * `bin/hoard-lib.sh`'s documented order (Rule 04):
 *
 *   1. `$YMIR_HOME` — an explicit word wins
 *   2. the recorded choice, `~/.config/ymir/home`
 *   3. the documented default, `$HOME/Documents/ymirhome`
 *
 * The ROOT owns `bin/`; the HOME owns `state/`. An extension that never resolves
 * the home falls back to its own root and writes private runtime state into the
 * public code tree — the drift this closes (2026-09-25). Never return the tree.
 */
export function resolveYmirHome(): string {
  const explicit = process.env.YMIR_HOME;
  if (explicit) return resolve(explicit);
  const home = process.env.HOME || process.env.USERPROFILE || "";
  try {
    const recorded = readFileSync(resolve(home, ".config", "ymir", "home"), "utf8").trim();
    if (recorded) return resolve(recorded);
  } catch {
    // no recorded choice — fall through to the documented default
  }
  return resolve(home, "Documents", "ymirhome");
}
