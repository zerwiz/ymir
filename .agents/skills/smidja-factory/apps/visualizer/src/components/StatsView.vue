<script setup lang="ts">
import { onMounted, ref, shallowRef } from 'vue'
import type { StatsResponse } from '../lib/types'
import { fetchStats } from '../lib/api'
import { fmtDate } from '../lib/format'

const data = shallowRef<StatsResponse | null>(null)
const apiError = ref<string | null>(null)
const loaded = ref(false)
const selectedModel = ref<string>('gpt-4o')

const selected = () =>
  data.value?.vendor_catalog.find((m) => m.id === selectedModel.value) ??
  data.value?.vendor_catalog[0] ??
  null

const tierGroups = (models: StatsResponse['vendor_catalog']) => [1, 2, 3].map((t) => ({
  label: models.find((m) => m.tier === t)?.tier_label ?? `Tier ${t}`,
  models: models.filter((m) => m.tier === t),
}))

async function load() {
  try {
    data.value = await fetchStats()
    // Default the vendor picker to the catalog's first model instead of a
    // stale hardcoded id ('gpt-4o') that may not exist.
    if (data.value?.vendor_catalog?.length) {
      selectedModel.value = data.value.vendor_catalog[0].id
    }
    apiError.value = null
  } catch (err) {
    apiError.value = err instanceof Error ? err.message : String(err)
  } finally {
    loaded.value = true
  }
}
onMounted(() => void load())

const pct = (n: number) => `${(n * 100).toFixed(1)}%`
const M = (n: number) => `${(n / 1_000_000).toFixed(3)}M`
const usd = (n: number) => `$${n.toFixed(4)}`
const usd2 = (n: number) => `$${n.toFixed(2)}`
const successRate = () => {
  const t = data.value?.totals
  if (!t || !t.runs) return '—'
  return pct(t.success / t.runs)
}
const providerShare = (kind: 'local' | 'online') => {
  const p = data.value?.providers
  if (!p) return '—'
  const total = p.local.tokens + p.online.tokens
  if (!total) return '—'
  return pct(p[kind].tokens / total)
}
</script>

