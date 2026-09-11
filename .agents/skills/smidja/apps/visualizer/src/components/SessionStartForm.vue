<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { AlertTriangle, Rocket } from 'lucide-vue-next'
import { launchSession, models, rosters } from '../lib/chat-store'
import { modelName } from '../lib/models'
import type { RosterInfo } from '../lib/types'

const team = ref<string>('')
const orchestrator = ref<string>('')
const task = ref('')
const launching = ref(false)
const launchError = ref<string | null>(null)

const selected = computed<RosterInfo | undefined>(() => rosters.value.find((r) => r.name === team.value))

/** Whether the currently chosen orchestrator model is a weak (small) model. */
const weakChosen = computed(
  () => orchestrator.value !== '' && (models.value.find((m) => m.id === orchestrator.value)?.weak ?? false),
)

/** All models, so the caller can freely pick the orchestrator's model. */
const allModels = computed(() => models.value)

watch(selected, (r) => {
  if (!r) return
  orchestrator.value = r.orchestrator_model
})

const canRun = computed(() => team.value !== '' && task.value.trim() !== '' && !launching.value)

async function run() {
  if (!canRun.value) return
  launchError.value = null
  launching.value = true
  try {
    await launchSession({
      roster: team.value,
      orchestratorModel: orchestrator.value || undefined,
      task: task.value.trim(),
    })
    task.value = ''
  } catch (e) {
    launchError.value = (e as Error).message
  } finally {
    launching.value = false
  }
}
</script>

<template>
  <div class="start">
    <div class="title">Start a session</div>

    <label class="field">
      <span class="lab">Team</span>
      <select v-model="team">
        <option value="" disabled>Choose a team…</option>
        <option v-for="r in rosters" :key="r.name" :value="r.name">
          {{ r.name }} — {{ r.agent_count }} agents
        </option>
      </select>
    </label>

    <label v-if="selected" class="field">
      <span class="lab">Orchestrator model</span>
      <select v-model="orchestrator">
        <option value="" disabled>Choose the orchestrator model…</option>
        <option v-for="m in allModels" :key="m.id" :value="m.id">{{ modelName(m.id) }}{{ m.size_b ? ` — ${m.size_b}B` : '' }}</option>
      </select>
    </label>

    <div v-if="weakChosen" class="team-note warn">
      <AlertTriangle :size="13" />
      <span><span class="warn-txt">weak model — a 4B may struggle as orchestrator</span></span>
    </div>

    <label class="field">
      <span class="lab">Task</span>
      <textarea
        v-model="task"
        rows="3"
        placeholder="Describe what you want the factory to do…"
      />
    </label>

    <div class="tip">💡 Tip: mention ticket IDs (WOTEAMS-xx) so the run is anchored.</div>

    <button class="run" type="button" :disabled="!canRun" @click="run">
      <Rocket :size="16" /> {{ launching ? 'Launching…' : 'Run' }}
    </button>
    <div v-if="launchError" class="err">{{ launchError }}</div>
  </div>
</template>

<style scoped>
.start { display: flex; flex-direction: column; gap: 12px; }
.title {
  font-weight: 700;
  font-size: 15px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--dim);
}
.field { display: flex; flex-direction: column; gap: 5px; }
.lab { font-size: 12px; color: var(--faint); letter-spacing: 0.04em; }
select, textarea {
  background: var(--panel-2);
  border: 1px solid var(--border);
  border-radius: 8px;
  color: var(--text);
  font-family: inherit;
  font-size: 14px;
  padding: 8px 10px;
}
select:focus, textarea:focus { outline: none; border-color: rgba(255, 107, 53, 0.55); }
textarea { resize: vertical; min-height: 64px; line-height: 1.5; }

.team-note {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12.5px;
  color: var(--dim);
  background: rgba(19, 26, 38, 0.5);
  border: 1px solid var(--border-soft);
  border-radius: 8px;
  padding: 7px 9px;
}
.team-note.warn { color: var(--amber); border-color: rgba(245, 158, 11, 0.35); }
.warn-txt { color: var(--amber); }

.tip { font-size: 12px; color: var(--faint); line-height: 1.5; }

.run {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 10px 14px;
  border-radius: 10px;
  border: none;
  background: var(--accent);
  color: #1A1A1A;
  font-weight: 700;
  font-size: 15px;
  cursor: pointer;
}
.run:disabled { background: var(--panel-2); color: var(--faint); cursor: not-allowed; }
.run:not(:disabled):hover { filter: brightness(1.08); }

.err { font-size: 13px; color: var(--red); }
</style>
