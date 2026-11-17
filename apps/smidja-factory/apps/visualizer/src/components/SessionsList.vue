<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, shallowRef } from 'vue'
import type { SessionSummary } from '../lib/types'
import { fetchSessions } from '../lib/api'
import { ts } from '../lib/format'
import SessionCard from './SessionCard.vue'

const sessions = shallowRef<SessionSummary[]>([])
const apiError = ref<string | null>(null)
const loaded = ref(false)
const nowMs = ref(Date.now())
/**
 * WHICH LIST THIS IS. `cleaned` is the review list — a run archived with the
 * card's × leaves it, which is what the × promises. `all` is the same list with
 * the archived runs back in it, so archiving is never a way to lose one.
 */
const scope = ref<'cleaned' | 'all'>('cleaned')

let timer: ReturnType<typeof setInterval> | undefined
let inflight = false

async function tick() {
  if (inflight) return
  inflight = true
  try {
    sessions.value = await fetchSessions(scope.value)
    nowMs.value = Date.now()
    apiError.value = null
    loaded.value = true
  } catch (err) {
    apiError.value = err instanceof Error ? err.message : String(err)
  } finally {
    inflight = false
  }
}

onMounted(() => {
  void tick()
  timer = setInterval(() => void tick(), 500)
})

onUnmounted(() => clearInterval(timer))

function toggleScope() {
  scope.value = scope.value === 'cleaned' ? 'all' : 'cleaned'
  void tick()
}


/** Optimistic removal; an empty id means the write failed, so re-sync instead. */
function onArchived(adwId: string) {
  if (!adwId) {
    void tick()
    return
  }
  sessions.value = sessions.value.filter((s) => s.smidja_id !== adwId)
}

const ordered = computed(() =>
  sessions.value.toSorted((a, b) => (ts(b.started_at) || 0) - (ts(a.started_at) || 0)),
)
</script>

<template>
  <div class="sessions">
    <div v-if="apiError" class="error-bar">api unreachable — retrying {{ apiError }}</div>

    <div class="list-head dim">
      <span>{{ ordered.length }} {{ scope === 'all' ? 'runs (archived included)' : 'runs' }}</span>
      <button type="button" class="scope-toggle" @click="toggleScope">
        {{ scope === 'all' ? 'hide archived' : 'show archived' }}
      </button>
    </div>

    <div v-if="ordered.length" class="cards">
      <SessionCard
        v-for="s in ordered"
        :key="s.smidja_id"
        :session="s"
        :now-ms="nowMs"
        :show-archived="scope === 'all'"
        @archived="onArchived"
      />
    </div>
    <div v-else-if="loaded" class="empty-state">no sessions yet — run an smidja to see it here</div>
    <div v-else-if="!apiError" class="empty-state">loading sessions…</div>
  </div>
</template>

<style scoped>
.sessions {
  display: flex;
  flex-direction: column;
}

.scope-toggle {
  background: transparent;
  border: 1px solid var(--border-soft);
  color: var(--dim);
  border-radius: 6px;
  padding: 2px 10px;
  font-size: 13px;
  cursor: pointer;
}

.scope-toggle:hover {
  color: var(--accent);
  border-color: var(--border);
}

.list-head {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 16px 24px 0;
  font-size: 16px;
}

.cards {
  /* Uniform grid: every card the same width and (fixed in SessionCard) height,
     independent of content. */
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(460px, 1fr));
  gap: 18px;
  padding: 16px 24px 28px;
}





</style>
