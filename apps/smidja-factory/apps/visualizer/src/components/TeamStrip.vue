<script setup lang="ts">
/**
 * THE TEAM, AS THE SESSION'S OWN ANSWER.
 *
 * A run IS a team: the agents its roster named, each with its own core four —
 * the context it was given, the model it ran on, the prompt it was written with,
 * and the tools it was allowed. The video's lesson and this board's job are the
 * same sentence: *a team you cannot see is a team you cannot steer.*
 *
 * So this strip is per RUN, not per machine (the machine-wide strip lives under
 * the topbar). It answers, for the session you have open:
 *
 *   who was on the team · which RUNTIME each one ran on (pi · opencode · herdr)
 *   · which model · how full its window got · and, for a herdr seat, the PANE
 *     it is working in and its live state, with one click to look at it.
 *
 * A run whose agents were processes (pi/opencode) says so plainly — "no pane,
 * these ran as processes" — because an empty pane column would read as "the
 * seats are missing", which is a different and false claim.
 */
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import type { AgentSession } from '../lib/types'
import { openPane } from '../lib/pane-drawer'

const props = defineProps<{ smidjaId: string; agents: AgentSession[] }>()

interface Seat {
  name: string
  pane: string
  status: string
  cwd: string
  smidja: boolean
  run: string
  role: string
}

const seats = ref<Seat[]>([])
const herdrWhy = ref('')
const herdrAnswered = ref(true)
let timer: number | undefined

async function load() {
  try {
    const response = await fetch(`/api/herdr/seats?run=${encodeURIComponent(props.smidjaId)}`)
    const data = (await response.json()) as { herdr: boolean; why: string; seats: Seat[] }
    herdrAnswered.value = data.herdr
    herdrWhy.value = data.why ?? ''
    seats.value = data.seats ?? []
  } catch (error) {
    herdrAnswered.value = false
    herdrWhy.value = (error as Error).message
    seats.value = []
  }
}

onMounted(() => {
  load()
  timer = window.setInterval(load, 2000)
})
onBeforeUnmount(() => {
  if (timer) window.clearInterval(timer)
})

/** The seat for one member: a smidja seat is named `smj-<run8>-<agent>`. */
function seatFor(agent: string): Seat | undefined {
  return seats.value.find((seat) => seat.role === agent)
}

/**
 * WHICH RUNTIME THIS MEMBER RAN ON — from evidence, never a guess.
 *
 * `agent_sessions.coding_agent` is written when a phase FINISHES, so a member
 * that is working right now has no answer there yet. A live herdr seat is proof
 * enough on its own (only the herdr interface raises one), and anything else is
 * stated as unknown rather than assumed to be pi — the old fallback printed
 * `pi` over a herdr seat, which is exactly the kind of quiet lie a board must
 * not tell.
 */
function runtimeOf(agent: AgentSession): string {
  if (seatFor(agent.agent)) return 'herdr'
  return agent.coding_agent || '—'
}

/** How full the window was after the last turn — the receipt, not a guess. */
function occupancy(agent: AgentSession): number | null {
  if (!agent.context_tokens || !agent.context_window) return null
  return Math.round((agent.context_tokens / agent.context_window) * 100)
}

function shortPath(path: string): string {
  const parts = (path ?? '').split('/').filter(Boolean)
  return parts.length > 1 ? `…/${parts.slice(-2).join('/')}` : path
}

/** Read the pane in the drawer — `herdr agent focus` alone changes nothing you can see. */
function look(pane: string, name: string, cwd: string) {
  openPane({ pane, name, cwd })
}

const runtimes = computed(() => {
  const counts = new Map<string, number>()
  for (const agent of props.agents) {
    const key = runtimeOf(agent)
    if (key === '—') continue
    counts.set(key, (counts.get(key) ?? 0) + 1)
  }
  return [...counts.entries()].map(([name, count]) => `${name}${count > 1 ? `×${count}` : ''}`).join(' · ')
})

const anySeat = computed(() => props.agents.some((agent) => runtimeOf(agent) === 'herdr'))
</script>

