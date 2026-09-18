## sessrumnir · unversioned · 2026-09-12 — The editor keeps its own seat

### Why
- **`open-editor.ts` seats the editor in Þjazi:** inside herdr, `/edit` and
  `ctrl+shift+e` now open the Allfather's editor in its **own tab** of the home
  workspace (`herdr tab create --focus` + `herdr pane run`, label
  `ymir:edit[:<base>]`, recorded in `state/herdr-seats` for `close-all`) instead
  of suspending the pi session — the agent no longer dies when the editor
  opens. Outside herdr the old roads remain: GUI editors launch detached,
  terminal editors suspend the TUI and resume on exit.
- **`open-editor.ts` shows hidden files:** the picker and `/edit`
  tab-completion now merge the git listing with a bounded walk, so gitignored
  dotfiles (`.env.local`, `.env.realm`, …) are openable too.

### Files
- *(carried from the frozen CHANGELOG.md)*
