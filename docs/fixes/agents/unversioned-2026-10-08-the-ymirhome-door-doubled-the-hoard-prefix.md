## agents · unversioned · 2026-10-08 — the ymirhome door doubled the hoard prefix

### Why
`hodd.sh path` answers the **hoard** (`…/ymirhome/hodd`), but every shelf
string the ymirhome doors build is **home-relative with the `hodd/` prefix**
(`hodd/docs/…`). `resolveHome()` returned the hoard as if it were the home, so
the movers aimed at `home/hodd/hodd/…`. Measured twice on 2026-10-08 while
filing the fleet security scan: `ymir_import`'s `git mv` died with
`home/hodd/hodd/reference/imported/…`, and `ymir_place`'s `mv` died with
`home/hodd/hodd/docs/…`. The scan file landed nowhere until the move was done
by hand.

### Mend
- `resolveHome()` now returns the **HOME** (the hoard's parent) for the
  `hodd.sh path` fallback; `YMIR_HOME` (already the home) is unchanged.
- A latent sibling defect the typechecker named in the same file:
  `ymir_layout` read `v.path` from `classify()`, which returns no such field —
  the door would have printed `undefined` on any classification. It now prints
  the path it was asked about.

### Proven
- `valknut-load --check` PASS (the .pi gate).
- `tsc --noEmit` clean after both edits (the layout error is gone).
- The same filing moves now build a single-hodd destination.
