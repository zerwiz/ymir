<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, hrefFor, hrefForMemory, hrefForDecisions, hrefForStats, hrefForChat, hrefForSettings, phaseCrumb } from './lib/router'
import SessionsList from './components/SessionsList.vue'
import SessionTrace from './components/SessionTrace.vue'
import MemoryView from './components/MemoryView.vue'
import DecisionsView from './components/DecisionsView.vue'
import StatsView from './components/StatsView.vue'
import ChatView from './components/ChatView.vue'
import SettingsView from './components/SettingsView.vue'

const route = useRoute()
const isMemory = computed(() => route.value.adwId === 'memory')
const isDecisions = computed(() => route.value.adwId === 'decisions')
const isStats = computed(() => route.value.adwId === 'stats')
const isChat = computed(() => route.value.adwId === 'chat')
const isSettings = computed(() => route.value.adwId === 'settings')

// The shared login, verified LIVE by the gate (server /api/auth forwards the
// browser cookie). We never read a file that *claims* a session — that is how a
// user looks logged in when they are not.
const auth = ref<{ authed: boolean; login: string | null }>({ authed: false, login: null })
const gateUrl = 'http://127.0.0.1:3889'
onMounted(async () => {
  try {
    auth.value = await (await fetch('/api/auth')).json()
  } catch {
    auth.value = { authed: false, login: null }
  }
})
const isMeta = computed(() => isMemory.value || isDecisions.value || isStats.value || isChat.value || isSettings.value)

// ── Theme toggle: fensalir (the carved cloth of the halls) is the default;
   //    data-theme="classic" preserves the OLD deep-space visualizer look
   //    (added 2026-09-01, G7 — nothing removed, the old styling is kept as an
   //    option). data-theme="high-contrast" adds a WCAG AAA compliant high
   //    contrast mode. Both are deliberate overrides and win when chosen.
   //    Choice is persisted locally; a saved "neutral" resolves to fensalir. ──
  const savedTheme = localStorage.getItem('smidja-theme')
  if (savedTheme === 'classic' || savedTheme === 'high-contrast') {
    document.documentElement.dataset.theme = savedTheme
  }
  const theme = ref<'fensalir' | 'classic' | 'high-contrast'>(
    (savedTheme === 'classic' || savedTheme === 'high-contrast') ? savedTheme : 'fensalir'
  )
  function toggleTheme() {
    const order: Array<'fensalir' | 'classic' | 'high-contrast'> = ['fensalir', 'classic', 'high-contrast']
    const idx = order.indexOf(theme.value)
    theme.value = order[(idx + 1) % order.length]
    if (theme.value === 'fensalir') {
      delete document.documentElement.dataset.theme
    } else {
      document.documentElement.dataset.theme = theme.value
    }
    localStorage.setItem('smidja-theme', theme.value)
  }

// Running inside the Electron shell? Then the native frame is hidden and the
// topbar doubles as the title bar — its right edge gets the window controls.
// Custom controls only appear on Linux; Windows/macOS draw native overlay
// buttons (which already sit on the right / follow the OS convention).
const isDesktop = (window as { smidjaDesktop?: { isDesktop?: boolean } }).smidjaDesktop?.isDesktop ?? false
const isLinuxDesktop = isDesktop && (window as { smidjaDesktop?: { platform?: string } }).smidjaDesktop?.platform === 'linux'
function winControl(action: 'minimize' | 'maximize' | 'close') {
  ;(window as { smidjaDesktop?: { windowControl?: (a: string) => void } }).smidjaDesktop?.windowControl?.(action)
}

/**
 * Raise the other app (or start it), through this API's /api/desktop route.
 * Silent on failure: a convenience control must never break the view it sits in.
 */
async function raiseApp(view: 'hlidskjalf' | 'smidja' | 'sessrumnir') {
  try {
    await fetch('/api/desktop', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ view }),
    })
  } catch {
    /* the launcher is unreachable — say nothing, change nothing */
  }
}

/**
 * The Óðrerir Live Hall — the landing's live board, a page of its own rather
 * than one of the three apps the gate raises. On this machine the hall answers
 * on :4322; anywhere else, the public hall.
 */
const host = window.location.host
const hallUrl =
  host.startsWith('localhost') || host.startsWith('127.0.0.1')
    ? 'http://localhost:4322'
    : 'https://hall.ymir.zerwiz.org'
</script>

