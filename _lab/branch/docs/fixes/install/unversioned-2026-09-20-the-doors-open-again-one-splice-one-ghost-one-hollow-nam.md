## install · unversioned · 2026-09-20 — the doors open again: one splice, one ghost, one hollow name

### Why
- **The killer — a spliced line in `scripts/electron.sh`.** `ROOT="$(cd "` ran
  straight into a stray comment and a `mkdir"$ROOT/state"` statement inside the
  command substitution, so `ROOT` never bound and every icon that ran the door
  (`ymir-hlidskjalf`, `ymir-odrerir`, `ymir-visualizer`) died on line 30 with
  `ROOT: unbound variable`. The splice rode in with the bragi-translation PR's own
  copy of the file and was sealed into main by its merge; none of the doors opened.
  Mended: `ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"` with the fresh-install
  `mkdir -p "$ROOT/state"` standing outside the substitution, where it belongs.
- **A hollow name — `app_dir smidja` resolved to nothing.** The smithy's surface
  maps to package `smidja-factory`, but the clone-shape probe only looked at
  `apps/smidja` — a `.py` husk with no manifest, correctly skipped, with
  `apps/smidja-factory` (the real app) never tried. The visualizer's Electron
  therefore launched with an empty path and showed nothing. The clone shape now
  probes `apps/<package>` too; the npm shape is untouched (no `apps/` exists
  there), so a packaged install resolves exactly as before.
- **A ghost pid — `start.sh` trusted `kill -0`, not the port.** A pid that lives
  but serves nothing (a dev server bound to a foreign port, or dead) passed the
  check, skipped the raise, and left Hlidskjalf's window pointing at a dead URL.
  The check now requires the port to answer; a live pid that does not serve is
  purged and the hall re-raised. And the raise's window-opening block reached for
  `$SCRIPT_DIR` (an `electron.sh` variable `start.sh` never defines) — now bound
  to `$ROOT/scripts`, so `ymir raise` opens the four windows as designed.
- **Verified live:** all four halls answer and open — Hlidskjalf :3888, the gate
  :3889, Óðrerir :4322 (its Electron runtime self-fetched on first breath), the
  Smiðja visualizer :8437, the seat-hall Sessrúmnir (own window).

### Files
- `electron.sh`
- `scripts/electron.sh`
- `start.sh`
