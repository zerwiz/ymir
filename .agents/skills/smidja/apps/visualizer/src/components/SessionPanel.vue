<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { Check, Circle, LoaderCircle, Pause, Play, Send, Square, X } from 'lucide-vue-next'
import {
  activeSession,
  controlActive,
  liveStats,
  loadPastSessions,
  pastSessions,
  refreshLiveStats,
  rosters,
  side,
  steerActive,
  syncAutoAttach,
} from '../lib/chat-store'
import { modelName } from '../lib/models'
import SessionStartForm from './SessionStartForm.vue'
import SessionMiniCard from './SessionMiniCard.vue'

const emit = defineEmits<{ (e: 'open', adwId: string): void }>()

const steerText = ref('')
const steerSent = ref(false)

/** Poll for detached/terminal-launched runs so they auto-appear in the chat,
 * and refresh the active session's real cost/tokens/ladder from the trace db. */
let poll: ReturnType<typeof setInterval> | null = null
onMounted(() => {
  void loadPastSessions()
  void refreshLiveStats()
  poll = setInterval(() => {
    void syncAutoAttach()
    void refreshLiveStats()
  }, 5000)
})
onBeforeUnmount(() => {
  if (poll) clearInterval(poll)
})

/** Progress ladder for the live panel — REAL phases from the trace db, with the
 * running phase marked. Falls back to a static plan/build/test ladder only
 * when the session has no phase rows yet (still in request/orchestrate). */
const ladder = computed(() => {
  const s = activeSession.value
  if (!s) return []
  if (liveStats.value?.steps?.length) {
    return liveStats.value.steps.map((step) => ({
      name: step.name,
      status: step.status === 'running' ? 'running' : step.status === 'success' ? 'success' : step.status === 'fail' ? 'fail' : 'queued',
      now: step.status === 'running',
    }))
  }
  const steps = ['plan', 'build', 'test', 'review', 'document']
  const running = s.status === 'running'
  return steps.map((name, i) => ({
    name,
    status: running && i === 1 ? 'running' : i < 1 ? 'success' : 'queued',
    now: running && i === 1,
  }))
})

/** Real money/token figures from the trace db; dashes until the first poll. */
const liveCost = computed(() => liveStats.value?.cost != null ? `$${liveStats.value.cost.toFixed(4)}` : '—')
const liveTokens = computed(() => liveStats.value?.tokens != null ? liveStats.value.tokens.toLocaleString() : '—')
const liveToolCalls = computed(() => liveStats.value?.toolCalls != null ? String(liveStats.value.toolCalls) : '—')

/** Past sessions come from the trace db via the existing sessions list. */

const teamLabel = computed(() =>
  rosters.value.find((r) => r.name === activeSession.value?.team)?.label ?? activeSession.value?.team ?? '',
)

async function steer() {
  const v = steerText.value.trim()
  if (!v) return
  await steerActive(v)
  steerSent.value = true
  steerText.value = ''
  setTimeout(() => (steerSent.value = false), 1500)
}
</script>

<template>
  <aside class="panel">
    <!-- ── Running state: live activity ladder + controls ─────────────── -->
    <template v-if="side.panel === 'running' && activeSession">
      <div class="panel-h">
        <span class="pill running">active</span>
        <span class="panel-title">session</span>
      </div>
      <code class="smidja">{{ activeSession.smidja_id }}</code>
      <div class="meta">{{ teamLabel }} · {{ modelName(activeSession.model) }}</div>

      <div class="ladder">
        <div v-for="step in ladder" :key="step.name" class="step" :class="step.status">
          <span class="rail">
            <Check v-if="step.status === 'success'" :size="14" />
            <LoaderCircle v-else-if="step.status === 'running'" :size="14" class="spin" />
            <X v-else-if="step.status === 'fail'" :size="12" class="rail-fail" />
            <Circle v-else :size="12" />
          </span>
          <span class="step-name">{{ step.name }}</span>
          <span v-if="step.now" class="now">now</span>
        </div>
      </div>

      <div class="sum-grid">
        <div class="sum"><span class="k">cost</span><span class="v">{{ liveCost }}</span></div>
        <div class="sum"><span class="k">tokens</span><span class="v">{{ liveTokens }}</span></div>
        <div class="sum"><span class="k">tools</span><span class="v">{{ liveToolCalls }}</span></div>
      </div>

      <div class="controls">
        <button class="ctl stop" type="button" title="Stop run" @click="controlActive('stop')"><Square :size="13" /> Stop</button>
        <button class="ctl" type="button" title="Pause (hold mid-run)" @click="controlActive('pause')"><Pause :size="13" /></button>
        <button class="ctl" type="button" title="Resume" @click="controlActive('resume')"><Play :size="13" /></button>
      </div>

      <div class="steer">
        <div class="lab">Steer mid-run</div>
        <div class="steer-row">
          <input v-model="steerText" placeholder="Guidance for the next agent…" @keydown.enter="steer" />
          <button class="s-btn" type="button" title="Send steer" @click="steer"><Send :size="15" /></button>
        </div>
        <div v-if="steerSent" class="steer-ok">✓ queued for the next agent call</div>
      </div>

      <button class="open-trace" type="button" @click="emit('open', activeSession.smidja_id)">Open trace →</button>
    </template>

    <!-- ── Completed / idle: summary of last run + start form ─────────── -->
    <template v-else>
      <div class="panel-h">
        <span class="pill complete">ready</span>
        <span class="panel-title">{{ activeSession ? 'completed' : 'orchestrator' }}</span>
      </div>

      <div v-if="activeSession && side.panel === 'completed'" class="summary">
        <code class="smidja">{{ activeSession.smidja_id }}</code>
        <div class="meta">{{ teamLabel }} · {{ modelName(activeSession.model) }}</div>
        <div class="sum-grid">
          <div class="sum"><span class="k">status</span><span class="v" :class="activeSession.status === 'fail' ? 'v-bad' : 'v ok'">{{ activeSession.status === 'fail' ? 'fail' : 'success' }}</span></div>
          <div class="sum"><span class="k">cost</span><span class="v">{{ liveCost }}</span></div>
          <div class="sum"><span class="k">tokens</span><span class="v">{{ liveTokens }}</span></div>
        </div>
        <button class="open-trace" type="button" @click="emit('open', activeSession.smidja_id)">Full trace →</button>
      </div>

      <SessionStartForm />

      <div class="sep-line"></div>
      <div class="past-h">Past sessions</div>
      <div class="past">
        <SessionMiniCard v-for="s in pastSessions" :key="s.smidja_id" :launch="s" @open="emit('open', $event)" />
      </div>
    </template>
  </aside>
