## gate · unversioned · 2026-11-14 — Dependabot opened six PRs at once, four of them majors — a major is never merge-ready

### Why
the first run of the weekly config (merged in #733) opened #734 and #736-#740 at once: capacitor 6 to 8, typescript 5 to 7, electron-vite 3 to 6, xterm 5 to 6, plus electron itself. A major changes an API, a build or a platform floor and earns its own errand and real-window test; and Electron is pinned exactly (43.8.9, no range) in every app because the shell is the window the house is. So every ecosystem now ignores semver-major, electron is ignored entirely, and the grouped minor/patch PR stays weekly. Security updates are not silenced: an advisory still arrives and a person handles it.

### Files
- `.github/dependabot.yml`
### What
`.github/dependabot.yml` gained two `ignore` rules per ecosystem, each with its reason in the file:

- `dependency-name: "*"` + `update-types: ["version-update:semver-major"]` — no major, in npm and in pip.
- `dependency-name: "electron"` (no update-types) — every version, because the apps pin `"electron": "43.8.9"`
  exactly and the shell is the window the house is.

The grouped `*-minor-and-patch` PR stays weekly on Monday, and the two `*-security` groups are untouched.

### Verified
The file parses (YAML), and the effective rules read back: npm → ignore `*` semver-major, ignore `electron`; pip →
ignore `*` semver-major. The six PRs the first run opened (#734, #736–#740) were left alone, as briefed: closing
another hand's PR is not this errand's business, and the maintainer decides what to do with the majors already
open. The effect is proved on the next Monday run (or by Dependabot's own config validation on this PR).

### Note
`ignore` slows chores, never a security answer: a security advisory still arrives through Dependabot's security
updates, majors included, and a person handles it.
