/**
 * NOT AN EXTENSION — a tombstone.
 *
 * A second copy of an extension that already lives in the shared source
 * (`.pi/shared/extensions/`) and deploys to the ONE global home. pi auto-discovers
 * both, so both copies loaded and pi refused the duplicate tool registration —
 * `Tool "brokk_branch_outcomes" conflicts with …`. Every pi start died on it.
 *
 * It exports no default factory, so pi registers nothing from it. The real
 * extension is `skuld-branch-supervision` — edit that one, in the shared source.
 */
export {};
