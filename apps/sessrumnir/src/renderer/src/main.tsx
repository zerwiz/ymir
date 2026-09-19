import React from 'react'
import ReactDOM from 'react-dom/client'
import { I18nextProvider } from 'react-i18next'
import { App } from './app'
import { i18n } from '../../shared/i18n'
import { applyBootLanguage } from './i18n'
import '@fontsource-variable/inter'
import '@fontsource-variable/jetbrains-mono'
// The cloth's type — the landing page's own three families, bundled so the seat
// wears them with no network: Cormorant (display), Newsreader (body),
// IBM Plex Mono (mono). Inter/JetBrains Mono stay as glyph fallbacks.
import '@fontsource/cormorant/400.css'
import '@fontsource/cormorant/500.css'
import '@fontsource/cormorant/600.css'
import '@fontsource-variable/newsreader'
import '@fontsource-variable/newsreader/wght-italic.css'
import '@fontsource/ibm-plex-mono/300.css'
import '@fontsource/ibm-plex-mono/400.css'
import '@fontsource/ibm-plex-mono/500.css'
import './index.css'

// OpenMoji COLRv1 color emoji font (vendored woff2, @font-face in index.css) —
// sharp vector emoji that read better on dark than the OS emoji font. Preloaded
// eagerly so glyphs render in OpenMoji from the first paint.
void document.fonts?.load('16px "OpenMoji Color"').catch(() => {})

// Before the first render, so the first frame is already in the saved language.
applyBootLanguage()

const rootElement = document.getElementById('root')

if (!rootElement) {
  throw new Error('Root element not found')
}

ReactDOM.createRoot(rootElement).render(
  <React.StrictMode>
    <I18nextProvider i18n={i18n}>
      <App />
    </I18nextProvider>
  </React.StrictMode>
)
