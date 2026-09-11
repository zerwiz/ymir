<script setup lang="ts">
import { onMounted, ref, shallowRef } from 'vue'
import type { MemoryEpisode, MemoryFact, MemoryHealth, MemoryInspect } from '../lib/types'
import {
  fetchMemoryHealth,
  fetchMemoryInspect,
  fetchMemoryRecall,
  fetchMemoryTimeline,
  observeMemory,
} from '../lib/api'
import { fmtDate } from '../lib/format'

// ── state ───────────────────────────────────────────────────────────────────
const health = ref<MemoryHealth>({ ok: false, db: '' })
const inspect = shallowRef<MemoryInspect | null>(null)
const apiError = ref<string | null>(null)

const recallQ = ref('')
const recallMode = ref<'hybrid' | 'cosine' | 'spreading'>('hybrid')
const recallResults = shallowRef<{ score: number; episode: MemoryEpisode }[]>([])
const recallLoading = ref(false)
const searched = ref(false)

const timelineEntity = ref('')
const timeline = shallowRef<MemoryFact[]>([])
const timelineLoading = ref(false)

const observeText = ref('')
const observeTags = ref('')
const observing = ref(false)
const observeDone = ref<string | null>(null)

// ── load ────────────────────────────────────────────────────────────────────
async function load() {
  try {
    health.value = await fetchMemoryHealth()
    inspect.value = await fetchMemoryInspect()
    apiError.value = null
  } catch (err) {
    apiError.value = err instanceof Error ? err.message : String(err)
  }
}
onMounted(() => void load())

// ── actions ─────────────────────────────────────────────────────────────────
async function runRecall() {
  const q = recallQ.value.trim()
  if (!q) return
  recallLoading.value = true
  recallResults.value = []
  try {
    const data = await fetchMemoryRecall(q, 8, recallMode.value)
    recallResults.value = data.results
    searched.value = true
  } catch (err) {
    apiError.value = err instanceof Error ? err.message : String(err)
  } finally {
    recallLoading.value = false
  }
}

async function runTimeline() {
  const entity = timelineEntity.value.trim()
  if (!entity) return
  timelineLoading.value = true
  timeline.value = []
  try {
    timeline.value = (await fetchMemoryTimeline(entity)).facts
  } catch (err) {
    apiError.value = err instanceof Error ? err.message : String(err)
  } finally {
    timelineLoading.value = false
  }
}

async function submitObserve() {
  const content = observeText.value.trim()
  if (!content) return
  observing.value = true
  observeDone.value = null
  try {
    const tags = observeTags.value
      .split(',')
      .map((t) => t.trim())
      .filter(Boolean)
    const res = await observeMemory(content, tags, ['kaia'], 0.7)
    observeDone.value = res.id
    observeText.value = ''
    observeTags.value = ''
    await load()
  } catch (err) {
    apiError.value = err instanceof Error ? err.message : String(err)
  } finally {
    observing.value = false
  }
}

function tagClass(tag: string): string {
  if (tag === 'success') return 'tag tag-success'
  if (tag === 'fail' || tag === 'blocked') return 'tag tag-fail'
  return 'tag'
}
</script>

