## sessrumnir · unversioned · 2026-09-17 — the hearth re-seeds on its container: Sessrúmnir's chat fire returns

### Why
- **The ember glow was gone from the chat because the canvas sized itself once
  at mount and only re-seeded on `window.resize`.** Sessrúmnir's split panes
  (file tree · editor · image) resize the chat column without any window resize,
  so the hearth kept a stale or zero-sized canvas — invisible. Both the shared
  hearth (`midgard/design-system/ember.js`) and Sessrúmnir's React port
  (`ember-background.tsx`) now watch their container with a ResizeObserver and
  re-seed only when the measured size actually changes (never per-frame).
  Hlidskjalf inherits the same mend through the shared module.
- **Verified live**: Sessrúmnir restarted on the fresh build; a screen capture
  of the running window shows the fire drawing (ember + warm-glow pixels across
  the hearth area). The running app had been serving a stale bundle (missing
  `react-i18next` — deps installed, rebuilt).

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` — the
EmberBackground hearth section (shared module + ResizeObserver mend).

# CHANGELOG

### Files
- *(carried from the frozen CHANGELOG.md)*
