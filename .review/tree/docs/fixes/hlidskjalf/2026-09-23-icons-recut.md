## hlidskjalf · unversioned · 2026-09-23 — the old app icons are re-cut from the design

### Why
- **Problem (Allfather):** *"why do we still have the old icons in the repo for the
  apps — now they are blue and pink."* The SVG icons had long since moved to the
  carved cloth (stone + rune + bronze/amber), but the **rasterised copies** the
  menu and launchers actually show were stale relics:
  - `apps/hlidskjalf/electron/icon.png` and `apps/odrerir/electron/icon.png` —
    **blue** (`srgba(21%,70%,93%)`);
  - `apps/hlidskjalf/public/ymir-icon.png` — a **grayscale** PNG;
  - `apps/hlidskjalf/electron/smidja-icon.png` and the smithy's
    `desktop/icon.png` — off-palette orange;
  - the Sessrúmnir `.ico` files;
  - the **Android launcher tiles** (`mipmap-*/ic_launcher.png`, `ic_launcher_round.png`,
    and a rune-only `ic_launcher_foreground.png`) — a stale **grayscale** relic;
  - the **Android splash screens** (`drawable*/splash.png`) — a plain **white**
    relic, re-cut to the stone ground with the icon centred at each size.
  Nothing regenerated them, so the design and the launch icons drifted apart.
- **Fix (Rule 7, script-first):** a new **`bin/design-icon.sh raster`** action —
  idempotent, writes nothing else — re-cuts every app icon from its own
  `public/icon.svg` (via `rsvg-convert`, else `magick`):
  - hlidskjalf → `electron/icon.png` (512), `public/apple-touch-icon.png` (180);
  - odrerir → `electron/icon.png` (512), `public/apple-touch-icon.png` (180);
  - sessrumnir → `resources/icons/icon-{16…512}.png`, `icon.png`,
    `public/apple-touch-icon.png`, and the two `.ico` files;
  - smidja → `apps/smidja-factory/apps/visualizer/desktop/icon.png` (512);
  - the Ymir emblem (**algiz** on stone) → `hlidskjalf/public/ymir-icon.png`,
    the smithy's icon → `hlidskjalf/electron/smidja-icon.png`.

### Verified
- **47 files** re-cut. Every regenerated icon now samples as **stone**
  (≈ `7%,6%,4%`) — the blue is gone; `ymir-icon.png` reports **sRGB**, not
  grayscale; the Android tiles are **sRGB** and the splashes stone; the `.ico`
  files are stone.
- `bash -n` clean; `compliance` clean (the `hlidskjalf-ui` asset records the
  action).

### Files
- `bin/design-icon.sh` (+ `raster`)
- 47 raster icons under `apps/hlidskjalf` (incl. the Android `mipmap-*` and
  `drawable*`), `apps/odrerir`, `apps/sessrumnir`,
  `apps/smidja-factory/apps/visualizer`
- `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`
