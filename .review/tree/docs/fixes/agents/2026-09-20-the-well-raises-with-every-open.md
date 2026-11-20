## agents · unversioned · 2026-09-20 — the well raises with every pi open

### Why
- **A `clear`-source reopen left the well silent.** The Allfather's pi session
  opened with `--source clear` (context re-emit) and the `ymir-well` extension
  printed `Unable to connect` — the well bridge (`bin/mimir-bridge.py`, `:4602`)
  was down, and the only raiser lived inside `bin/saga-session-start.sh` (the
  2026-09-20 birth-race mend). The run-tier adapter runs
  `bin/saga-sessionstart-run.sh`, and on `clear`/`compact` after a completed
  startup it **skips the digest entirely** — so the bridge was never raised, no
  matter how patient the probe. A well that does not start cannot be probed up.
- **The first cold recall outran the call cap.** `call()` applied a hard
  `AbortSignal.timeout(15000)`; a cold-start recall fetches the engram embedding
  model from HF once (measured ~17s) and was aborted at 15s — a timed-out
  `well_recall` even with the bridge up.

### Fix
- `bin/saga-sessionstart-run.sh` now raises the well bridge (idempotent
  `bin/mimir-bridge.sh --start`, silent on success, one line on failure) **before**
  source routing, so every pi open — startup/new, clear/compact re-emit, and
  resume/reload/fork — has `:4602` listening before the session binds and the
  extension's `session_start` probe fires. The full digest repeats the raise only
  as its own status line.
- The extension's call timeout is now `Number(process.env.YMIR_WELL_TIMEOUT_MS) || 60000`
  (Rule 07: one env with one documented default), so a cold model fetch survives.

### Verify
- `bin/saga-sessionstart-run.sh --source clear` prints only the re-emit text when
  the bridge is up (already-up is silent), and `curl :4602/health` answers.
- A fresh or re-emitted pi session opens with no `ymir-well` extension error, and
  the first-ever recall of a cold bridge completes (no 15s abort).

### Files
- `bin/saga-sessionstart-run.sh`
- `.pi/shared/extensions/ymir-well.ts`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` —
the well section now says the runner raises the bridge on every open; extension
one-home rule unchanged. `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md` —
runner section notes the pre-routing well raise.