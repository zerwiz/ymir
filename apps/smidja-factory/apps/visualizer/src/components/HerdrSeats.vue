<script setup lang="ts">
/**
 * The seats, live — who is working right now, and where to look at them.
 *
 * A herdr agent runs in a PANE: that is the reason to seat one there at all, so
 * the person can watch the work happen instead of reading its trace afterwards.
 * This strip is the board's half of that bargain. It asks the server, the server
 * asks herdr, and what comes back is the truth as herdr holds it — including the
 * honest case where herdr cannot answer at all, which is NOT "nobody is working".
 *
 * `run` narrows the strip to one run's team (`smj-<run8>-<agent>`); without it,
 * every seat on the machine is shown and a smidja seat is marked.
 */
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

const props = defineProps<{ run?: string; pollMs?: number }>()

interface Seat {
  name: string
  pane: string
  tab: string
  status: string
  cwd: string
  agent: string
  smidja: boolean
  run: string
  role: string
}

const seats = ref<Seat[]>([])
const herdr = ref(true)
const why = ref('')
const loaded = ref(false)
const focusNote = ref('')
let timer: number | undefined

async function load() {
  try {
    const query = props.run ? `?run=${encodeURIComponent(props.run)}` : ''
    const response = await fetch(`/api/herdr/seats${query}`)
    const data = (await response.json()) as {
      herdr: boolean
      why: string
      seats: Seat[]
    }
    herdr.value = data.herdr
    why.value = data.why ?? ''
    seats.value = data.seats ?? []
  } catch (error) {
    herdr.value = false
    why.value = `the board could not ask the server: ${(error as Error).message}`
    seats.value = []
  } finally {
    loaded.value = true
  }
}

/** Bring a pane to the front — the one action this strip has. */
async function focus(pane: string) {
  focusNote.value = ''
  try {
    const response = await fetch('/api/herdr/focus', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ pane }),
    })
    if (!response.ok) {
      const data = (await response.json().catch(() => ({}))) as { why?: string; error?: string }
      focusNote.value = `could not focus ${pane}: ${data.why ?? data.error ?? response.status}`
    }
  } catch (error) {
    focusNote.value = `could not focus ${pane}: ${(error as Error).message}`
  }
}

/** A tree's last two segments — enough to recognise the seat, short enough to fit. */
function shortPath(path: string): string {
  const parts = (path ?? '').split('/').filter(Boolean)
  return parts.length > 1 ? `…/${parts.slice(-2).join('/')}` : path
}

const working = computed(() => seats.value.filter((seat) => seat.status === 'working').length)

onMounted(() => {
  load()
  timer = window.setInterval(load, props.pollMs ?? 2000)
})
onBeforeUnmount(() => {
  if (timer) window.clearInterval(timer)
})
</script>

<template>
  <section v-if="loaded" class="seats" aria-label="Agents seated in herdr">
    <!-- herdr cannot answer: say so, name why, and never look empty. -->
    <p v-if="!herdr" class="seats-why" data-testid="herdr-why">
      <span class="dot off" aria-hidden="true"></span>
      no herdr session on this machine — {{ why }}
    </p>

    <template v-else>
      <p v-if="!seats.length" class="seats-why" data-testid="herdr-empty">
        <span class="dot off" aria-hidden="true"></span>
        herdr answers, and no agent is seated — nothing is running
      </p>

      <ul v-else class="seat-list">
        <li class="seats-head">
          <span class="dot on" aria-hidden="true"></span>
          {{ seats.length }} seated · {{ working }} working
        </li>
        <li
          v-for="seat in seats"
          :key="seat.pane || seat.name"
          class="seat"
          :class="{ smidja: seat.smidja, working: seat.status === 'working' }"
          :data-testid="`herdr-seat-${seat.name}`"
        >
          <span class="dot" :class="seat.status === 'working' ? 'on' : 'idle'" aria-hidden="true"></span>
          <span class="seat-name">{{ seat.name || seat.pane }}</span>
          <span class="seat-role" v-if="seat.smidja && seat.role">{{ seat.role }}</span>
          <code class="seat-pane">{{ seat.pane }}</code>
          <span class="seat-status">{{ seat.status }}</span>
          <span class="seat-cwd" :title="seat.cwd">{{ shortPath(seat.cwd) }}</span>
          <button
            type="button"
            class="seat-focus"
            :title="`Show ${seat.pane} in herdr`"
            @click="focus(seat.pane)"
          >look</button>
        </li>
      </ul>
      <p v-if="focusNote" class="seats-why">{{ focusNote }}</p>
    </template>
  </section>
</template>

<style scoped>
.seats {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 6px 28px;
  border-bottom: 1px solid var(--border-soft);
  background: color-mix(in srgb, var(--panel) 72%, transparent);
  font-size: 14px;
  color: var(--dim);
  overflow-x: auto;
}

.seat-list {
  display: flex;
  align-items: center;
  gap: 16px;
  list-style: none;
  margin: 0;
  padding: 0;
  white-space: nowrap;
}

.seats-head {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  color: var(--faint);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  font-size: 12px;
}

.seat {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 3px 10px;
  border-radius: 999px;
  border: 1px solid var(--border-soft);
}

.seat.smidja {
  border-color: color-mix(in srgb, var(--accent) 45%, transparent);
}

.seat.working {
  background: color-mix(in srgb, var(--accent) 8%, transparent);
}

.seat-name {
  color: var(--text);
  font-family: var(--mono);
  font-size: 13px;
}

.seat-role {
  color: var(--accent);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.seat-pane,
.seat-cwd {
  font-family: var(--mono);
  font-size: 12px;
  color: var(--faint);
}

.seat-status {
  font-size: 12px;
  color: var(--dim);
}

.seat-focus {
  background: transparent;
  border: 1px solid var(--border-soft);
  color: var(--dim);
  border-radius: 6px;
  padding: 1px 8px;
  font-size: 12px;
  cursor: pointer;
}

.seat-focus:hover {
  color: var(--accent);
  border-color: var(--border);
}

.seats-why {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin: 0;
  color: var(--faint);
  font-size: 13px;
}

.dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  flex: none;
  background: var(--faint);
}

.dot.on {
  background: var(--accent);
  box-shadow: 0 0 8px color-mix(in srgb, var(--accent) 70%, transparent);
}

.dot.idle {
  background: var(--green);
}

.dot.off {
  background: var(--red);
  opacity: 0.7;
}
</style>
