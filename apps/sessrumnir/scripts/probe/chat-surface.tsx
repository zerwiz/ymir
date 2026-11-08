/**
 * The page the width probe renders: the real `ChatPanel`, in a real browser,
 * over a real stylesheet.
 *
 * Nothing about the component tree is re-drawn here — the probe mounts the
 * shipping panel, so a measurement is a statement about the app and not about a
 * copy of it. Only the edges are staged:
 *
 *   · the engine (Pi/OMP) is absent, so `window.piDesktop` is a quiet stub and
 *     no session is started;
 *   · the messages are `fixtures.ts`, chosen to carry the two things that set a
 *     width floor (an unbreakable token, a code block);
 *   · `?pane=<px>` pins the panel to that many pixels inside a wider window,
 *     which is how a 400-pixel chat in a 1400-pixel window is measured at all.
 *
 * The runner (`scripts/probe-chat-widths.mjs`) builds this entry with esbuild and
 * drives it once per width in headless Chromium.
 */
import { createElement } from 'react'
import { createRoot } from 'react-dom/client'
import { I18nextProvider } from 'react-i18next'
import { ChatPanel } from '../../src/renderer/src/components/chat-panel'
import { useAppStore } from '../../src/renderer/src/store'
import { i18n } from '../../src/shared/i18n'
import { PROBE_MESSAGES } from './fixtures'

// The same faces the shipping window bundles (main.tsx), so the probe wraps
// text the way the app does rather than in a fallback serif.
import '@fontsource-variable/inter'
import '@fontsource-variable/jetbrains-mono'
import '@fontsource/cormorant/400.css'
import '@fontsource-variable/newsreader'
import '@fontsource/ibm-plex-mono/400.css'

const params = new URLSearchParams(window.location.search)
const pane = Number(params.get('pane') ?? '') || 0
const panel = params.get('panel')

const root = document.getElementById('probe-root')
if (!root) throw new Error('probe-root missing')

// A pane narrower than the window: the app is split into panes, and this is how
// a narrow chat inside a wide window is measured without resizing the window.
if (pane > 0) {
  root.style.width = `${pane}px`
  root.dataset.pane = String(pane)
}

useAppStore.setState({
  messages: PROBE_MESSAGES,
  currentView: 'chat',
  sidebarOpen: false,
  chatSidePanel: panel === 'files' ? 'files' : panel === 'diff' ? 'diff' : null,
})

createRoot(root).render(
  createElement(I18nextProvider, { i18n }, createElement(ChatPanel))
)
