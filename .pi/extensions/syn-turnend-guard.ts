/**
 * NOT AN EXTENSION — a tombstone.
 *
 * A second copy of an extension that already lives in the shared source
 * (`.pi/shared/extensions/`) and deploys to the ONE global home. pi auto-discovers
 * both, so both copies loaded and pi refused the duplicate tool registration.
 * Every pi start in every worktree died on it, and a seated worker fell through to
 * a bare shell.
 *
 * It exports no default factory, so pi registers nothing from it. The real
 * extension is `syn-turnend-guard` — edit that one, in the shared source.
 */
export {};