</template>

<style scoped>
.panel {
  width: 320px;
  flex: none;
  display: flex;
  flex-direction: column;
  gap: 12px;
  border-left: 1px solid var(--border-soft);
  padding: 18px;
  background: rgba(11, 15, 24, 0.4);
  overflow-y: auto;
}

.panel-h { display: flex; align-items: center; gap: 8px; }
.panel-title { font-size: 12px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--faint); }
.pill {
  font-size: 11px;
  font-family: var(--mono);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 2px 8px;
  border-radius: 999px;
  border: 1px solid var(--border-soft);
  color: var(--dim);
}
.pill.running { color: var(--blue); border-color: rgba(108, 182, 255, 0.4); background: rgba(108, 182, 255, 0.08); }
.pill.complete { color: var(--green); border-color: rgba(74, 222, 128, 0.4); background: rgba(74, 222, 128, 0.08); }

.smidja { font-family: var(--mono); font-size: 14px; color: var(--text); }
.meta { font-size: 13px; color: var(--dim); }

/* activity ladder */
.ladder { display: flex; flex-direction: column; gap: 2px; margin-top: 6px; }
.step { display: flex; align-items: center; gap: 9px; padding: 5px 6px; border-radius: 6px; }
.rail { width: 18px; display: inline-flex; align-items: center; justify-content: center; color: var(--faint); flex: none; }
.step.success .rail { color: var(--green); }
.step.running .rail { color: var(--blue); }
.step.fail .rail { color: var(--red); }
.step.running { background: rgba(108, 182, 255, 0.06); }
.step-name { font-size: 13.5px; color: var(--dim); flex: 1; }
.step.success .step-name { color: var(--text); }
.now { font-size: 10px; font-family: var(--mono); text-transform: uppercase; color: var(--blue); }
.spin { animation: spin 1.1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.controls { display: flex; gap: 7px; margin-top: 6px; }
.ctl {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 12px;
  border-radius: 8px;
  border: 1px solid var(--border);
  background: var(--panel-2);
  color: var(--dim);
  font-size: 13px;
  cursor: pointer;
}
.ctl:hover { color: var(--text); border-color: var(--border); }
.ctl.stop { color: var(--red); border-color: rgba(255, 111, 103, 0.4); }
.ctl.stop:hover { background: rgba(255, 111, 103, 0.1); }

.steer { display: flex; flex-direction: column; gap: 6px; margin-top: 6px; }
.lab { font-size: 11px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--faint); }
.steer-row { display: flex; gap: 6px; }
.steer-row input {
  flex: 1;
  background: var(--panel-2);
  border: 1px solid var(--border);
  border-radius: 8px;
  color: var(--text);
  font-size: 13px;
  padding: 7px 9px;
}
.steer-row input:focus { outline: none; border-color: rgba(255, 107, 53, 0.55); }
.s-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  border-radius: 8px;
  border: none;
  background: var(--accent);
  color: #1A1A1A;
  cursor: pointer;
}
.s-btn:hover { filter: brightness(1.08); }
.steer-ok { font-size: 12px; color: var(--green); }

.open-trace {
  margin-top: 4px;
  background: transparent;
  border: none;
  color: var(--blue);
  font-size: 13px;
  cursor: pointer;
  text-align: left;
  padding: 0;
}
.open-trace:hover { text-decoration: underline; }

.summary { display: flex; flex-direction: column; gap: 8px; }
.sum-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.sum { display: flex; flex-direction: column; gap: 2px; background: rgba(19, 26, 38, 0.5); border: 1px solid var(--border-soft); border-radius: 8px; padding: 7px 9px; }
.k { font-size: 10px; text-transform: uppercase; letter-spacing: 0.05em; color: var(--faint); }
.v { font-family: var(--mono); font-size: 12.5px; color: var(--text); }
.v.ok { color: var(--green); }
.v-bad { color: var(--red); }

.sep-line { height: 1px; background: var(--border-soft); margin: 6px 0; }
.past-h { font-size: 12px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--faint); }
.past { display: flex; flex-direction: column; gap: 7px; }
</style>
