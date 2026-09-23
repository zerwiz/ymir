## runtime · unversioned · 2026-09-23 — one wake queue: the watcher and the handoff now read the same state

### Why
The handoff fired and Brokk was still not told. The cause was **two state
directories**, and both ends were individually correct:

| | resolved state |
|---|---|
| **The watcher** (Sýn, `bin/syn-watch-arm.sh`) | `$BROKK_STATE_OVERRIDE` else `$BROKK_HOME/state` — the **code tree**, `/home/heimdall/ymir/state` |
| **The handoff** (`bin/eindri-acclaim.sh`) | `$YMIR_STATE_DIR` via `bin/hoard-lib.sh` — the **hoard**, `~/Documents/ymirhome/state` |

So the handoff wrote the wake into the hoard's `.wake-queue` while the watcher
polled the tree's — a queue that did not exist. Proof on disk:

```
repo  state/.wake-queue : ABSENT
hoard state/.wake-queue : exists (5 lines, incl. "eindri bragi reported …")
```

The extension set the fallback: `state = BROKK_STATE_OVERRIDE || ${fmHome}/state`,
and `fmHome` is the repo when `BROKK_HOME` is unset — so the watcher was pointed
at the tree. **The task wrote, the watcher watched, and the two never met.**

### Fix
- **`.pi/shared/extensions/gna-pi-watch.ts`** — resolve the operator's home the
  way every shell tool does: `$YMIR_HOME` → the recorded choice
  (`~/.config/ymir/home`) → `$HOME/Documents/ymirhome`; then
  `state = BROKK_STATE_OVERRIDE || <home>/state`. A seat still isolates through
  `BROKK_STATE_OVERRIDE`.
- **`bin/syn-watch-arm.sh`** — defense in depth: when `BROKK_STATE_OVERRIDE` is
  unset, resolve the state through `bin/hoard-lib.sh` instead of defaulting to
  `$BROKK_HOME/state`.

Both now resolve to `/home/heimdall/Documents/ymirhome/state` — **one queue**.

### Verification
- `bash -n` clean on the watcher; the extension parses.
- The watcher's state and the handoff's state are now the identical path
  (`/home/heimdall/Documents/ymirhome/state`), and Bragi's report sits in it.
- The underlying handoff had already fired correctly (the wake line
  `eindri bragi reported: report filed at state/eindri-reports/bragi.md` is in
  the queue) — this fix is what makes the watcher SEE it.

### Files
- `.pi/shared/extensions/gna-pi-watch.ts`
- `bin/syn-watch-arm.sh`
