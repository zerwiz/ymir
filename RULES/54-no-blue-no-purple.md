# 54 — No blue and no purple

Written 2026-11-12 at the Allfather's word:

> *"we should never have blue … Blue and purple, those ones must go away. They should not exist in this repo at all.
> They need to be converted to the right colors."*

**Status:** law. The ward is `bin/gates/guards/house-colour-guard.sh`, and it runs in the pre-push wards and in CI.

**In three sentences.** The house wears stone, bone, bronze, steel and blood, and nothing else. A blue or purple colour
anywhere in this repository is refused by the ward, which names the file, the line, and the house colour it becomes.
Two areas are held until the Allfather rules on them, and the ward names them on every run so they are never forgotten.

## The law

Every colour in this repository is a house colour. The palette lives in one file,
`midgard/design-system/tokens.css`, and `docs/house-cloth.md` shows how an application wears it.

A colour is **blue or purple** when all three of these hold:

| Test | Value | Why |
|---|---|---|
| Hue | 185° to 330° | from cyan-blue, through blue, indigo and violet, to magenta |
| HSL saturation | at least 15 % | so steel (`#96a0a8`, 9 %) and other greys are not judged |
| Lightness | between 6 % and 94 % | so near-black and near-white are not judged |

The ward reads a colour in four spellings: hex (`#36f`, `#3366ff`, `#3366ffcc`), the `rgb()`, `rgba()`, `hsl()` and
`hsla()` functions, a Tailwind class in the `blue`, `indigo`, `violet`, `purple`, `sky` or `fuchsia` families, and a cool
CSS colour name such as `navy` or `violet` written as a colour value.

## How a cool colour is mapped

A cool colour is never swapped for another cool colour. It goes to the nearest **house role**, by what it was doing:

| What it was | Becomes | House colours |
|---|---|---|
| a dark ground (lightness under 20 %) | the stone ladder | `#0e0c09` `#151209` `#1a1610` `#221d14` `#2b241a` |
| a blue-grey, such as slate (saturation under 35 %) | the bone ladder | `#2b241a` `#6b6250` `#9a8f75` `#cfc3a9` `#f0e6cd` |
| blue, sky or indigo — usually the accent | the bronze ramp | `#57411a` `#7d5f2a` `#c9973f` `#eca654` `#f0e6cd` |
| violet or purple — usually the second accent | the steel ramp | `#2b241a` `#5f686e` `#96a0a8` `#cfc3a9` `#f0e6cd` |
| fuchsia or magenta | the blood ramp | `#7c3a30` `#c2584a` `#cfc3a9` `#f0e6cd` |

The step is chosen by lightness, and the alpha is kept. Tailwind classes move family and keep their shade: blue, sky and
indigo become `amber`, violet and purple become `stone`, fuchsia becomes `red`.

The map is a starting point, not the end. Where colours must stay **apart** — a terminal's sixteen colours, a chart's
series, an agent's lane — the hand checks that the mapped colours are still distinct and picks other house steps if not.

## Pictures

The ward reads text, not pixels. A blue picture is recoloured by hand into the cloth: a duotone map from stone through
bronze to bone keeps its light and shape. Where only part of a picture glows blue, only that part is recoloured. The
before and after are shown to the Allfather before the original leaves the tree; git history keeps it.

## What is held, and why

> [!IMPORTANT]
> Two areas are **held** for the Allfather's word. They are listed in `house-colour.allow` as `held`, and the ward
> prints every colour in them on every run.

- **`docs/fixes/**`** — fix notes are append-only records (Rule 06). A correction is a new note, never a rewrite of an old
  one, so a blue hex quoted in a note of September stays as it was written.
- **Sessrúmnir's user themes** (Nord, Breeze and the upstream dark and light) — a user chooses them, and they are blue by
  design. The house's own themes, `fensalir` and `sessrumnir`, are in the cloth.

`house-colour.allow` also names **fixtures** (Sessrúmnir's theme-engine tests, which must prove they can read a blue user
theme) and **specimens** (this rule and its ward, which must name what they refuse). A line there that matches no file
is itself a finding.

## How it is kept

```bash
bash bin/gates/guards/house-colour-guard.sh                 # the whole tree
bash bin/gates/guards/house-colour-guard.sh path/a.css …    # just these files
bash bin/gates/guards/house-colour-guard.sh --map '#3b82f6' # what one colour becomes
bash bin/gates/guards/house-colour-guard.sh --fix path/a.css …   # apply the map
bash bin/gates/guards/house-colour-guard.sh --self-test     # prove the ward can fail
```

The pre-push wards run it on the files a push changed (`bin/gates/guards.sh`), and CI runs it on the whole tree.

## CHANGE LOG

- **2026-11-12** — Written at the Allfather's word, with the ward, and with the sweep of 503 colours in 81 files and six
  banners (fix note `docs/fixes/gates/2026-11-12-no-blue-no-purple.md`).