<template>
  <div class="stats">
    <div v-if="apiError" class="error-bar">stats unreachable — {{ apiError }}</div>

    <div class="head">
      <div class="title">Statistics <span class="dim">— every run, tokens, cost, savings</span></div>
      <div v-if="data" class="dim">generated {{ fmtDate(data.generated_at) }}</div>
    </div>

    <template v-if="data">
      <!-- totals -->
      <section class="panel">
        <div class="panel-title">Runs</div>
        <div class="stat-grid">
          <div class="stat"><b>{{ data.totals.runs }}</b><span>total runs</span></div>
          <div class="stat ok"><b>{{ data.totals.success }}</b><span>success</span></div>
          <div class="stat bad"><b>{{ data.totals.fail }}</b><span>fail</span></div>
          <div class="stat live"><b>{{ data.totals.running }}</b><span>running</span></div>
          <div class="stat"><b>{{ successRate() }}</b><span>success rate</span></div>
          <div class="stat"><b>{{ data.totals.tokens.toLocaleString() }}</b><span>tokens</span></div>
          <div class="stat"><b>{{ usd(data.totals.cost) }}</b><span>actual cost</span></div>
        </div>
      </section>

      <!-- token optimization -->
      <section class="panel">
        <div class="panel-title">Token optimization <span class="dim">(LLM token metrics)</span></div>
        <div class="stat-grid">
          <div class="stat"><b>{{ M(data.usage.input) }}</b><span>uncached input</span></div>
          <div class="stat"><b>{{ M(data.usage.output) }}</b><span>output</span></div>
          <div class="stat good"><b>{{ M(data.usage.cache_read) }}</b><span>cache read</span></div>
          <div class="stat"><b>{{ M(data.usage.cache_write) }}</b><span>cache write</span></div>
          <div class="stat"><b>{{ M(data.usage.total) }}</b><span>total tokens</span></div>
          <div class="stat good"><b>{{ pct(data.cache_hit_ratio) }}</b><span>cache-hit ratio (CHR)</span></div>
          <div class="stat"><b>{{ pct(data.avg_cache_hit_per_run) }}</b><span>avg CHR per run</span></div>
        </div>
      </section>

      <!-- local vs online -->
      <section class="panel">
        <div class="panel-title">Model provider <span class="dim">(local = own hardware — pi on LM Studio / Ollama — vs online cloud APIs)</span></div>
        <div class="stat-grid">
          <div class="stat good"><b>{{ M(data.providers.local.tokens) }}</b><span>local tokens · {{ providerShare('local') }} of all</span></div>
          <div class="stat bad"><b>{{ M(data.providers.online.tokens) }}</b><span>online tokens · {{ providerShare('online') }} of all</span></div>
          <div class="stat good"><b>{{ data.providers.local.events }}</b><span>local agent calls</span></div>
          <div class="stat bad"><b>{{ data.providers.online.events }}</b><span>online agent calls</span></div>
          <div class="stat good"><b>{{ usd(data.providers.local.cost) }}</b><span>local cost</span></div>
          <div class="stat bad"><b>{{ usd(data.providers.online.cost) }}</b><span>online cost</span></div>
          <div class="stat good"><b>{{ data.providers.local.sessions }}</b><span>local sessions</span></div>
          <div class="stat bad"><b>{{ data.providers.online.sessions }}</b><span>online sessions</span></div>
        </div>
        <div class="split-bar" :title="`local ${providerShare('local')} / online ${providerShare('online')}`">
          <div class="split-local" :style="{ width: providerShare('local') }"></div>
          <div class="split-online" :style="{ width: providerShare('online') }"></div>
        </div>
        <div class="split-legend">
          <span><i class="dot dot-local"></i>local (pi, LM Studio, Ollama) — {{ providerShare('local') }}</span>
          <span><i class="dot dot-online"></i>online (cloud APIs) — {{ providerShare('online') }}</span>
        </div>
        <table v-if="data.providers.per_model.length" class="tbl provider-tbl">
          <thead>
            <tr><th>Model</th><th>Agent</th><th>Kind</th><th class="num">Calls</th><th class="num">Tokens</th><th class="num">Cost</th></tr>
          </thead>
          <tbody>
            <tr v-for="m in data.providers.per_model" :key="m.model">
              <td><b>{{ m.model }}</b></td>
              <td>{{ m.coding_agent ?? '—' }}</td>
              <td><span class="badge" :class="m.kind">{{ m.kind }}</span></td>
              <td class="num">{{ m.events }}</td>
              <td class="num">{{ M(m.tokens) }}</td>
              <td class="num">{{ usd(m.cost) }}</td>
            </tr>
          </tbody>
        </table>
      </section>

      <!-- vendor comparison -->
      <section class="panel">
        <div class="panel-title">Commercial comparison <span class="dim">(what these runs would cost on vendors, with caching)</span></div>
        <div class="vendor-pick">
          <label for="vendor-model">Model</label>
          <select id="vendor-model" v-model="selectedModel" class="vendor-select" :disabled="!data">
            <optgroup v-for="g in tierGroups(data.vendor_catalog)" :key="g.label" :label="g.label">
              <option v-for="m in g.models" :key="m.id" :value="m.id">
                #{{ m.rank }} {{ m.name }} — {{ m.provider }}
              </option>
            </optgroup>
          </select>
          <span v-if="selected()" class="dim vendor-rates">
            rates: ${{ selected()!.input_price.toFixed(2) }} in / ${{ selected()!.cache_price.toFixed(2) }} cache / ${{ selected()!.output_price.toFixed(2) }} out per 1M
          </span>
        </div>
        <table v-if="selected()" class="tbl">
          <thead>
            <tr>
              <th>Model</th>
              <th class="num">Cached cost</th>
              <th class="num">Total cost</th>
              <th class="num">Savings vs actual</th>
              <th class="num">Saved</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>
                <b>{{ selected()!.name }}</b>
                <span class="dim"> · {{ selected()!.provider }} · #{{ selected()!.rank }}</span>
              </td>
              <td class="num">{{ usd2(selected()!.cached_cost) }}</td>
              <td class="num">{{ usd2(selected()!.total_cost) }}</td>
              <td class="num good">+{{ usd2(selected()!.savings) }}</td>
              <td class="num good">{{ pct(selected()!.savings_pct) }}</td>
            </tr>
          </tbody>
        </table>
      </section>

      <!-- per chain -->
      <section class="panel">
        <div class="panel-title">By chain</div>
        <table class="tbl">
          <thead><tr><th>Chain</th><th class="num">Runs</th><th class="num">Success</th><th class="num">Rate</th><th class="num">Tokens</th><th class="num">Cost</th></tr></thead>
          <tbody>
            <tr v-for="c in data.by_chain" :key="c.chain">
              <td>{{ c.chain }}</td>
              <td class="num">{{ c.runs }}</td>
              <td class="num">{{ c.success }}</td>
              <td class="num">{{ c.runs ? pct(c.success / c.runs) : '—' }}</td>
              <td class="num">{{ c.tokens.toLocaleString() }}</td>
              <td class="num">{{ usd(c.cost) }}</td>
            </tr>
          </tbody>
        </table>
      </section>

      <!-- per model / smidja -->
      <section class="panel">
        <div class="panel-title">By workflow</div>
        <table class="tbl">
          <thead><tr><th>Workflow</th><th class="num">Runs</th><th class="num">Success</th><th class="num">Rate</th><th class="num">Tokens</th><th class="num">Cost</th></tr></thead>
          <tbody>
            <tr v-for="m in data.by_model" :key="m.model">
              <td>{{ m.model }}</td>
              <td class="num">{{ m.runs }}</td>
              <td class="num">{{ m.success }}</td>
              <td class="num">{{ m.runs ? pct(m.success / m.runs) : '—' }}</td>
              <td class="num">{{ m.tokens.toLocaleString() }}</td>
              <td class="num">{{ usd(m.cost) }}</td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>
    <div v-else-if="!loaded && !apiError" class="empty-state">loading stats…</div>
  </div>
