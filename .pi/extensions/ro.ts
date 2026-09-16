/**
 * NOT AN EXTENSION — a tombstone.
 *
 * A second copy of an extension that already lives in the shared source
 * (`.pi/shared/extensions/`) and deploys to the ONE global home. pi auto-discovers
 * both the global home and the project tree, so both copies loaded and pi refused
 * the duplicate tool registration. Every pi start in every worktree died on it.
 *
 * It exports no default factory, so pi registers nothing from it. The real
 * extension is `ro` — edit that one, in the shared source, and deploy it.
 */
export {};