<template>
  <div class="app">
    <a href="#main-content" class="skip-link">Skip to main content</a>
    <header class="topbar">
      <nav class="crumbs">
        <!-- Inline copy of public/logo.svg (the favicon) so the mark renders
             crisply with no fetch; keep the two in sync. -->
        <svg class="logo" viewBox="0 0 32 32" aria-hidden="true">
          <rect x="1" y="1" width="30" height="30" rx="7" fill="#0f172a" stroke="#1e293b" stroke-width="1" />
          <g fill="#38bdf8">
            <polygon points="7,6 10,6 16,11.5 22,6 25,6 17.5,13 17.5,20 14.5,20 14.5,13" />
            <polygon points="6,21 26,21 25.4,24 6.6,24" />
            <polygon points="8,25 24,25 23.3,27.5 8.7,27.5" />
          </g>
        </svg>
        <span class="brand">Smíðja</span>
        <span class="sep">›</span>
        <a :href="hrefFor()" :class="{ current: !route.adwId }">sessions</a>
        <span class="sep">›</span>
        <a :href="hrefForMemory()" :class="{ current: isMemory }">memory</a>
        <span class="sep">›</span>
        <a :href="hrefForDecisions()" :class="{ current: isDecisions }">decisions</a>
        <span class="sep">›</span>
        <a :href="hrefForStats()" :class="{ current: isStats }">stats</a>
        <span class="sep">›</span>
        <a :href="hrefForChat()" :class="{ current: isChat }">chat</a>
        <span class="sep">›</span>
        <a :href="hrefForSettings()" :class="{ current: isSettings }">settings</a>
        <template v-if="route.adwId && !isMeta">
          <span class="sep">›</span>
          <a :href="hrefFor(route.adwId)" :class="{ current: !route.phaseId }">{{
            route.adwId
          }}</a>
        </template>
        <template v-if="route.adwId && route.phaseId && !isMeta">
          <span class="sep">›</span>
          <span class="current">{{ phaseCrumb ?? route.phaseId }}</span>
        </template>
      </nav>
      <span class="live-hint"><span class="live-dot" /> live</span>
      <a v-if="auth.authed" :href="gateUrl" target="_blank" rel="noreferrer" title="Signed in to the gate" style="margin-right:6px;color:inherit;text-decoration:none;font-size:12px;opacity:.85">ᛉ {{ auth.login }}</a>
      <a v-else :href="gateUrl" target="_blank" rel="noreferrer" title="Sign in to Ymir" style="margin-right:6px;color:inherit;text-decoration:none;font-size:12px;opacity:.85">Sign in</a>
      <div role="group" aria-label="Switch hall" style="display:flex;gap:2px;margin-right:6px">
        <button type="button" title="Hlidskjalf — the control plane" aria-label="Open Hlidskjalf" @click="raiseApp('hlidskjalf')" style="background:transparent;border:none;color:inherit;cursor:pointer;font-size:15px;padding:2px 6px;border-radius:6px">ᚺ</button>
        <button type="button" class="on" aria-current="page" title="Smíðja — the smithy" style="background:transparent;border:none;color:var(--accent);cursor:default;font-size:15px;padding:2px 6px">ᛊ</button>
        <button type="button" title="Sessrúmnir — the seat-hall" aria-label="Open Sessrúmnir" @click="raiseApp('sessrumnir')" style="background:transparent;border:none;color:inherit;cursor:pointer;font-size:15px;padding:2px 6px;border-radius:6px">ᛋ</button>
      </div>
      <!-- The Óðrerir Live Hall — the landing's live board, a page of its own
           (the three apps above are raised through the gate; this one is a tab). -->
      <a
        class="hall-btn"
        :href="hallUrl"
        target="_blank"
        rel="noreferrer"
        title="The Óðrerir Live Hall — the landing's carved board"
      >ᛟ To the Hall</a>
      <button class="theme-toggle" type="button" :title="`Theme: ${theme === 'classic' ? 'classic deep-space' : theme === 'high-contrast' ? 'high contrast (WCAG AAA)' : 'fensalir — the carved cloth'} (click to switch)`" @click="toggleTheme">
        {{ theme === 'classic' ? 'classic' : theme === 'high-contrast' ? 'high-contrast' : 'fensalir' }}
      </button>
      <span v-if="isLinuxDesktop" class="win-controls">
        <button class="win-btn" title="Minimize" @click="winControl('minimize')" aria-label="Minimize">
          <svg viewBox="0 0 10 10" aria-hidden="true"><path d="M1 5.5h8" stroke="currentColor" stroke-width="1.2" fill="none" /></svg>
        </button>
        <button class="win-btn" title="Maximize" @click="winControl('maximize')" aria-label="Maximize">
          <svg viewBox="0 0 10 10" aria-hidden="true"><rect x="1.5" y="1.5" width="7" height="7" stroke="currentColor" stroke-width="1.2" fill="none" rx="1" /></svg>
        </button>
        <button class="win-btn win-close" title="Close" @click="winControl('close')" aria-label="Close">
          <svg viewBox="0 0 10 10" aria-hidden="true"><path d="M1.5 1.5l7 7M8.5 1.5l-7 7" stroke="currentColor" stroke-width="1.2" fill="none" /></svg>
        </button>
      </span>
      <!-- A speed-start from the UI: raise Hlidskjalf (or start it). The same
           launcher the Omarchy key bindings use, so there is one way in. -->
      <button class="win-btn" title="Open Hlidskjalf" aria-label="Open Hlidskjalf" @click="raiseApp('hlidskjalf')">
        <svg viewBox="0 0 10 10" aria-hidden="true"><path d="M1 8.5h8M2 8.5V3l3-2 3 2v5.5" stroke="currentColor" stroke-width="1.1" fill="none" /></svg>
      </button>
    </header>
    <main id="main-content">
      <StatsView v-if="isStats" />
      <DecisionsView v-else-if="isDecisions" />
      <MemoryView v-else-if="isMemory" />
      <ChatView v-else-if="isChat" />
      <SettingsView v-else-if="isSettings" />
      <SessionsList v-else-if="!route.adwId" />
      <SessionTrace v-else :key="route.adwId" :adw-id="route.adwId" :phase-id="route.phaseId" />
    </main>
  </div>
