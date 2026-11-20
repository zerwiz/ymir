// The built-in theme ids, frozen since the token system's first task.
// These are also persisted in users' settings.json, so this list must never
// change without a migration. Both the renderer's theme registry
// (src/renderer/src/themes/index.ts) and the main process's user-theme store
// (src/main/theme-store.ts) must agree on this exact set — the renderer is
// the source of the actual theme files, but the main process cannot import
// those (separate process/bundle), so this module is the single shared
// source of truth for just the id strings.
//
// `fensalir` was appended when the carved cloth of the halls arrived: the last
// entry is new, every id before it is unchanged, and a new id is additive —
// old settings keep resolving, new ones may select it. Never reorder, rename
// or drop an id here; only ever append.
export const BUILTIN_THEME_IDS = [
  'sessrumnir', 'fensalir', 'dark', 'light', 'nord', 'gruvbox', 'breeze-dark', 'breeze-light', 'breeze-claudius',
] as const
