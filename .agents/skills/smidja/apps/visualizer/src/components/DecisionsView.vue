<script setup lang="ts">
import { onMounted, ref, shallowRef } from 'vue'
import type { DecisionsResponse } from '../lib/types'
import { fetchDecisions } from '../lib/api'
import { fmtDate } from '../lib/format'

const data = shallowRef<DecisionsResponse | null>(null)
const apiError = ref<string | null>(null)
const loaded = ref(false)

async function load() {
  try {
    data.value = await fetchDecisions()
    apiError.value = null
  } catch (err) {
    apiError.value = err instanceof Error ? err.message : String(err)
  } finally {
    loaded.value = true
  }
}
onMounted(() => void load())

function clsClass(cls: string): string {
  if (cls.includes('JSON') || cls.includes('HALLUCINATED')) return 'cls cls-warn'
  if (cls === 'EMPTY_COMMIT' || cls === 'STOPPED') return 'cls cls-mild'
  return 'cls'
}

function fmtRuns(runs: string[]): string {
  return runs.length > 6 ? `${runs.slice(0, 6).join(' · ')} · +${runs.length - 6} more` : runs.join(' · ')
}
</script>

<template>
  <div class="decisions">
    <div v-if="apiError" class="error-bar">decisions unreachable — {{ apiError }}</div>

    <div class="head">
      <div class="title">Decisions <span class="dim">— what to change to make the factory work</span></div>
      <div v-if="data" class="stat-row">
        <span class="stat"><b>{{ data.total_failed }}</b> failed runs</span>
        <span class="stat"><b>{{ data.decisions.length }}</b> diagnosis × model buckets</span>
        <span class="dim">generated {{ fmtDate(data.generated_at) }}</span>
      </div>
    </div>

    <div v-if="data && !data.decisions.length" class="empty-state">
      no failures recorded — the factory has nothing to improve yet
    </div>

    <div v-if="data && data.decisions.length" class="cards">
      <div v-for="(d, i) in data.decisions" :key="i" class="card">
        <div class="card-top">
          <span :class="clsClass(d.diagnosis)">{{ d.diagnosis }}</span>
          <span class="count">×{{ d.count }}</span>
        </div>
        <div class="model" :title="d.model">{{ d.model }}</div>
        <div class="fix">fix: {{ d.fix }}</div>
        <div class="meta">
          <span class="dim">last {{ fmtDate(d.last_seen) }}</span>
        </div>
        <div class="runs">{{ fmtRuns(d.runs) }}</div>
      </div>
    </div>

    <div v-else-if="!loaded && !apiError" class="empty-state">loading decisions…</div>
  </div>
</template>

<style scoped>
.decisions {
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

.cards {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
  gap: 14px;
}
.card {
  background: rgba(16, 21, 32, 0.6);
  border: 1px solid rgba(255, 143, 92, 0.14);
  border-radius: 12px;
  padding: 14px 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.card-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.cls {
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.03em;
  border-radius: 99px;
  padding: 3px 10px;
  background: rgba(255, 143, 92, 0.12);
  color: #ffb28a;
}
.cls-warn {
  background: rgba(255, 111, 103, 0.16);
  color: #ff9a94;
}
.cls-mild {
  background: rgba(148, 163, 255, 0.14);
  color: #b3c0ff;
}
.count {
  font-size: 20px;
  font-weight: 700;
  color: #ff8f5c;
}
.model {
  font-family: var(--mono, monospace);
  font-size: 13px;
  color: #8a93a6;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.fix {
  font-size: 13px;
  line-height: 1.5;
}
.meta {
  font-size: 12px;
}
.runs {
  font-family: var(--mono, monospace);
  font-size: 11px;
  color: #8a93a6;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
  padding-top: 8px;
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