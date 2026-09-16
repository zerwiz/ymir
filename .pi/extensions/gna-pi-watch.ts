/**
 * NOT AN EXTENSION — a tombstone.
 *
 * This file used to hold a second copy of an extension that already lives in the
 * shared source (`.pi/shared/extensions/`) and is deployed to the ONE global home,
 * `~/.pi/agent/extensions/`. pi auto-discovers extensions from BOTH the global home
 * and the project tree, so the two copies registered the same tools twice and pi
 * refused the second: `Tool "gna_watch_arm" conflicts with …`. Every pi start in
 * every worktree died on it, and a seated worker fell through to a bare shell.
 *
 * It exports no default factory, so pi registers nothing from it. The extension is
 * `gna-pi-watch` — edit that one, in the shared source, and deploy it.
 */
export {};
