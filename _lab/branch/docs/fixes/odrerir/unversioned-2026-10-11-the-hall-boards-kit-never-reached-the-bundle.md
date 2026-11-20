## odrerir · unversioned · 2026-10-11 — the hall board's own kit never reached the bundle (the @import sat last)

Ticket: **odrerir/1** (the hall's UI, Phase 1 diagnosis).

### Why

`apps/odrerir/src/hall.css` ended with:

```css
/* the ORIGINAL hall board kit, scoped to #livehall (2026-09-24: never simplify) */
@import "./hall/lh-scoped.css";
```

CSS requires `@import` to precede every other statement. PostCSS said so at build time
and **dropped the import**:

```
[vite:css][postcss] @import must precede all other statements (besides @charset or empty @layer)
548|  @import "./hall/lh-scoped.css";
```

So `src/hall/lh-scoped.css` — 108 lines of `#livehall` rules, the original board's kit
carried over under the never-simplify law — **never reached the output**. The board's
markup was injected as designed and styled by nothing. Measured before the fix:

```
built css: 11,021 bytes · "#livehall" occurrences: 0
```

### What

The kit is now imported **by JS** (`src/main.tsx`, right after `./hall.css`), which is how
Vite is meant to order stylesheets. The CSS `@import` is removed, with the reason left in
its place so nobody re-adds it.

Importing it *after* `hall.css` keeps the author's intended cascade: the scoped kit was
placed last on purpose, so it must win where the two overlap.

### Verified

Same command, same machine, before and after:

```
before: index-Cjpl4Kd4.css   11,021 bytes   "#livehall": 0      + postcss warning
after:  index-DqYl_2qo.css   33,627 bytes   "#livehall": 199    no warning
(then: ✓ 41 modules transformed — was 40)
```

`tsc --noEmit && vite build` clean both before and after: the site built **successfully**
while the board was unstyled, which is why this survived — a build that passes is not a
hall that works.

### Files

- `apps/odrerir/src/hall.css` — the misplaced `@import` replaced by the reason it must not return
- `apps/odrerir/src/main.tsx` — the kit imported by JS, after `hall.css`
- `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md` — dated note
