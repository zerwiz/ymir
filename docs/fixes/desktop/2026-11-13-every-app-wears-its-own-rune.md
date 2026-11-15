# Every app wears its own rune, minted the same way — Bilskirnir and Rödd join

**Status:** built and installed on heimdall, 2026-11-13 (plan 275), at the Allfather's word: *"bilskirnir's and
rödd's logos are not made in the same way as the others."*

## What was wrong

Four apps wore the house style, a single bronze rune on a dark stone tile, minted by `bin/desktop/design-icon.sh`
from the rune shelf. Two did not:

- **Bilskirnir** wore the whole Ymir mark, from its own hand-made icon set, which `apps/bilskirnir/setup.sh` copied
  into the icon theme on every setup.
- **Rödd** wore a black copy of Óðrerir's glyph with no tile, labelled "Ansuz — Forge".

Neither app was in the minter's table. Behind it was a second fault: the minter's `install` wrote its own launcher
entries (`Exec=ymir <app>`) over the ones `bin/desktop/shortcuts.sh` writes (`Exec=ymir-app <app>`), so the
launcher an install left behind depended on which of the two ran last.

## What changed

| Part | Change |
|---|---|
| Runes | Bilskirnir wears ᚦ Thurisaz (Thor's rune, for Thor's hall); Rödd wears ᛚ Laguz (water, flow: the voice). Laguz is newly drawn in `midgard/design-system/icons/laguz.svg`; `runes.md` and `icons.md` name both |
| Minting | Both apps are rows in the minter's table; `mint` writes their `public/icon.svg`, and `raster` cuts their window and launcher PNGs, and Bilskirnir's own theme set at every size |
| Launchers | The minter installs icons only, then runs `shortcuts.sh`, the one launcher writer |
| Rödd's window | Wears `apps/rodd/electron/icon.png`, its own minted icon |

## How it was proven

- The six minted icons rendered side by side match in style; the theme's scalable SVG and 256px PNG agree for every
  app.
- After `design-icon.sh install`, every launcher entry reads `Exec=…/ymir-app <app>` and `Icon=ymir-<app>`.
- The raster also re-cut Hlidskjalf's Android splash screens; those were restored unchanged, as this change does not
  concern them.

## CHANGE LOG

- 2026-11-13 — review-mend: added missing heading for #730