</template>

<style scoped>
.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 15px 28px;
  background: rgba(11, 15, 24, 0.72);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  position: sticky;
  top: 0;
  z-index: 10;
  /* In the desktop shell the native frame is hidden — this bar is the title
     bar, so the whole header drags the window. Ignored by browsers. */
  -webkit-app-region: drag;
  padding-right: 12px;
}

/* Gradient hairline instead of a hard border — the brand colors, whispered. */
.topbar::after {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 1px;
  background: linear-gradient(
    90deg,
    color-mix(in srgb, var(--accent) 40%, transparent),
    color-mix(in srgb, var(--accent) 30%, transparent) 40%,
    color-mix(in srgb, var(--accent) 6%, transparent)
  );
}

.crumbs {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 17px;
  min-width: 0;
}

.logo {
  width: 28px;
  height: 28px;
  flex: none;
  filter: drop-shadow(0 0 8px rgba(201, 151, 79, 0.3));
}

.brand {
  background: linear-gradient(90deg, var(--accent), var(--cyan));
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
  font-weight: 700;
  letter-spacing: 0.05em;
  white-space: nowrap;
}

.sep {
  color: var(--faint);
}

.crumbs a {
  color: var(--dim);
}

.crumbs a:hover {
  color: var(--text);
}

.crumbs .current {
  color: var(--text);
}

.live-hint {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: var(--dim);
  font-size: 16px;
  white-space: nowrap;
}

.live-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--green);
  box-shadow: 0 0 10px rgba(74, 222, 128, 0.7);
  animation: pulse 1.6s ease-in-out infinite;
}

/* Theme toggle — small pill in the topbar; opt out of the drag region. */
.theme-toggle {
  margin-left: 12px;
  flex: none;
  -webkit-app-region: no-drag;
  font-family: var(--mono);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 4px 10px;
  border-radius: 999px;
  border: 1px solid var(--border);
  background: var(--panel-2);
  color: var(--dim);
  cursor: pointer;
}
.theme-toggle:hover {
  color: var(--text);
  border-color: var(--border);
}

/* Clickable elements must opt out of the drag region or they can't be used. */
.crumbs a,
.live-hint,
.theme-toggle,
.hall-btn,
.win-controls {
  -webkit-app-region: no-drag;
}

/* The Hall door — a pill in the topbar, its own tab. The glyph is Othala, the
   ancestral hall; the accent keeps it legible in every theme. */
.hall-btn {
  margin-left: 12px;
  flex: none;
  font-family: var(--mono);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 4px 10px;
  border-radius: 999px;
  border: 1px solid var(--border);
  background: var(--panel-2);
  color: var(--accent);
  text-decoration: none;
  white-space: nowrap;
}
.hall-btn:hover {
  border-color: var(--accent);
  color: var(--text);
}
.hall-btn:active {
  transform: translateY(1px) scale(0.97);
}

/* Desktop window controls — right-aligned, dark, hover to close is red. */
.win-controls {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  margin-left: 14px;
  flex: none;
}

.win-btn {
  width: 40px;
  height: 34px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: none;
  background: transparent;
  color: var(--dim);
  border-radius: 6px;
  cursor: default;
  padding: 0;
}

.win-btn svg {
  width: 12px;
  height: 12px;
}

.win-btn:hover {
  background: rgba(255, 255, 255, 0.08);
  color: var(--text);
}

.win-btn.win-close:hover {
  background: #E81123;
  color: #FFFFFF;
}
</style>