</template>

<style scoped>
.stats {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px 24px 40px;
}
.head {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.title {
  font-size: 22px;
  font-weight: 600;
}
.panel {
  background: rgba(16, 21, 32, 0.6);
  border: 1px solid color-mix(in srgb, var(--accent) 12%, transparent);
  border-radius: 12px;
  padding: 14px 16px;
}
.panel-title {
  font-weight: 600;
  margin-bottom: 12px;
}
.stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 12px;
}
.stat {
  background: rgba(11, 15, 24, 0.6);
  border: 1px solid color-mix(in srgb, var(--text) 7%, transparent);
  border-radius: 10px;
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.stat b {
  font-size: 22px;
  color: var(--accent);
  font-variant-numeric: tabular-nums;
}
.stat span {
  font-size: 12px;
  color: var(--dim);
}
.stat.ok b { color: var(--green); }
.stat.bad b { color: var(--red); }
.stat.live b { color: var(--accent); }
.stat.good b { color: var(--green); }
.good { color: var(--green); }

.vendor-pick {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}
.vendor-pick label {
  font-size: 12px;
  font-weight: 600;
  color: var(--dim);
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.vendor-rates {
  font-size: 12px;
}
.vendor-select {
  background: rgba(11, 15, 24, 0.8);
  border: 1px solid color-mix(in srgb, var(--accent) 25%, transparent);
  border-radius: 8px;
  color: var(--text);
  font-size: 13px;
  padding: 7px 10px;
  min-width: 300px;
  max-width: 100%;
}
.vendor-select:focus {
  outline: none;
  border-color: var(--accent);
}

.split-bar {
  display: flex;
  height: 10px;
  border-radius: 6px;
  overflow: hidden;
  background: color-mix(in srgb, var(--text) 7%, transparent);
  margin: 2px 0 8px;
}
.split-local {
  background: linear-gradient(90deg, var(--green), var(--green));
  transition: width 0.3s ease;
}
.split-online {
  background: linear-gradient(90deg, var(--accent), var(--red));
  transition: width 0.3s ease;
}
.split-legend {
  display: flex;
  gap: 16px;
  font-size: 12px;
  color: var(--dim);
  margin-bottom: 12px;
  flex-wrap: wrap;
}
.split-legend .dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 4px;
}
.dot-local { background: var(--green); }
.dot-online { background: var(--accent); }
.provider-tbl { margin-top: 4px; }
.badge {
  display: inline-block;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  border-radius: 999px;
  padding: 2px 8px;
}
.badge.local { color: var(--green); background: color-mix(in srgb, var(--green) 12%, transparent); border: 1px solid color-mix(in srgb, var(--green) 30%, transparent); }
.badge.online { color: var(--accent); background: color-mix(in srgb, var(--amber) 12%, transparent); border: 1px solid color-mix(in srgb, var(--amber) 30%, transparent); }
.badge.unknown { color: var(--dim); background: color-mix(in srgb, var(--dim) 12%, transparent); border: 1px solid color-mix(in srgb, var(--dim) 30%, transparent); }

.tbl {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.tbl th, .tbl td {
  text-align: left;
  padding: 7px 10px;
  border-bottom: 1px solid color-mix(in srgb, var(--text) 6%, transparent);
  vertical-align: top;
}
.tbl th {
  color: var(--dim);
  font-weight: 600;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  white-space: nowrap;
}
.tbl .num {
  text-align: right;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.dim { color: var(--dim); }
.empty-state { color: var(--dim); font-size: 13px; padding: 14px 2px; }
.error-bar {
  background: rgba(251, 113, 133, 0.12);
  border: 1px solid rgba(251, 113, 133, 0.4);
  border-radius: 8px;
  color: var(--red);
  padding: 10px 14px;
  font-size: 13px;
}
</style>