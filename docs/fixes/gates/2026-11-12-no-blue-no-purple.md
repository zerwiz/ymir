# gates · 2026-11-12 — no blue and no purple: the house-colour ward, and the sweep

**Status:** done on branch `eindri/no-blue-no-purple`; two areas held for the Allfather's word.

**In three sentences.** The Allfather ruled that blue and purple must not exist in this repository. A new ward,
`bin/gates/guards/house-colour-guard.sh`, finds them by hue and names the house colour each becomes, and it now runs in
the pre-push wards and in CI. The sweep carried 503 colours in 81 files and six banner pictures into the cloth.

## Files

| What | Where |
|---|---|
| The law | `RULES/54-no-blue-no-purple.md` (with its row in `RULES/README.md`) |
| The ward | `bin/gates/guards/house-colour-guard.sh` and its engine `house-colour-guard.py` |
| What may stay, and why | `house-colour.allow` (repo root) |
| Wired in | `bin/gates/guards.sh` — in `WARDS`, and `SCOPED` so a push reads only the files it changed |

## What was wrong

A count on 2026-11-12 found 562 cool colours in 136 files: Snotra's mail templates, the SVG emblems and the stave, the
Smíðja visualizer, Hlidskjalf's realm and accent presets, the house accents in `tokens.css` (raven violet, jötun
magenta, two slates), skill assets, design documents, and six banner pictures. No ward looked at colour, so each new
app could bring blue back in.

## Fix

The ward judges a colour by hue (185°–330°), saturation (at least 15 %) and lightness (6 %–94 %). It reads hex,
`rgb()`/`hsl()`, Tailwind classes and cool CSS colour names. An all-digit short hex such as `#636` counts only in a
stylesheet or as a colour value, so issue numbers are not judged.

Every cool colour was mapped by the ward's `--fix` to the nearest house role: a dark ground to stone, a blue-grey to
bone, blue to bronze, violet to steel, magenta to blood. Then the hand checked the places where colours must stay apart:

- Hlidskjalf's terminal palette, its accent presets (ids kept, now named Bronze, Hearth, Steel, Blood, Bone, Worn bone)
  and its background presets (Peat, Dried blood, Iron);
- Smíðja's agent lanes (planner steel, builder bronze, documenter bone, orchestrator ember);
- Sessrúmnir's model-dot series and Bilskirnir's box terminal palette;
- the words around the hex in `docs/design.md`, `docs/lore.md`, `docs/ymir-rut.md`, Sessrúmnir's `NOTICE`, and the
  Zed-theme guide (which now names the Aetheria theme's cool values instead of quoting them).

The steel banners (01, 04, 05, 06) were recoloured whole with a five-stop duotone (stone → line → bronze-deep → bronze →
bone). The parchment banners (02, 03) had only their blue glow recoloured, through a hue mask.
`apps/hlidskjalf/public/ymir-icon.png` measured 0 % cool pixels already and was left alone.

## Proof

- `house-colour-guard.sh` on the whole tree: clean except the held areas, which it names.
- `house-colour-guard.sh --self-test`: 4 of 4. A planted blue is refused in five spellings, the cloth and an issue
  number pass, a held path is named, and the map lands clean.
- Cool-pixel share by the ward's own band, before → after: banner-01 58.6 % → 0, 02 20.3 % → 0, 03 0.07 % → 0,
  04 59.2 % → 0, 05 72.8 % → 0, 06 77.0 % → 0.
- Before and after screenshots from Chromium (DevTools protocol) of Hlidskjalf, Smíðja, Bilskirnir, the emblems, the
  stave, the mail templates and the reference pages, attached to the pull request.

## Not done

> [!IMPORTANT]
> Held for the Allfather's word: `docs/fixes/**` (append-only records, 6 colours in 5 notes) and Sessrúmnir's user
> themes `nord`, `breeze-dark`, `breeze-light`, `breeze-claudius`, `dark`, `light` (114 colours).

- The token **names** `--ymir-cyan-*` and `--ymir-violet-*` still say cyan and violet, though their values are bronze
  and steel. Renaming them touches every app and is its own change.
- Colours stored in **data**, not code, are not judged: Smíðja's database keeps the lane colour each past run was given
  (a past builder lane still shows cyan until it runs again).
- Near-black navy below 6 % lightness (such as `#080c14`) is not judged by design; it reads as black.
- The Google mark on Bilskirnir's sign-in was mapped like everything else; its blue quarter is now bronze.

## CHANGE LOG

- **2026-11-12** — Written with the change (heimdall, Eindri `no-blue-no-purple`).
