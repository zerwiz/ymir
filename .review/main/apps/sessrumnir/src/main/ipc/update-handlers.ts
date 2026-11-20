import { ipcMain, app } from 'electron'
import type { UpdateCheckResult } from '../../shared/ipc-contracts'
import { IPC_CHANNELS } from '../../shared/ipc-contracts'
import { isNewerVersion } from '../../shared/version-compare'
import { appLog } from '../app-log'

// The update well is OUR OWN shelf, never the upstream we forked from.
// Sessrúmnir rides the folded single-repo (plan 39): it ships as the
// @zerwiz/sessrumnir npm package, so the app compares its version against the
// package's dist-tag — `next` while this build is a prerelease, `latest`
// once a stable line exists. A GitHub-releases check of the parent would
// advertise the parent's builds on a fork that no longer follows them.
const UPDATE_PACKAGE = '@zerwiz/sessrumnir'
const UPDATE_PACKAGE_URL = 'https://www.npmjs.com/package/@zerwiz/sessrumnir'
const NPM_REGISTRY_URL = 'https://registry.npmjs.org'
const UPDATE_CHECK_TIMEOUT_MS = 8000

/** The dist-tag this build follows: prereleases ride `next`, stable rides `latest`. */
function distTagFor(version: string): string {
  return version.includes('-') ? 'next' : 'latest'
}

/** The version a dist-tag resolves to, or null when the registry can't say. */
async function fetchTagVersion(tag: string): Promise<string | null> {
  // The registry expects a scoped name's slash encoded: `@scope%2fname`.
  const url = `${NPM_REGISTRY_URL}/${UPDATE_PACKAGE.replace('/', '%2f')}/${encodeURIComponent(tag)}`
  try {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), UPDATE_CHECK_TIMEOUT_MS)
    const res = await fetch(url, {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    })
    clearTimeout(timer)
    if (!res.ok) return null
    const manifest = (await res.json()) as { version?: unknown }
    return typeof manifest.version === 'string' ? manifest.version : null
  } catch (err) {
    appLog.warn('updates', 'Update check failed', err)
    return null
  }
}

/** Check our own npm package for a version newer than this build. */
async function checkForUpdate(): Promise<UpdateCheckResult> {
  const currentVersion = app.getVersion()
  const noUpdate: UpdateCheckResult = { updateAvailable: false, currentVersion, latestVersion: currentVersion, url: '' }

  const tag = distTagFor(currentVersion)
  const latestVersion = await fetchTagVersion(tag)
  if (!latestVersion) return noUpdate

  return {
    updateAvailable: isNewerVersion(latestVersion, currentVersion),
    currentVersion,
    latestVersion,
    url: UPDATE_PACKAGE_URL,
    name: `@zerwiz/sessrumnir`,
  }
}

export function registerUpdateHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.UPDATE_CHECK, async (): Promise<UpdateCheckResult> => {
    return checkForUpdate()
  })
}