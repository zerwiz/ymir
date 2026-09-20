## sessrumnir · unversioned · 2026-09-19 — the seat stops wearing the fork's name (plan 35 folds it in)

### Why
- `apps/sessrumnir` carried "Pi Desktop" in 25 files and a `scripts/postinstall.js` whose
  job was to install a *Pi Desktop* launcher — so every install re-planted the fork's
  identity. All 25 renamed; the postinstall deleted and unwired from `package.json`.
- `appId: com.zerwiz.sessrumnir` set — with no appId the window class matches nothing and
  the dock cannot find the icon, which is why the glyph was in the theme and never used.
- Verified: **0 files** under `apps/sessrumnir` still name the fork.

### Files
- `package.json`
- `scripts/postinstall.js`
