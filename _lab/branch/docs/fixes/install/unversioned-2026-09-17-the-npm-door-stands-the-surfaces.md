## install · unversioned · 2026-09-17 — the npm door stands the surfaces

### Why
- **`@zerwiz/ymir` now depends on its surfaces**: `@zerwiz/{hlidskjalf,
  odrerir, sessrumnir, smidja-factory}` are declared dependencies (bump
  `0.1.14` → `0.1.15`), so `npm i -g @zerwiz/ymir` (or a packaged install)
  delivers the app shells under `node_modules/@zerwiz/*`, which `app-lib`
  resolves. The audit's one gap — the platform carried no apps — is closed.
- **`@zerwiz/smidja-factory` `0.1.1` → `0.1.2`**: the visualizer's nanoid fix
  and the eye's-home SKILL line reach npm.

### Files
- *(carried from the frozen CHANGELOG.md)*
