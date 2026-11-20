import type { ThemeFile } from '../../../shared/theme/theme-file'
import { t } from '../../../shared/i18n'
import { BUILTIN_THEME_IDS as SHARED_BUILTIN_THEME_IDS } from '../../../shared/theme/builtin-ids'
import dark from './dark.json'
import light from './light.json'
import nord from './nord.json'
import gruvbox from './gruvbox.json'
import breezeDark from './breeze-dark.json'
import breezeLight from './breeze-light.json'
import breezeClaudius from './breeze-claudius.json'
import sessrumnir from './sessrumnir.json'
import fensalir from './fensalir.json'

export const BUILTIN_THEMES: ReadonlyArray<{ id: string; file: ThemeFile }> = [
  { id: 'sessrumnir', file: sessrumnir as ThemeFile },
  { id: 'fensalir', file: fensalir as ThemeFile },
  { id: 'dark', file: dark as ThemeFile },
  { id: 'light', file: light as ThemeFile },
  { id: 'nord', file: nord as ThemeFile },
  { id: 'gruvbox', file: gruvbox as ThemeFile },
  { id: 'breeze-dark', file: breezeDark as ThemeFile },
  { id: 'breeze-light', file: breezeLight as ThemeFile },
  { id: 'breeze-claudius', file: breezeClaudius as ThemeFile },
]

export const BUILTIN_THEME_IDS: readonly string[] = BUILTIN_THEMES.map((t) => t.id)

type BuiltinThemeId = (typeof SHARED_BUILTIN_THEME_IDS)[number]

function isBuiltinThemeId(id: string): id is BuiltinThemeId {
  return (SHARED_BUILTIN_THEME_IDS as readonly string[]).includes(id)
}

// `id` here is a plain `string` narrowed to `BuiltinThemeId` only inside the
// `isBuiltinThemeId` type-guard call below, not a directly union-typed
// parameter — the extractor's static analysis cannot follow that narrowing
// through a template literal (`themes.builtin.${id}`) and deletes the keys
// as unused (verified: a direct union-typed parameter, as in
// permission-mode.ts's `getPermissionModeLabel`, extracts fine). An explicit
// key per id keeps them extractable and typo-checked by tsc.
const BUILTIN_THEME_NAME_KEYS = {
  dark: 'themes.builtin.dark',
  light: 'themes.builtin.light',
  nord: 'themes.builtin.nord',
  gruvbox: 'themes.builtin.gruvbox',
  'breeze-dark': 'themes.builtin.breeze-dark',
  'breeze-light': 'themes.builtin.breeze-light',
  'breeze-claudius': 'themes.builtin.breeze-claudius',
  sessrumnir: 'themes.builtin.sessrumnir',
  fensalir: 'themes.builtin.fensalir',
} as const

/** Built-in themes show a translated name; user and gallery themes keep their own. */
export function themeDisplayName(id: string, fileName: string): string {
  if (!isBuiltinThemeId(id)) return fileName
  const themeId: BuiltinThemeId = id
  type ThemeNameKey = typeof BUILTIN_THEME_NAME_KEYS[BuiltinThemeId]
  const key: ThemeNameKey = BUILTIN_THEME_NAME_KEYS[themeId]
  return t(key)
}
