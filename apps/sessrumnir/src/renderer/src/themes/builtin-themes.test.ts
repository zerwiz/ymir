import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readdirSync, readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { validateThemeFile } from '../../../shared/theme/theme-file'
import { resolveThemeVars } from '../../../shared/theme/resolve'
import { TOKEN_NAMES, cssVarForToken } from '../../../shared/theme/tokens'
import { BUILTIN_THEME_IDS } from './index'
import { BUILTIN_THEME_IDS as SHARED_BUILTIN_THEME_IDS } from '../../../shared/theme/builtin-ids'

const themesDir = dirname(fileURLToPath(import.meta.url))
const EXPECTED_IDS = [
  'sessrumnir', 'fensalir', 'dark', 'light', 'nord', 'gruvbox', 'breeze-dark', 'breeze-light', 'breeze-claudius',
]

test('renderer and shared built-in theme id lists never diverge', () => {
  assert.deepEqual(
    new Set(BUILTIN_THEME_IDS),
    new Set(SHARED_BUILTIN_THEME_IDS),
  )
})

test('all 9 built-in themes exist, validate, and fully resolve', () => {
  const files = readdirSync(themesDir).filter((f) => f.endsWith('.json')).sort()
  assert.deepEqual(files, [...EXPECTED_IDS].sort().map((id) => `${id}.json`))
  for (const file of files) {
    const theme = validateThemeFile(JSON.parse(readFileSync(join(themesDir, file), 'utf8')))
    const vars = resolveThemeVars(theme)
    for (const token of TOKEN_NAMES) {
      assert.ok(vars[cssVarForToken(token)], `${file}: unresolved ${token}`)
    }
  }
})

test('ported themes pin every token in overrides (parity guarantee)', () => {
  for (const id of EXPECTED_IDS) {
    if (id === 'dark' || id === 'light') continue
    const theme = validateThemeFile(
      JSON.parse(readFileSync(join(themesDir, `${id}.json`), 'utf8')),
    )
    const seedBacked = new Set(['app', 'surface', 'primary', 'accent', 'success', 'warning', 'error'])
    // error-hover and border-strong-hover have no legacy CSS counterpart to
    // reproduce (no theme ever remapped the red-500/600 or neutral-600 shades),
    // so they derive via MIX(..., 15) / MIX(..., 35) instead of pinning the
    // raw value that would carry the theme-blind bug forward. selection-bg and
    // selection-fg are the same case: a ported theme's selection should follow
    // that theme's own accent (the cloth themes pin the landing's amber).
    const derivedOnly = new Set([
      'error-hover', 'border-strong-hover', 'selection-bg', 'selection-fg',
    ])
    for (const token of TOKEN_NAMES) {
      if (seedBacked.has(token) || derivedOnly.has(token)) continue
      assert.ok(theme.overrides?.[token], `${id}: token ${token} not pinned`)
    }
  }
})

// The cloth is one. `sessrumnir` (the seat's own default) and `fensalir` (the
// weaving halls, named) are the same carved palette: the seat cannot drift from
// the halls, and a name/description change is the only difference permitted.
test('the cloth is one: Sessrúmnir and Fensalir resolve identically', () => {
  const read = (id: string) =>
    resolveThemeVars(validateThemeFile(
      JSON.parse(readFileSync(join(themesDir, `${id}.json`), 'utf8')),
    ))
  assert.deepEqual(read('sessrumnir'), read('fensalir'))
})

// The CSS base in index.css is the first paint (before the ThemeEngine writes
// the resolved vars onto <html>) and the Tailwind `@theme` surface. It must be
// the same cloth as the theme file, or the app would flash one palette and
// settle into another.
test('the CSS @theme base and the cloth theme never drift', () => {
  const css = readFileSync(join(themesDir, '..', 'index.css'), 'utf8')
  const block = /@theme\s*\{([\s\S]*?)\n\}/.exec(css)
  assert.ok(block, 'index.css has no @theme block')
  const declared = new Map<string, string>()
  for (const line of block[1].split('\n')) {
    const match = /^\s*(--color-[a-z-]+)\s*:\s*([^;]+);/.exec(line)
    if (match) declared.set(match[1], match[2].trim())
  }
  const cloth = resolveThemeVars(validateThemeFile(
    JSON.parse(readFileSync(join(themesDir, 'fensalir.json'), 'utf8')),
  ))
  for (const token of TOKEN_NAMES) {
    const key = cssVarForToken(token)
    assert.equal(declared.get(key), cloth[key], `@theme ${key} drifted from the cloth`)
  }
})
