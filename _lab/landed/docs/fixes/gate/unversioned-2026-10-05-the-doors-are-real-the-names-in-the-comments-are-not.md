## gate · unversioned · 2026-10-05 — the doors are real; the names in the comments are not

### Why

Reported as *"six doors lost in the bin rebuild"*. **They were never lost.** They
exist today under their upstream `fm-*` names in `bin/backend/`, and the tests that
exercise them pass.

| reported missing | actually here | size |
|---|---|---|
| `bin/brokk-watch.sh` | `bin/backend/fm-watch.sh` | 96 KB, 1,962 lines |
| `bin/brokk-control.sh` | `bin/backend/fm-control.sh` | 39 KB, 878 lines |
| `bin/brokk-gate-refuse-lib.sh` | `bin/backend/fm-gate-refuse-lib.sh` | 5 KB, 102 lines |
| `bin/brokk-claude-stop-autoarm.sh` | `bin/backend/fm-claude-stop-autoarm.sh` | 16 KB, 334 lines |

**The error was mine.** I searched for the *paths*, found nothing, and reported it as
though it meant the *functionality*. The Allfather pushed back — *"this files hade
functonality"* — and he was right.

### What was actually broken

**Nine references across four live doors named a door that does not exist.** Eight are
comments, which cost nothing but lie. **One was a live instruction:**

```diff
- note: mend it with: bin/ymir-visualizer.sh build
+ note: mend it with: bin/desktop/smidja-board.sh build
```

Anyone who followed that hint got `no such file`. The door it named has since become
`bin/desktop/smidja-board.sh`, which builds the UI itself.

### Fixed

Every one now names a door that exists, **each replacement target verified on disk
before the edit**:

`brokk-watch` · `brokk-gate-refuse-lib` · `brokk-control` · `brokk-claude-stop-autoarm`
· `brokk-supervise-daemon` · `brokk-send` · `brokk-teardown` · `ymir-visualizer`

`bash -n` clean across all four doors.

### Still open, deliberately

**Plan 29 §12's rename is unfinished.** 156 files in `bin/backend/` carry upstream
`fm-*` names, and the naming law says those *"must never name a Ymir component"*. The
comments now tell the truth — **the truth being that the Norse rename has not happened
yet.** Completing it is deliberate work and the Allfather has deferred it.

**The comments could have been made to lie on purpose**, naming the future `brokk-*`
path. They were not: a comment that describes a door that does not exist is a small
lie that costs a future reader an hour.

### The lesson

> **Search for the thing, not for the name.** A path that resolves to nothing and a
> capability that is gone are different findings, and I reported the first as the
> second.

Both were true at once here — the paths were wrong *and* the rename was unfinished —
but only one of them was a loss of functionality, and it was none.
