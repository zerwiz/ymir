## hlidskjalf · unversioned · 2026-09-17 — 0.1.14: the panels reach the gate, and the fourth window ships

### Why
- **`@zerwiz/hlidskjalf` 0.1.1** — the package now declares its own `name`, `files` and the absence of `private`, and ships **`vite.config.ts`**. Without that config a packaged SPA is served by `vite preview` with **no `/api` proxy**, so every panel answered `index.html` and died on `Unexpected token '<'<`. That was the whole panel fault.
- **`@zerwiz/odrerir` 0.1.1** — ships its **`electron/`** half, so the fourth hall can have a window; its name is `@zerwiz/odrerir` and it is no longer marked private (npm refuses those, EPRIVATE).
- Both apps declared what ships **in their own repos**, instead of a manifest rewritten at publish time — which is how the wrong things shipped in the first place.

### Files
- *(carried from the frozen CHANGELOG.md)*
