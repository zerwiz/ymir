# A dependency folder can be reflinked, and a session id names no harness

**2026-11-20 · component: collab**

## What was wrong

Installing the kit into a product monorepo, `bun run build` failed in a kit worktree: Next.js Turbopack refused
`web/node_modules` because the symlink pointed out of the project root ("Symlink web/node_modules is invalid, it
points out of the filesystem root"). And that repository's rules gate refused the kit's code for naming a harness
in an environment variable.

## What was forged

| Change | Where |
|---|---|
| `link_mode: reflink` per part — `cp -a --reflink=always`: a real folder sharing the main tree's blocks (btrfs, XFS, APFS); a symlink where the filesystem cannot reflink, said aloud | `kit/scripts/kitlib/worktrees.py`, `profiles/monorepo-bun-uv-mix.yaml` |
| the session id: `KIT_SESSION`, else the variables `KIT_SESSION_VARS` names | `kit/scripts/kitlib/work.py`, `kit/docs/harness-hooks.md` |

## What was run

```
cp -a --reflink=always <main>/web/node_modules web/node_modules   → 6.7 s; bun run build passes
btrfs filesystem du -s <worktree>                                  → 310 MiB exclusive, 833 MiB shared
python3 bin/collab/tests/test_kit.py -k K03                        → OK
python3 bin/collab/tests/test_work.py                              → Ran 13 tests … OK
```
