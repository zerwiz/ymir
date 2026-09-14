/**
 * Pure-logic settings module — no Electron imports.
 *
 * Used by both the Electron main process (via ipc/settings.ts) and the
 * web server (src/web-server.ts). The Electron version registers IPC
 * handlers; the web server calls these functions directly.
 */

import { WorkspaceManager } from '../main/workspace-manager'
import { getGuiDataPath } from '../main/app-data-paths'
import type { AppSettings } from '../shared/ipc-contracts'
import { DEFAULT_SETTINGS } from '../shared/default-settings'
import { readFile, writeFile, mkdir } from 'fs/promises'
import { join } from 'path'
import { existsSync } from 'fs'

const SETTINGS_FILE_NAME = 'settings.json'

/** Also consumed by the diagnostics report. */
export function getSettingsPath(): string {
  return getGuiDataPath(SETTINGS_FILE_NAME)
}

export async function loadAppSettings(workspaceManager: WorkspaceManager): Promise<AppSettings> {
  try {
    const settingsPath = getSettingsPath()
    if (existsSync(settingsPath)) {
      const data = await readFile(settingsPath, 'utf-8')
      const merged = { ...DEFAULT_SETTINGS, ...JSON.parse(data) }
      if (merged.piEngine !== 'auto' && merged.piEngine !== 'pi' && merged.piEngine !== 'omp') {
        merged.piEngine = 'auto'
      }
      return merged
    }
  } catch {
    // Fall through to defaults
  }

  return {
    ...DEFAULT_SETTINGS,
    defaultCwd: workspaceManager.getActiveWorkspace()?.path ?? (process.env.HOME ?? process.env.USERPROFILE ?? process.cwd()),
  }
}

export async function saveAppSettings(settings: Partial<AppSettings>): Promise<void> {
  const settingsPath = getSettingsPath()
  const dir = join(settingsPath, '..')

  if (!existsSync(dir)) {
    await mkdir(dir, { recursive: true })
  }

  // Merge with existing
  let existing: AppSettings = { ...DEFAULT_SETTINGS }
  try {
    if (existsSync(settingsPath)) {
      const data = await readFile(settingsPath, 'utf-8')
      existing = { ...DEFAULT_SETTINGS, ...JSON.parse(data) }
    }
  } catch {
    // Use defaults
  }

  const merged = { ...existing, ...settings }
  try {
    await writeFile(settingsPath, JSON.stringify(merged, null, 2), 'utf-8')
  } catch (err) {
    throw err
  }
}
