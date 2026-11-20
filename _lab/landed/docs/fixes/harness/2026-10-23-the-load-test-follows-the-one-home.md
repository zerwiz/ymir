# The load test follows the one home

**Date:** 2026-10-23 · **Component:** harness · **Rule:** 13 (extensions, one home)

## The fault

`bun test ./.pi/extensions/constellation/load.test.ts` failed **3 of 3** before this change — not on
an extension, but on a directory:

```
ENOENT: no such file or directory, lstat '/home/heimdall/ymir/.pi/shared/extensions'
```

The test reproduced a deploy from `.pi/shared/extensions`, the second home that the one-tree
migration removed. A gate that fails on a missing path is a gate nobody reads, and a suite that is
red for the wrong reason hides the failures that matter.

## The change

```
changes[3]{was,is}:
  "deployed from .pi/shared/extensions (gone)","deploys the live shape: .pi/extensions/constellation/ — a directory with index.ts, which is what pi's loader accepts"
  "imported constellation.ts from the scratch home","imports constellation/index.ts"
  "the third case tested the retired project-local shim","tests the one-home rule instead: index.ts present, and no .pi/shared/extensions second path"
```

The scratch deploy has no `bin/` of its own, so the test names the tree that owns one
(`process.env.YMIR_ROOT = ROOT`) — exactly what `.ymir-root` records for a deployed copy
(`lib/ymir-home.ts` resolves `YMIR_ROOT`/`BROKK_ROOT_OVERRIDE` first).

## Verified

```
before: 0 pass · 3 fail  (missing directory)
after:  3 pass · 0 fail  (bun test ./.pi/extensions/constellation/load.test.ts)
```

Also green in the same session: `bin/seat/valknut-load.sh --check` (one home, no duplicate load path,
settings name the tree) and the ward set on push.
