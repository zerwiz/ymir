<script setup lang="ts">
/**
 * The pane drawer — what an agent's terminal says, inside the board.
 *
 * `look` used to call `herdr agent focus`, which moves herdr's own focus and
 * therefore does nothing you can SEE while you are sitting in the Smíðja window
 * (measured: the POST returned `{"ok":true}` and the screen did not change). A
 * control whose effect is invisible is a broken control.
 *
 * So the drawer reads the pane (`herdr agent read`, text, no escape codes) and
 * shows it here, live, while it is open. `raise` is still there for the case the
 * operator wants herdr's own window — it says what it did, and it does not
 * pretend to be the same thing.
 */
import { onBeforeUnmount, ref, watch } from 'vue'
import { openPaneRef, closePane, openPane } from '../lib/pane-drawer'
import LiveTerminal from './LiveTerminal.vue'

const pane = openPaneRef
/**
 * READ or TYPE. `read` is the pane's words, sampled; `terminal` is a REAL PTY
 * attached to the agent's own session — what you type reaches it. The choice and
 * the open pane are remembered, so a page reload re-attaches to the same session
 * instead of silently dropping it (the agent never noticed the viewer left).
 */
const mode = ref<'read' | 'terminal'>('read')
const MODE_KEY = 'smidja-pane-mode'
const OPEN_KEY = 'smidja-pane-open'
const text = ref('')
const state = ref('unknown')
const why = ref('')
const source = ref('')
const loading = ref(false)
const note = ref('')
let timer: number | undefined

async function load() {
  if (!pane.value) return
  loading.value = true
  try {
    const response = await fetch(`/api/herdr/pane?pane=${encodeURIComponent(pane.value.pane)}&lines=400`)
    const data = (await response.json()) as {
      ok: boolean
      why: string
      state: string
      text: string
      source: string
    }
    if (data.ok) {
      text.value = data.text
      state.value = data.state
      source.value = data.source
      why.value = ''
    } else {
      why.value = data.why || `the board could not read ${pane.value.pane}`
    }
  } catch (error) {
    why.value = (error as Error).message
  } finally {
    loading.value = false
  }
}

async function raise() {
  if (!pane.value) return
  note.value = ''
  try {
    const response = await fetch('/api/herdr/focus', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ pane: pane.value.pane }),
    })
    const data = (await response.json()) as { ok: boolean; why: string }
    note.value = data.ok
      ? `herdr's own focus is on ${pane.value.pane} — switch to the herdr window to see it`
      : `could not raise ${pane.value.pane}: ${data.why}`
  } catch (error) {
    note.value = `could not raise ${pane.value.pane}: ${(error as Error).message}`
  }
}

watch(
  () => pane.value?.pane,
  (value) => {
    if (timer) window.clearInterval(timer)
    text.value = ''
    why.value = ''
    note.value = ''
    if (!value) {
      localStorage.removeItem(OPEN_KEY)
      return
    }
    localStorage.setItem(OPEN_KEY, JSON.stringify({ pane: value, name: pane.value?.name ?? '', cwd: pane.value?.cwd ?? '' }))
    if (mode.value !== 'read') return
    void load()
    timer = window.setInterval(load, 2000)
  },
)

watch(mode, (value) => {
  localStorage.setItem(MODE_KEY, value)
  if (timer) window.clearInterval(timer)
  if (value === 'read' && pane.value) {
    void load()
    timer = window.setInterval(load, 2000)
  }
})

// A reload re-opens the same pane in the same mode: the identity is the PANE,
// and the agent's session outlives the browser either way.
const savedMode = localStorage.getItem(MODE_KEY)
if (savedMode === 'terminal' || savedMode === 'read') mode.value = savedMode
const savedPane = localStorage.getItem(OPEN_KEY)
if (savedPane) {
  try {
    const parsed = JSON.parse(savedPane) as { pane?: string; name?: string; cwd?: string }
    if (parsed?.pane) openPane({ pane: parsed.pane, name: parsed.name, cwd: parsed.cwd })
  } catch {
    /* a stale entry is not worth a broken drawer */
  }
}

