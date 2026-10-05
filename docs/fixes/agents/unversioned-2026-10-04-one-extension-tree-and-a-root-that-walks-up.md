## agents · unversioned · 2026-10-04 — one extension tree, and a root that walks up

### Why

The Pi extensions lived in **two** trees, and `bin/seat/valknut-load.sh` copied the
second into `<agent-dir>/extensions/`. Pi loads the global and the project directory
and does **not** de-duplicate, so the moment the extensions moved into the repo the
deployed copy collided with them and **every extension refused to load**:

```
Error: Failed to load extension "<agent-dir>/extensions/ymirhome.ts":
  Tool "ymir_recall" conflicts with <repo>/.pi/extensions/ymirhome.ts
```

That is the failure `RULES/13-pi-extensions.md` §1 exists to prevent. It is now
fixed **at the source**: the extensions live where pi already reads them, and nothing
is deployed to collide with them.

### What moved

- The six that remained in `.pi/shared/extensions/` — `eindri`, `gna-pi-watch`,
  `herdr`, `odrerir`, `rules`, `syn-turnend-guard` — moved into `.pi/extensions/`.
- **They were stubs where they landed.** `.pi/extensions/` held 133–651-byte no-op
  factories for all six while the real extensions sat in `.pi/shared/` at 8–40 KB,
  so **Sýn and Gná were loading as empty functions.** The real files replaced them.
- **`.pi/shared/extensions/` held nothing unique** — every file already had a
  counterpart — so the whole tree is removed rather than moved. It was a second
  source directory for one extension system, and that was the whole fault.
- The three no-op stubs that sat beside their own folders (`ro.ts`,
  `constellation.ts`, `skuld-branch-supervision.ts`) are gone.

### Two root-resolution faults, both Rule 12's lesson applied to the wrong file

**1. A fixed climb.** `resolveYmirRoot` resolved the root as
`resolve(extensionDir, "../..")` — correct only while every extension sat flat. The
moment one became a folder, the climb landed on `.pi/`, which owns no `bin/`, and six
extensions failed with *"YMIR_ROOT is not set and .ymir-root holds no usable root."*

Rule 12 says **"a door may never resolve the repo by counting `..`"**, because depth
must not be able to blind the resolver. The same law, the same reason — this file had
not learned it. It now **walks up** until it finds a directory owning `bin/`.

**2. A hardcoded door as the root marker.** Twelve files decided "is this a Ymir
root?" by testing for `bin/pi/syn-watch-arm.sh`. The 250-door restructure moved it to
`bin/pi/`, so `.ymir-root` was correct and **every check still failed**.

**A root owns `bin/`. It does not own any particular door.** All twelve now test for
the directory, so a door moving can no longer break a root check — which is the whole
class of fault that produced tonight's breakage.

### Verified

```
19 extensions discovered · 0 load errors · 32 tools · 0 double-registered · 2 commands
28 relative imports resolved, 0 unresolved
```

Five factories cannot run under bare `node` because they import pi's own packages
(`@earendil-works/pi-tui`, `pi-ai`, `pi-coding-agent`); pi provides those at runtime,
which is the same exemption the project's own `extension-smoke` records.

### Not fixed here — eleven exec'd paths are still dead

The same hardcoded-door fault, but in paths the extensions **run** rather than test.
These fail silently the way Sýn's own header warns: exit 127, no heartbeat, watch
dead, every listing correct.

`bin/pi/syn-watch-arm.sh` · `bin/gates/guards/syn-turnend-guard.sh` · `bin/gates/checks/syn-arm-pretool-check.sh`
· `bin/gates/checks/syn-cd-pretool-check.sh` · `bin/gates/checks/syn-asset-pretool-check.sh` ·
`bin/vault/gleipnir-lock-lib.sh` · `bin/agents/groa-update.sh` · `bin/gates/queue.sh` ·
`bin/gates/capabilities.sh` · `bin/gates/inventory.sh` · `bin/gates/checks/home-index-check.sh` ·
`bin/agents/brokk-lease-lib.sh`

They belong to the `bin/` restructure and its callers. **Guessing at destinations
from six extensions is how the wrong door gets exec'd silently**, so this records
them instead of guessing.
