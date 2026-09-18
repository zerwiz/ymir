## runtime · unversioned · 2026-09-16 — the hearth spreads: one fire, three more surfaces

### Why
Sessrúmnir's fire is now shared rather than copied. `midgard/design-system/ember.js`
is the framework-neutral original (the land page's Ginnungagap embers: 30 rising
with a gentle sway over six drifting haze pools), with `ember.d.ts` for TypeScript
consumers and a reader who asked for less motion gets a **still frame** instead of
an animation.

Wired, and built:

- **Hlidskjalf** — `src/components/EmberBackground.tsx` imports the shared module;
  mounted behind the *login* and behind the *shell*, so the door and the hall burn
  over one hearth.
- **Smíðja visualizer** — a `<canvas class="ember-bg">` behind every view.
- **Óðrerir** — a `data-ember` canvas in its shell, so the hall warms too.
- Sessrúmnir keeps its own React port untouched (two ports of one fire, the same
  physics; consolidating them on the shared module is the next tidy).

And the reference for the missing furniture: **Óðrerir already carries it all** —
four favicons, `mask-icon` in bronze, `site.webmanifest`, canonical, description,
theme-colour and Open Graph. The other apps should be brought up to *it*.

### Files
- *(carried from the frozen CHANGELOG.md)*
