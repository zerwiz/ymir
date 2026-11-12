# The house cloth — one fire, one palette, and how every surface wears it

This is the design system's own page: what the cloth is, what it is made of, and — as of the audit of
2026-11-11 — **how well each application actually wears it**. It exists because the answers were spread
across fix notes and one stylesheet, and a design system nobody can read is one that drifts.

```
files[6]{file,what it is,who uses it}:
  "tokens.css","THE CLOTH: `--ymir-bg-0..3` (stone · panel · panel2 · line-soft), `--ymir-cyan-1/2` (bronze — accent, active, focus, links), `--ymir-violet-1/2` (steel — realm identity, secondary), plus space, radius and type sizes","every web surface; imported, never copied"
  "ember.js + ember.d.ts","THE HEARTH: embers rising with a sway over drifting haze. Framework-neutral, `pointer-events: none`, `aria-hidden`, and it honours `prefers-reduced-motion`. The original came from Sessrúmnir's chat","every surface; `import { startEmbers }` or mark `<canvas data-ember>`"
  "icons/ + icons.md","the house icon set and how to choose one","every surface"
  "runes.md","the rune marks and their meanings","where a mark is needed"
  "ymir-mark.svg","the mark itself","the mark"
  "this file","the cloth's own record","whoever dresses a surface next"
```

## The two layers — identity, then overlay

```
layers[2]{layer,is,rule}:
  "the HOUSE","bronze on stone, steel for realm identity — the values in `tokens.css`","this is Ymir's identity. It is the default everywhere, always, and never silently replaced"
  "the MACHINE","the desktop's active Omarchy theme, readable as `omarchy theme current --print-name` → `~/.config/omarchy/themes/<slug>/colors.toml` (accent, cursor, foreground, background, selection, color0…15)","an OPT-IN overlay only. A surface that wants to follow the machine offers a named setting (`house` | `theme`), default `house`"
```

**Why the default is the house and not the machine.** On this box, right now, the active desktop theme is
**Matte Black** while the cloth is bronze-on-stone. A surface that silently adopted the desktop palette would
stop looking like Ymir the moment the desktop theme changed — and nobody would notice until it was in a
screenshot. Theme-following is therefore a switch a person flips, not a behaviour a stylesheet inherits.

## The audit — 2026-11-11, measured on this tree

"tokens" = does the app import `tokens.css`; "ember" = does it use the hearth; "raw hex" = distinct
hard-coded colours in the app's own styles.

| surface | tokens | ember | raw hex | verdict |
|---|---|---|---|---|
| `apps/hlidskjalf` | yes | **twice** (`src/app/EmberBackground.tsx`, 14 lines; `src/components/EmberBackground.tsx`, 36 lines — different files, one fire) | — | in the system, with a copy of the hearth |
| `apps/odrerir` | yes (`hall.css`) | yes | 37 | in the system, some local colour |
| `apps/rodd` | yes (2 files) | yes | **507** | worst: `ui/house.css` *restates* the cloth by hand (`--bg:#0e0c09` **is** `--ymir-bg-0`) |
| `apps/sessrumnir` | no | yes | 34 | the fire without the cloth — and it carries its **own theme store** (`src/main/theme-store.ts`, `themes/<slug>/theme.json`) |
| `apps/hvergelmir` | no | no | 21 | outside entirely |
| `apps/smidja` | — | — | — | a Python backend, no CSS surface — a clean skip |
| `apps/smidja-factory/apps/visualizer` | no | no | — | a separate bun build; an outsider by construction, not by neglect |

**Six degrees of adherence from one system.** And the plain fact the audit established: **no application on
this machine reads the live desktop theme at all** — the only theme reader in the tree is Sessrúmnir's own
`theme-store.ts`, which manages its own theme files and is unrelated to `tokens.css`. "Follow the machine's
theme" was, until this page, a sentence rather than a behaviour.

## The three forms of drift, and the mend

```
drift[3]{form,example,mend}:
  "the copy","two EmberBackground components in one app","one component, imported; the second deleted (a move, recorded in a fix note)"
  "the restatement","Rödd's 507 hexes and its hand-written `--bg:#0e0c09`","Rödd imports the tokens and declares only what they cannot express; `house.css` becomes a mapping, not a palette"
  "the outsider","sessrumnir, the visualiser — the fire without the cloth, or neither","each surface either imports `tokens.css` in one line or says in its own README why it must not"
```

**One guard, not six repairs.** `bin/gates/guards/house-look-guard.sh` (plan 259, B2b/B2d) reports per app:
does it import `tokens.css`, and how many raw hexes does it carry. A number per app that can go down, printed
where a push can see it — instead of a look that drifts in the dark. The outsiders are listed with their
reasons, never silently passed.

## The resolver that makes the overlay real

```
resolver[1]{door,does}:
  "bin/desktop/theme-colors.sh [--json|--css]","asks `omarchy theme current --print-name`, reads that theme's `colors.toml`, and emits the palette; with no omarchy or no theme it prints a clean skip and its reason (RULES/25), never a guess"
```

A surface that opts in applies the resolver's output as a **layer over** the tokens: the house keeps
`--ymir-*`, the overlay supplies the machine's accent and ground, and the setting that chooses between them
is visible in the surface's own settings — never inferred.

## The rule for the next surface

1. Import `midgard/design-system/tokens.css`. Do not copy a hex out of it.
2. Use the hearth (`ember.js`) rather than writing a third fire.
3. Take icons from `icons/`, marks from `runes.md`, the mark from `ymir-mark.svg`.
4. If you want the machine's theme, add the setting and use the resolver — default `house`.
5. Run `bin/gates/guards/house-look-guard.sh`; if your raw-hex count is not zero, say why in your README.

**The cloth is a single file and a single fire; everything else is an opinion about them.**

## CHANGE LOG

- **2026-11-11** — Written, after he asked whether the other apps' UI and their use of the Ember had ever
  been audited. They had not. This page carries the audit (six degrees of adherence, and the fact that no
  app reads the live desktop theme), the two-layer rule (house identity in `tokens.css`, the machine's
  theme as an opt-in overlay), the three forms of drift, the per-app guard, and the five-line rule for the
  next surface.
