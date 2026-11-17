<script setup lang="ts">
/**
 * THE LIVE TERMINAL — a real PTY attached to the agent's own session.
 *
 * Not a log tail and not a picture of one: `xterm.js` in the browser, a genuine
 * pseudo-terminal on the server (`node-pty`), and one websocket between them.
 * The PTY holds `herdr agent attach <pane>`, which joins the terminal the agent
 * is ALREADY running in — so what you see is the run itself, and what you type
 * reaches the agent.
 *
 * Three promises this component keeps, each because its opposite has already
 * cost this house:
 *
 *  1. A dead terminal SAYS DEAD. When the PTY exits, the socket closes and the
 *     pane is covered with the exit code — never a frozen screen that looks
 *     alive (plan 001, the 27 shells).
 *  2. A reload re-attaches. The pane id is the identity, so a reload opens the
 *     same session again; the agent never noticed the viewer left.
 *  3. Nothing is invented. If the socket never opens, the pane says so with the
 *     reason.
 */
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { Terminal } from '@xterm/xterm'
import { FitAddon } from '@xterm/addon-fit'
import '@xterm/xterm/css/xterm.css'

const props = defineProps<{ pane: string; name?: string }>()

const host = ref<HTMLDivElement | null>(null)
const dead = ref<{ code: number | null; why: string } | null>(null)
const connecting = ref(true)
const cols = ref(120)
const rows = ref(32)

let term: Terminal | undefined
let fit: FitAddon | undefined
let socket: WebSocket | undefined
let observer: ResizeObserver | undefined

/** The private resize sequence the PTY host strips before the agent sees it. */
function sendResize() {
  if (!socket || socket.readyState !== WebSocket.OPEN || !term) return
  socket.send(`\x1b]999;${term.cols};${term.rows}\x07`)
}

function connect() {
  if (!host.value) return
  const url = new URL(`/api/terminal`, window.location.href)
  url.protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  url.searchParams.set('pane', props.pane)
  url.searchParams.set('cols', String(term?.cols ?? cols.value))
  url.searchParams.set('rows', String(term?.rows ?? rows.value))

  connecting.value = true
  dead.value = null
  socket = new WebSocket(url)

  socket.onopen = () => {
    connecting.value = false
    sendResize()
    term?.focus()
  }

  socket.onmessage = (event) => {
    if (typeof event.data === 'string') {
      // A control frame: attach · exit. Anything else is text for the screen.
      try {
        const control = JSON.parse(event.data)
        if (control.type === 'exit') {
          dead.value = { code: control.code ?? null, why: control.why ?? '' }
          socket?.close()
          return
        }
        if (control.type === 'attach') return
      } catch {
        /* not a control frame — fall through and print it */
      }
      term?.write(event.data)
      return
    }
    void (async () => {
      const buffer = event.data instanceof Blob ? await event.data.arrayBuffer() : event.data
      term?.write(new Uint8Array(buffer as ArrayBuffer))
    })()
  }

  socket.onerror = () => {
    connecting.value = false
    dead.value = { code: null, why: 'the socket could not be opened — is the visualizer running?' }
  }

  socket.onclose = () => {
    connecting.value = false
    if (!dead.value) dead.value = { code: 0, why: 'the terminal closed' }
  }
}

function reconnect() {
  dead.value = null
  connect()
}

onMounted(() => {
  term = new Terminal({
    cursorBlink: true,
    fontSize: 12,
    fontFamily: '"IBM Plex Mono", ui-monospace, monospace',
    scrollback: 5000,
    theme: { background: '#0e0c09', foreground: '#cfc3a9', cursor: '#c9973f' },
  })
  fit = new FitAddon()
  term.loadAddon(fit)
  term.open(host.value!)
  try {
    fit.fit()
  } catch {
    /* a hidden pane has no size yet */
  }

  // What the operator types goes to the agent.
  term.onData((data) => {
    if (socket?.readyState === WebSocket.OPEN) socket.send(data)
  })

  observer = new ResizeObserver(() => {
    try {
      fit?.fit()
    } catch {
      /* ignore */
    }
    sendResize()
  })
  observer.observe(host.value!)

  connect()
})

onBeforeUnmount(() => {
  observer?.disconnect()
  socket?.close()
  term?.dispose()
})
</script>

<template>
  <div class="terminal" data-testid="live-terminal" :data-pane="pane">
    <div ref="host" class="screen" />
    <p v-if="connecting" class="overlay connecting">attaching to {{ pane }}…</p>
    <p v-else-if="dead" class="overlay dead" data-testid="terminal-dead">
      <strong>this terminal is dead</strong>
      <span v-if="dead.code !== null"> — exit {{ dead.code }}</span>
      <span v-if="dead.why"> · {{ dead.why }}</span>
      <button type="button" class="again" @click="reconnect">attach again</button>
    </p>
  </div>
</template>

<style scoped>
.terminal {
  position: relative;
  display: flex;
  flex-direction: column;
  min-height: 220px;
  background: #0e0c09;
  border-top: 1px solid var(--border-soft);
}

.screen {
  flex: 1;
  min-height: 200px;
  padding: 6px 8px;
  overflow: hidden;
}

.screen :deep(.xterm) {
  height: 100%;
}

.overlay {
  position: absolute;
  inset: auto 0 0 0;
  margin: 0;
  padding: 8px 12px;
  font-size: 12px;
  background: color-mix(in srgb, #0e0c09 88%, transparent);
  border-top: 1px solid var(--border-soft);
}

.overlay.connecting {
  color: var(--faint);
}

.overlay.dead {
  color: var(--red);
}

.again {
  margin-left: 10px;
  background: transparent;
  border: 1px solid var(--border-soft);
  color: var(--dim);
  border-radius: 6px;
  padding: 1px 8px;
  font-size: 12px;
  cursor: pointer;
}

.again:hover {
  color: var(--accent);
  border-color: var(--border);
}
</style>
