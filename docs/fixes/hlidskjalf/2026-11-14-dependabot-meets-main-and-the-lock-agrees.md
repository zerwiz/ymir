## hlidskjalf · 2026-11-14 — dependabot's bump meets main's, and the lock agrees with both package sets

### Why

PR #744 (dependabot, the npm minor-and-patch group, 25 updates) could not be merged: `apps/hlidskjalf/package.json`,
`apps/sessrumnir/package.json` and `package-lock.json` all conflicted, because main had bumped the same three
packages while the branch sat open. Merge state was CONFLICTING — the PR could not move at all.

### What the conflict was

Three dependency lines, and only those, differed:

| package | main had | the branch had |
|---|---|---|
| `@capacitor/cli` (hlidskjalf) | `^6.2.2` | `^6.2.3` |
| `react-i18next` (sessrumnir) | `^17.0.14` | `^17.1.13` |
| `vite` (sessrumnir) | `^6.3.5` | `^6.4.6` |

Every one is a dependabot bump **above** main's range, so the branch's line is the newer answer and main's is the
stale one. The lockfile's two hunks were the same two range strings inside `packages["apps/sessrumnir"]` — no
resolved `node_modules` entry conflicted, which is why no `npm install` was run (this machine has 11 GB and a
lock regeneration is not free).

### The resolution

Take the branch's line in all six hunks, then prove the lock still speaks to the manifests rather than assuming
it:

```
node_modules/react-i18next  17.1.13
node_modules/vite           6.4.6
node_modules/@capacitor/cli 6.2.3
```

Each matches the range the merged `package.json` files now declare, and all three JSON files parse. A lock that
disagrees with its manifest is the fault this check exists to catch.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #765
