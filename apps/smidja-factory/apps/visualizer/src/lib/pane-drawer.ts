/**
 * Which pane the board is showing, if any — one place, so every "look" opens the
 * same drawer. A module-level ref rather than a store: it holds one value, and
 * the components that need it are the two strips and the drawer itself.
 */
import { ref } from 'vue'

export interface OpenPane {
  pane: string
  name?: string
  cwd?: string
}

export const openPaneRef = ref<OpenPane | null>(null)

export function openPane(pane: OpenPane): void {
  openPaneRef.value = pane
}

export function closePane(): void {
  openPaneRef.value = null
}