<template>
  <div class="memory">
    <div v-if="apiError" class="error-bar">memory unreachable — {{ apiError }}</div>

    <!-- header + stats -->
    <div class="head">
      <div class="title">Kaia's memory <span class="dim">(engram)</span></div>
      <div v-if="health.ok" class="stat-row">
        <span class="stat">
          <b>{{ inspect?.counts.episodes ?? health.episodes ?? '—' }}</b>
          episodes
        </span>
        <span class="stat">
          <b>{{ inspect?.counts.facts ?? health.facts ?? '—' }}</b>
          facts
        </span>
        <span class="stat">
          <b>{{ inspect?.counts.entities ?? health.entities ?? '—' }}</b>
          entities
        </span>
        <span v-if="inspect?.db" class="dim db">db: {{ inspect.db }}</span>
      </div>
    </div>

    <div v-if="!health.ok && !apiError" class="empty-state">
      memory bridge offline — start it with <code>just kaia</code> or
      <code>scripts/factory-ui.sh</code>
    </div>

    <template v-if="health.ok">
      <!-- recall -->
      <section class="panel">
        <div class="panel-title">Recall</div>
        <div class="row">
          <input
            v-model="recallQ"
            class="input"
            placeholder="what works for building wayofteams?"
            @keyup.enter="runRecall"
          />
          <select v-model="recallMode" class="input select">
            <option value="hybrid">hybrid</option>
            <option value="cosine">cosine</option>
            <option value="spreading">spreading</option>
          </select>
          <button class="btn" :disabled="recallLoading" @click="runRecall">
            {{ recallLoading ? 'recalling…' : 'recall' }}
          </button>
        </div>
        <div v-if="recallResults.length" class="results">
          <div v-for="(r, i) in recallResults" :key="i" class="result">
            <div class="result-score" :title="`score ${r.score}`">
              {{ r.score.toFixed(2) }}
            </div>
            <div class="result-body">
              <div class="result-content">{{ r.episode.content }}</div>
              <div class="result-meta">
                <span v-if="r.episode.timestamp" class="dim">{{ fmtDate(r.episode.timestamp) }}</span>
                <span
                  v-for="t in r.episode.tags"
                  :key="t"
                  :class="tagClass(t)"
                >
                  {{ t }}
                </span>
              </div>
            </div>
          </div>
        </div>
        <div v-else-if="searched" class="empty-state">no memories matched</div>
      </section>

      <!-- timeline -->
      <section class="panel">
        <div class="panel-title">Timeline</div>
        <div class="row">
          <input
            v-model="timelineEntity"
            class="input"
            placeholder="entity — e.g. wayofteams"
            @keyup.enter="runTimeline"
          />
          <button class="btn" :disabled="timelineLoading" @click="runTimeline">
            {{ timelineLoading ? 'loading…' : 'facts' }}
          </button>
        </div>
        <div v-if="timeline.length" class="results">
          <div v-for="(f, i) in timeline" :key="i" class="fact">
            <b>{{ f.subject }}</b> {{ f.predicate }} <b>{{ f.object }}</b>
            <span v-if="f.valid_from" class="dim">
              {{ fmtDate(f.valid_from) }} → {{ f.valid_to ? fmtDate(f.valid_to) : 'now' }}
            </span>
          </div>
        </div>
      </section>

      <!-- observe -->
      <section class="panel">
        <div class="panel-title">Observe <span class="dim">(write a memory)</span></div>
        <div class="row">
          <input
            v-model="observeText"
            class="input grow"
            placeholder="project=wayofteams task=coding mode=cloud-fast model=deepseek-v4-flash tool_calls_ok=1 gates_passed=3/3 outcome=success"
            @keyup.enter="submitObserve"
          />
          <input
            v-model="observeTags"
            class="input tags"
            placeholder="tags, comma, sep"
            @keyup.enter="submitObserve"
          />
          <button class="btn" :disabled="observing || !observeText.trim()" @click="submitObserve">
            {{ observing ? 'writing…' : 'observe' }}
          </button>
        </div>
        <div v-if="observeDone" class="ok">stored {{ observeDone }}</div>
      </section>

      <!-- recent episodes -->
      <section class="panel">
        <div class="panel-title">Recent episodes</div>
        <div v-if="inspect?.episodes.length" class="results">
          <div v-for="(ep, i) in inspect.episodes" :key="ep.id ?? i" class="result">
            <div class="result-score dim">{{ ep.importance?.toFixed(2) ?? '—' }}</div>
            <div class="result-body">
              <div class="result-content">{{ ep.content }}</div>
              <div class="result-meta">
                <span v-if="ep.timestamp" class="dim">{{ fmtDate(ep.timestamp) }}</span>
                <span v-for="t in ep.tags" :key="t" :class="tagClass(t)">{{ t }}</span>
              </div>
            </div>
          </div>
        </div>
        <div v-else class="empty-state">no memories yet — run a mission to start learning</div>
      </section>
    </template>
  </div>
</template>

<style scoped>
.memory {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px 24px 40px;
}

.head {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.title {
  font-size: 22px;
  font-weight: 600;
}
.stat-row {
  display: flex;
  gap: 20px;
  align-items: baseline;
}
.stat b {
  font-size: 20px;
  color: #ff8f5c;
  margin-right: 4px;
}
.db {
  font-size: 12px;
  margin-left: auto;
}

.panel {
  background: rgba(16, 21, 32, 0.6);
  border: 1px solid rgba(255, 143, 92, 0.12);
  border-radius: 12px;
  padding: 14px 16px;
}
.panel-title {
  font-weight: 600;
  margin-bottom: 10px;
}

.row {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.input {
  background: rgba(11, 15, 24, 0.8);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 8px;
  color: inherit;
  padding: 8px 12px;
  flex: 1 1 260px;
}
.input.grow {
  flex: 3 1 420px;
}
.input.tags {
  flex: 1 1 160px;
}
.select {
  flex: 0 0 auto;
  width: auto;
}
.btn {
  background: linear-gradient(90deg, #ff6b35, #ff8f5c);
  border: none;
  border-radius: 8px;
  color: #0b0f18;
  font-weight: 600;
  padding: 8px 16px;
  cursor: pointer;
}
.btn:disabled {
  opacity: 0.5;
  cursor: default;
}

.results {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: 10px;
}
.result {
  display: flex;
  gap: 10px;
  align-items: flex-start;
}
.result-score {
  min-width: 38px;
  text-align: right;
  font-variant-numeric: tabular-nums;
  font-size: 13px;
  padding-top: 2px;
}
.result-body {
  flex: 1;
}
.result-content {
  font-size: 13px;
  line-height: 1.45;
}
.result-meta {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
  margin-top: 4px;
}
.tag {
  font-size: 11px;
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 99px;
  padding: 1px 8px;
  color: #bbb;
}
.tag-success {
  border-color: rgba(74, 222, 128, 0.5);
  color: #86efac;
}
.tag-fail {
  border-color: rgba(251, 113, 133, 0.5);
  color: #fda4af;
}
.fact {
  font-size: 13px;
  padding: 6px 0;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}
.ok {
  margin-top: 8px;
  color: #86efac;
  font-size: 13px;
}
.dim {
  color: #8a93a6;
}
.empty-state {
  color: #8a93a6;
  font-size: 13px;
  padding: 14px 2px;
}
.error-bar {
  background: rgba(251, 113, 133, 0.12);
  border: 1px solid rgba(251, 113, 133, 0.4);
  border-radius: 8px;
  color: #fda4af;
  padding: 10px 14px;
  font-size: 13px;
}
</style>