<script setup lang="ts">
import { computed, ref } from 'vue'
import { Check, ChevronDown, CircleX, TerminalSquare, Wrench } from 'lucide-vue-next'
import type { ChatToolCall } from '../lib/types'

const props = defineProps<{
  call: ChatToolCall
  inlinePreview?: boolean
}>()

const open = ref(props.call.expanded ?? false)
const prettyArgs = computed(() => JSON.stringify(props.call.args, null, 2))

// Preview: first 120 chars of result, shown inline when not expanded
const resultPreview = computed(() => {
  if (!props.call.result || open.value) return ''
  const text = String(props.call.result).trim()
  return text.length > 120 ? text.slice(0, 120) + '…' : text
})
</script>

<template>
  <div class="tool-card" :class="{ ok: call.ok !== false, fail: call.ok === false }">
    <button class="head" type="button" @click="open = !open" :aria-expanded="open">
      <span class="t-icon">
        <TerminalSquare :size="15" :stroke-width="2.2" />
      </span>
      <code class="t-name">{{ call.tool }}</code>
      <span v-if="call.ms != null" class="t-ms">{{ call.ms }}ms</span>
      <span class="t-status">
        <Check v-if="call.ok !== false" class="ok-ico" :size="15" />
        <CircleX v-else class="fail-ico" :size="15" />
      </span>
      <ChevronDown class="t-chev" :class="{ flip: open }" :size="16" />
    </button>

    <div v-if="open" class="body">
      <div class="row">
        <span class="lab">args</span>
        <pre class="mono"><code>{{ prettyArgs }}</code></pre>
      </div>
      <div v-if="call.result" class="row">
        <span class="lab">result</span>
        <span class="res" :class="{ fail: call.ok === false }">{{ call.result }}</span>
      </div>
      <a v-if="call.link" class="row link-row" :href="call.link">
        <Wrench :size="13" /> open in trace →
      </a>
    </div>

    <!-- Inline preview: show truncated result without expanding -->
    <div v-else-if="inlinePreview && resultPreview" class="inline-preview" :class="{ fail: call.ok === false }">
      {{ resultPreview }}
    </div>
  </div>
</template>

<style scoped>
.tool-card {
  margin: 10px 0 4px;
  border: 1px solid var(--border-soft);
  border-left: 3px solid var(--violet);
  border-radius: 8px;
  background: rgba(19, 26, 38, 0.55);
  overflow: hidden;
}
.tool-card.ok { border-left-color: var(--green); }
.tool-card.fail { border-left-color: var(--red); }

.head {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 7px 12px;
  background: transparent;
  border: none;
  color: var(--text);
  cursor: pointer;
  font-size: 15px;
  text-align: left;
}
.head:hover { background: color-mix(in srgb, var(--text) 3%, transparent); }

.t-icon { display: inline-flex; color: var(--violet); flex: none; }
.tool-card.ok .t-icon { color: var(--green); }
.tool-card.fail .t-icon { color: var(--red); }

.t-name {
  font-family: var(--mono);
  font-size: 13px;
  color: var(--text);
  flex: 1 1 auto;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.t-ms { color: var(--faint); font-family: var(--mono); font-size: 12px; flex: none; }
.t-status { display: inline-flex; flex: none; }
.ok-ico { color: var(--green); }
.fail-ico { color: var(--red); }
.t-chev { color: var(--faint); flex: none; transition: transform 0.15s ease; }
.t-chev.flip { transform: rotate(180deg); }

.body { padding: 2px 12px 10px; display: flex; flex-direction: column; gap: 8px; }
.row { display: flex; flex-direction: column; gap: 3px; }
.lab {
  font-family: var(--mono);
  font-size: 11px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--faint);
}
.mono {
  margin: 0;
  padding: 8px 10px;
  background: var(--panel-3);
  border: 1px solid var(--border-soft);
  border-radius: 6px;
  font-family: var(--mono);
  font-size: 12.5px;
  line-height: 1.5;
  color: var(--text);
  white-space: pre-wrap;
  word-break: break-word;
}
.res { font-size: 14px; color: var(--green); }
.res.fail { color: var(--red); }
.link-row {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--blue);
  font-size: 13px;
  width: fit-content;
}
.inline-preview {
  padding: 6px 12px 8px;
  font-size: 13px;
  color: var(--green);
  background: color-mix(in srgb, var(--green) 8%, transparent);
  border-top: 1px solid color-mix(in srgb, var(--green) 20%, transparent);
  border-radius: 0 0 8px 8px;
  font-family: var(--mono);
  white-space: pre-wrap;
  word-break: break-word;
  max-height: 3em;
  overflow: hidden;
}
.inline-preview.fail {
  color: var(--red);
  background: color-mix(in srgb, var(--red) 8%, transparent);
  border-top-color: color-mix(in srgb, var(--red) 20%, transparent);
}
</style>
