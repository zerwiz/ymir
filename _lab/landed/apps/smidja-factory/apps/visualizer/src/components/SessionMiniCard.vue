<script setup lang="ts">
import { Check, Circle, ExternalLink, X } from 'lucide-vue-next'
import type { SessionLaunch } from '../lib/types'
import { modelName } from '../lib/models'

defineProps<{ launch: SessionLaunch }>()
const emit = defineEmits<{ (e: 'open', adwId: string): void }>()
</script>

<template>
  <button class="mini" type="button" @click="emit('open', launch.smidja_id)">
    <span class="dot" :class="launch.status ?? 'queued'"></span>
    <span class="mid">
      <code class="id">{{ launch.smidja_id }}</code>
      <span class="meta">{{ launch.team }} · {{ modelName(launch.model) }}</span>
    </span>
    <span class="edge">
      <Check v-if="launch.status === 'success'" class="ok" :size="15" />
      <X v-else-if="launch.status === 'fail'" class="fail" :size="15" />
      <Circle v-else class="run" :size="15" />
      <ExternalLink :size="14" class="ext" />
    </span>
  </button>
</template>

<style scoped>
.mini {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 8px 10px;
  border: 1px solid var(--border-soft);
  border-radius: 8px;
  background: rgba(19, 26, 38, 0.45);
  color: var(--text);
  cursor: pointer;
  text-align: left;
}
.mini:hover { border-color: var(--border); background: rgba(19, 26, 38, 0.7); }

.dot { width: 8px; height: 8px; border-radius: 50%; flex: none; background: var(--faint); }
.dot.success { background: var(--green); box-shadow: 0 0 8px color-mix(in srgb, var(--green) 60%, transparent); }
.dot.fail { background: var(--red); box-shadow: 0 0 8px color-mix(in srgb, var(--red) 60%, transparent); }
.dot.running { background: var(--blue); animation: pulse 1.6s ease-in-out infinite; }
@keyframes pulse { 50% { opacity: 0.4; } }

.mid { flex: 1 1 auto; min-width: 0; }
.id { display: block; font-family: var(--mono); font-size: 12.5px; color: var(--text); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.meta { display: block; font-size: 12px; color: var(--dim); margin-top: 1px; }

.edge { display: inline-flex; align-items: center; gap: 7px; flex: none; }
.ok { color: var(--green); }
.fail { color: var(--red); }
.run { color: var(--blue); }
.ext { color: var(--faint); }
.mini:hover .ext { color: var(--blue); }
</style>