onBeforeUnmount(() => {
  if (timer) window.clearInterval(timer)
})
</script>

<template>
  <aside v-if="pane" class="drawer" aria-label="The pane's own words" data-testid="pane-drawer">
    <header class="drawer-head">
      <span class="dot" :class="state === 'working' ? 'on' : 'idle'" aria-hidden="true"></span>
      <strong>{{ pane.name || pane.pane }}</strong>
      <code>{{ pane.pane }}</code>
      <span class="state">{{ state }}</span>
      <span v-if="source === 'visible'" class="source" title="A working agent's scrollback cannot be captured; this is its screen">
        the screen
      </span>
      <span v-if="pane.cwd" class="cwd" :title="pane.cwd">{{ pane.cwd }}</span>
      <span class="spacer" />
      <button
        type="button"
        class="btn"
        :class="{ active: mode === 'read' }"
        title="Read the pane's words, sampled"
        @click="mode = 'read'"
      >read</button>
      <button
        type="button"
        class="btn"
        :class="{ active: mode === 'terminal' }"
        title="A real PTY attached to this agent — what you type reaches it"
        @click="mode = 'terminal'"
      >terminal</button>
      <button type="button" class="btn" title="Move herdr's own focus to this pane" @click="raise">raise</button>
      <button type="button" class="btn" title="Close this view" @click="closePane()">close</button>
    </header>

    <!-- THE LIVE TERMINAL: a real PTY on the agent's own session. -->
    <LiveTerminal v-if="mode === 'terminal'" :key="pane.pane" :pane="pane.pane" :name="pane.name" />

    <template v-else>
      <p v-if="why" class="why">could not read the pane — {{ why }}</p>
      <p v-else-if="note" class="why">{{ note }}</p>
      <pre v-if="!why" class="pane-text" :class="{ loading }">{{ text || 'reading the pane…' }}</pre>
    </template>
  </aside>
</template>

<style scoped>
.drawer {
  position: fixed;
  right: 18px;
  bottom: 18px;
  width: min(760px, 52vw);
  max-height: 62vh;
  display: flex;
  flex-direction: column;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: color-mix(in srgb, var(--panel) 96%, transparent);
  box-shadow: 0 18px 50px rgba(0, 0, 0, 0.55);
  z-index: 40;
}

.drawer-head {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  border-bottom: 1px solid var(--border-soft);
  font-size: 13px;
  color: var(--dim);
}

.drawer-head strong {
  color: var(--text);
  font-family: var(--mono);
  font-weight: 600;
}

.drawer-head code {
  font-family: var(--mono);
  color: var(--faint);
}

.source {
  font-size: 11px;
  color: var(--faint);
  font-style: italic;
}

.state {
  text-transform: uppercase;
  letter-spacing: 0.05em;
  font-size: 11px;
  color: var(--accent);
}

.cwd {
  font-family: var(--mono);
  font-size: 11px;
  color: var(--faint);
  max-width: 220px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.spacer {
  flex: 1;
}

.btn {
  background: transparent;
  border: 1px solid var(--border-soft);
  color: var(--dim);
  border-radius: 6px;
  padding: 2px 10px;
  font-size: 12px;
  cursor: pointer;
}

.btn:hover {
  color: var(--accent);
  border-color: var(--border);
}

.btn.active {
  color: var(--accent);
  border-color: color-mix(in srgb, var(--accent) 55%, transparent);
}

.why {
  margin: 0;
  padding: 8px 12px;
  font-size: 12px;
  color: var(--red);
}

.pane-text {
  margin: 0;
  padding: 10px 12px;
  overflow: auto;
  font-family: var(--mono);
  font-size: 11.5px;
  line-height: 1.45;
  color: var(--text);
  white-space: pre-wrap;
  word-break: break-word;
}

.pane-text.loading {
  opacity: 0.6;
}

.dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--faint);
}

.dot.on {
  background: var(--accent);
  box-shadow: 0 0 8px color-mix(in srgb, var(--accent) 70%, transparent);
}

.dot.idle {
  background: var(--green);
}
</style>
