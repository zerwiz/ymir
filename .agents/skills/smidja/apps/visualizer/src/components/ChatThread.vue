<script setup lang="ts">
import { nextTick, onMounted, ref, watch } from 'vue'
import { Bot, LoaderCircle, TriangleAlert, User } from 'lucide-vue-next'
import { renderMarkdown } from '../lib/markdown'
import { modelName } from '../lib/models'
import type { ChatMessage } from '../lib/types'
import ToolCallCard from './ToolCallCard.vue'

const props = defineProps<{ messages: ChatMessage[] }>()
const emit = defineEmits<{ (e: 'launch-click', adwId: string): void }>()

const scrollEl = ref<HTMLElement | null>(null)
const stick = ref(true)

function scrollToBottom() {
  if (!stick.value || !scrollEl.value) return
  scrollEl.value.scrollTop = scrollEl.value.scrollHeight
}

onMounted(scrollToBottom)
watch(() => props.messages.length, () => nextTick(scrollToBottom))
watch(
  () => props.messages.map((m) => m.streaming),
  () => nextTick(scrollToBottom),
)

function onScroll() {
  const el = scrollEl.value
  if (!el) return
  stick.value = el.scrollHeight - el.scrollTop - el.clientHeight < 80
}
</script>

<template>
  <div class="thread" ref="scrollEl" @scroll="onScroll">
    <div class="list">
      <template v-for="m in messages" :key="m.id">
        <!-- Centered system / error notes -->
        <div v-if="m.role === 'system' || m.role === 'error'" class="sys" :class="{ err: m.role === 'error' }">
          <span class="sys-pill"><TriangleAlert v-if="m.role === 'error'" :size="13" />{{ m.content }}</span>
        </div>

        <!-- User bubble, right-aligned -->
        <div v-else-if="m.role === 'user'" class="row user-row">
          <div class="bubble user">
            <div class="who"><User :size="13" /> You</div>
            <div class="text">{{ m.content }}</div>
          </div>
        </div>

        <!-- Kaia bubble, left-aligned with model footnote -->
        <div v-else class="row kaia-row">
          <div class="bubble kaia">
            <div class="who kaia-who">
              <Bot :size="14" /> Kaia
              <span v-if="m.model" class="model" :title="m.model">{{ modelName(m.model) }}</span>
            </div>
            <!-- eslint-disable-next-line vue/no-v-html -->
            <div class="text md" v-html="renderMarkdown(m.content)" />
            <span v-if="m.streaming" class="streaming">
              <LoaderCircle :size="13" class="spin" /> thinking…
            </span>
            <ToolCallCard v-for="c in m.tool_calls" :key="c.tool" :call="c" :inline-preview="true" />
            <div v-if="m.session_launch" class="launch">
              <div class="launch-head">
                <span class="launch-ico">🚀</span>
                <div>
                  <div class="launch-title">Session launched</div>
                  <div class="launch-sub">
                    <code>{{ m.session_launch.smidja_id }}</code> · {{ m.session_launch.team }} ·
                    {{ modelName(m.session_launch.model) }}
                  </div>
                </div>
                <span class="launch-status" :class="m.session_launch.status ?? ''">
                  {{ m.session_launch.status ?? 'queued' }}
                </span>
              </div>
              <button class="launch-link" type="button" @click="emit('launch-click', m.session_launch!.smidja_id)">
                View in Trace UI →
              </button>
            </div>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.thread {
  flex: 1 1 auto;
  overflow-y: auto;
  padding: 20px 24px;
}
.list {
  max-width: 940px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.sys {
  display: flex;
  justify-content: center;
}
.sys-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 14px;
  border-radius: 999px;
  background: rgba(19, 26, 38, 0.6);
  border: 1px solid var(--border-soft);
  color: var(--dim);
  font-size: 14px;
}
.sys.err .sys-pill {
  color: var(--red);
  border-color: rgba(255, 111, 103, 0.4);
  background: rgba(255, 111, 103, 0.08);
}

.row { display: flex; }
.user-row { justify-content: flex-end; }
.kaia-row { justify-content: flex-start; }

.bubble {
  max-width: min(760px, 78%);
  border-radius: 14px;
  padding: 11px 15px;
}
.bubble.user {
  background: linear-gradient(180deg, rgba(255, 107, 53, 0.18), rgba(255, 107, 53, 0.08));
  border: 1px solid rgba(255, 107, 53, 0.35);
  border-top-right-radius: 4px;
}
.bubble.kaia {
  background: var(--surface);
  border: 1px solid var(--border-soft);
  border-top-left-radius: 4px;
}

.who {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12.5px;
  letter-spacing: 0.04em;
  color: var(--faint);
  margin-bottom: 4px;
}
.user .who { color: var(--accent); }
.kaia-who { color: var(--violet); }
.model {
  margin-left: auto;
  font-family: var(--mono);
  font-size: 11px;
  color: var(--faint);
  background: rgba(11, 15, 24, 0.6);
  border-radius: 999px;
  padding: 1px 8px;
}

.text { font-size: 15.5px; line-height: 1.6; color: var(--text); white-space: pre-wrap; word-break: break-word; }
.text.md :deep(p) { margin: 0 0 8px; }
.text.md :deep(p:last-child) { margin-bottom: 0; }
.text.md :deep(pre) { font-size: 13px; }
.text.md :deep(code) { font-family: var(--mono); font-size: 13px; }

.streaming {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--dim);
  font-size: 14px;
  margin-top: 6px;
}
.spin { animation: spin 1.1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.launch {
  margin-top: 10px;
  border: 1px solid var(--border-soft);
  border-left: 3px solid var(--accent);
  border-radius: 8px;
  padding: 10px 12px;
  background: rgba(19, 26, 38, 0.55);
}
.launch-head { display: flex; align-items: center; gap: 10px; }
.launch-ico { font-size: 18px; flex: none; }
.launch-title { font-weight: 700; font-size: 14px; }
.launch-sub { font-size: 13px; color: var(--dim); margin-top: 2px; }
.launch-sub code { font-family: var(--mono); font-size: 12.5px; }
.launch-status {
  margin-left: auto;
  font-size: 12px;
  font-family: var(--mono);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 2px 9px;
  border-radius: 999px;
  border: 1px solid var(--border-soft);
  color: var(--amber);
}
.launch-status.running { color: var(--blue); border-color: rgba(108, 182, 255, 0.4); }
.launch-status.success { color: var(--green); border-color: rgba(74, 222, 128, 0.4); }
.launch-status.fail { color: var(--red); border-color: rgba(255, 111, 103, 0.4); }
.launch-link {
  margin-top: 9px;
  background: transparent;
  border: none;
  color: var(--blue);
  font-size: 13px;
  cursor: pointer;
  padding: 0;
}
.launch-link:hover { text-decoration: underline; }
</style>