<template>
  <section v-if="agents.length" class="team" aria-label="The team this run seated">
    <header class="team-head">
      <span class="team-title">the team</span>
      <span class="team-count">{{ agents.length }} agent{{ agents.length === 1 ? '' : 's' }}</span>
      <span v-if="runtimes" class="team-runtimes" data-testid="team-runtimes">{{ runtimes }}</span>
      <span v-if="anySeat && !herdrAnswered" class="team-why">
        no herdr session — {{ herdrWhy }}
      </span>
    </header>

    <ul class="team-list">
      <li
        v-for="agent in agents"
        :key="agent.agent"
        class="member"
        :class="{ seated: seatFor(agent.agent) }"
        :data-testid="`team-member-${agent.agent}`"
        :style="{ borderColor: agent.color ? `${agent.color}66` : undefined }"
      >
        <span class="member-name" :style="{ color: agent.color ?? undefined }">{{ agent.agent }}</span>
        <span class="badge runtime" :data-runtime="runtimeOf(agent)">{{ runtimeOf(agent) }}</span>
        <span class="member-model" :title="agent.model ?? ''">{{ (agent.model ?? '—').split('/').pop() }}</span>
        <span v-if="occupancy(agent) !== null" class="member-ctx" :title="`${agent.context_tokens} of ${agent.context_window} tokens after the last turn`">
          {{ occupancy(agent) }}%
        </span>
        <template v-if="seatFor(agent.agent)">
          <code class="member-pane">{{ seatFor(agent.agent)!.pane }}</code>
          <span class="member-state" :class="seatFor(agent.agent)!.status">{{ seatFor(agent.agent)!.status }}</span>
          <span class="member-cwd" :title="seatFor(agent.agent)!.cwd">{{ shortPath(seatFor(agent.agent)!.cwd) }}</span>
          <button
            type="button"
            class="member-look"
            @click="look(seatFor(agent.agent)!.pane, agent.agent, seatFor(agent.agent)!.cwd)"
          >look</button>
        </template>
        <span v-else-if="runtimeOf(agent) === 'herdr'" class="member-note">pane closed</span>
        <span v-else class="member-note">a process, no pane</span>
      </li>
    </ul>
  </section>
</template>

<style scoped>
.team {
  margin: 0 24px 14px;
  border: 1px solid var(--border-soft);
  border-radius: 10px;
  background: color-mix(in srgb, var(--panel) 70%, transparent);
  padding: 10px 14px;
}

.team-head {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 13px;
  color: var(--faint);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  margin-bottom: 8px;
}

.team-title {
  color: var(--accent);
}

.team-runtimes {
  color: var(--dim);
  text-transform: none;
  letter-spacing: 0;
  font-family: var(--mono);
}

.team-why {
  color: var(--red);
  text-transform: none;
  letter-spacing: 0;
}

.team-list {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  list-style: none;
  margin: 0;
  padding: 0;
}

.member {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 5px 11px;
  border: 1px solid var(--border-soft);
  border-radius: 999px;
  font-size: 13px;
}

.member.seated {
  background: color-mix(in srgb, var(--accent) 7%, transparent);
}

.member-name {
  color: var(--text);
  font-family: var(--mono);
}

.badge.runtime {
  font-size: 11px;
  padding: 1px 7px;
  border-radius: 999px;
  border: 1px solid var(--border-soft);
  color: var(--dim);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.badge.runtime[data-runtime='herdr'] {
  color: var(--accent);
  border-color: color-mix(in srgb, var(--accent) 50%, transparent);
}

.member-model,
.member-pane,
.member-cwd {
  font-family: var(--mono);
  font-size: 12px;
  color: var(--faint);
}

.member-ctx {
  font-size: 12px;
  color: var(--dim);
}

.member-state {
  font-size: 12px;
  color: var(--dim);
}

.member-state.working {
  color: var(--accent);
}

.member-note {
  font-size: 12px;
  color: var(--faint);
  font-style: italic;
}

.member-look {
  background: transparent;
  border: 1px solid var(--border-soft);
  color: var(--dim);
  border-radius: 6px;
  padding: 1px 8px;
  font-size: 12px;
  cursor: pointer;
}

.member-look:hover {
  color: var(--accent);
  border-color: var(--border);
}
</style>
