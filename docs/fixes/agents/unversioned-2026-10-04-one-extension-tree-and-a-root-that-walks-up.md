## agents · unversioned · 2026-10-04 — one extension tree, and a root that walks up

### Why

The Pi extensions lived in **two** trees — `.pi/extensions/` and
`.pi/shared/extensions/` — and `bin/seat/valknut-load.sh` copied the second into
`<agent-dir>/extensions/`. Pi loads both the global and the project directory and
does **not** de-duplicate, so when the extensions moved into the repo the deployed
copy collided with them and **every extension refused to load**:

```
Error: Failed to load extension "<agent-dir>/extensions/ymirhome.ts":
  Tool "ymir_recall" conflicts with <repo>/.pi/extensions/ymirhome.ts
```

That is the failure Rule 13 §1 exists to prevent, and it is now **fixed at the
source**: the extensions live where pi already reads them, and there is nothing
deployed to collide with.

### What moved

- The six that remained in `.pi/shared/extensions/` — `eindri.ts`, `gna-pi-watch.ts`,
  `herdr.ts`, `odrerir.ts`, `rules.ts`, `syn-turnend-guard.ts` — moved into
  `.pi/extensions/`.
- **They were stubs where they landed.** `.pi/extensions/` held 133–651-byte no-op
  factories for all six while the real extensions sat in `.pi/shared/` at 8–40 KB,
  so **Sýn and Gná were loading as empty functions.** The real files replaced them.
- **`.pi/shared/extensions/` was a stale duplicate of all 32 files** — nothing in it
  was unique, and 14 of them differed from the live copy. Removed.
- The deployed copy at `<agent-dir>/extensions/` was moved aside, so nothing can
  collide with the in-tree source.

### The root resolver climbed a fixed number of levels

`lib/ymir-home.ts` resolved the distro root as `resolve(extensionDir, "../..")` —
correct only while every extension sat flat in one directory. The moment an
extension became a folder, `constellation/index.ts`, the climb landed on `.pi/`,
which owns no `bin/`, and six extensions failed with *"YMIR_ROOT is not set and
.ymir-root holds no usable root."*

**Rule 12 says: a door may never resolve the repo by counting `..`.** The same law,
the same reason, and this file had not learned it. `resolveYmirRoot` now **walks up**
until it finds a directory that owns `bin/`.

### The root marker was one named door — and that door moved

Twelve files decided "is this a Ymir root?" by testing for
`bin/syn-watch-arm.sh`. The 250-door restructure moved it to `bin/pi/`, so
`.ymir-root` was correct and every check still failed.

**A root owns `bin/`; it does not own any particular door.** All twelve now test
for the directory. A door moving can no longer break a root check.

### Verified

```
$ node discoverAndLoadExtensions([], <repo>, <agent-dir>)
DISCOVERED: 22    ERRORS: 0
```

All 28 relative imports inside the tree resolve, and the six that were stubs now
load their real 8–40 KB selves.

### Not fixed here — eleven exec'd paths are still dead

The same hardcoded-door fault, but in paths the extensions **execute** rather than
test. These fail silently the way Sýn's own header warns: exit 127, no heartbeat,
watch dead, every listing correct.

`bin/syn-watch-arm.sh` · `bin/syn-turnend-guard.sh` · `bin/syn-arm-pretool-check.sh`
· `bin/syn-cd-pretool-check.sh` · `bin/syn-asset-pretool-check.sh` ·
`bin/gleipnir-lock-lib.sh` · `bin/groa-update.sh` · `bin/queue.sh` ·
`bin/capabilities.sh` · `bin/inventory.sh` · `bin/home-index-check.sh` ·
`bin/brokk-lease-lib.sh`

They are owned by the `bin/` restructure and its callers, and guessing at
destinations from six extensions is how the wrong door gets exec'd silently.
Recorded here so they are not rediscovered.
