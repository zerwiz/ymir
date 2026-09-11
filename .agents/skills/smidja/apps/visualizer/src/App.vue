<script setup lang="ts">
import { computed, ref } from 'vue'
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
const isMeta = computed(() => isMemory.value || isDecisions.value || isStats.value || isChat.value || isSettings.value)

// ── Theme toggle: the neutral theme is the default; data-theme="classic"
   //    preserves the OLD deep-space visualizer look (added 2026-09-01, G7 —
   //    nothing removed, the old styling is kept as an option).
   //    data-theme="high-contrast" adds a WCAG AAA compliant high contrast mode.
   //    Choice is persisted locally. ──
  const savedTheme = localStorage.getItem('factory-theme')
  if (savedTheme === 'classic' || savedTheme === 'high-contrast') {
    document.documentElement.dataset.theme = savedTheme
  }
  const theme = ref<'neutral' | 'classic' | 'high-contrast'>(
    (savedTheme === 'classic' || savedTheme === 'high-contrast') ? savedTheme : 'neutral'
  )
  function toggleTheme() {
    const order: Array<'neutral' | 'classic' | 'high-contrast'> = ['neutral', 'classic', 'high-contrast']
    const idx = order.indexOf(theme.value)
    theme.value = order[(idx + 1) % order.length]
    if (theme.value === 'neutral') {
      delete document.documentElement.dataset.theme
    } else {
      document.documentElement.dataset.theme = theme.value
    }
    localStorage.setItem('factory-theme', theme.value)
  }

// Running inside the Electron shell? Then the native frame is hidden and the
// topbar doubles as the title bar — its right edge gets the window controls.
// Custom controls only appear on Linux; Windows/macOS draw native overlay
// buttons (which already sit on the right / follow the OS convention).
const isDesktop = (window as { factoryDesktop?: { isDesktop?: boolean } }).factoryDesktop?.isDesktop ?? false
const isLinuxDesktop = isDesktop && (window as { factoryDesktop?: { platform?: string } }).factoryDesktop?.platform === 'linux'
function winControl(action: 'minimize' | 'maximize' | 'close') {
  ;(window as { factoryDesktop?: { windowControl?: (a: string) => void } }).factoryDesktop?.windowControl?.(action)
}
</script>

<template>
  <div class="app">
    <a href="#main-content" class="skip-link">Skip to main content</a>
    <header class="topbar">
      <nav class="crumbs">
        <!-- Inline copy of public/logo.svg (the favicon) so the mark renders
             crisply with no fetch; keep the two in sync. -->
        <svg class="logo" viewBox="0 0 32 32" aria-hidden="true">
          <rect x="4" y="6" width="17" height="5" rx="2.5" fill="#FF6B35" />
          <rect x="8" y="13.5" width="20" height="5" rx="2.5" fill="#FF8F5C" />
          <rect x="4" y="21" width="13" height="5" rx="2.5" fill="#E25A26" />
        </svg>
        <span class="brand">WayOf Factory</span>
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
      <button class="theme-toggle" type="button" :title="`Theme: ${theme === 'classic' ? 'classic deep-space' : theme === 'high-contrast' ? 'high contrast (WCAG AAA)' : 'neutral'} (click to switch)`" @click="toggleTheme">
        {{ theme === 'classic' ? 'classic' : theme === 'high-contrast' ? 'high-contrast' : 'neutral' }}
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
    rgba(255, 107, 53, 0.4),
    rgba(255, 143, 92, 0.3) 40%,
    rgba(255, 143, 92, 0.06)
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
  filter: drop-shadow(0 0 8px rgba(255, 107, 53, 0.3));
}

.brand {
  background: linear-gradient(90deg, var(--accent), #FF8F5C);
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
.win-controls {
  -webkit-app-region: no-drag;
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
