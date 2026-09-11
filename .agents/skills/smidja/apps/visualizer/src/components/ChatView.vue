<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { navigate } from '../lib/router'
import {
  chatModel,
  chatModels,
  chatSessions,
  deleteChat,
  init,
  loadChatSessions,
  loadHistory,
  messages,
  newChat,
  pending,
  sendMessage,
  sessionId,
  switchChat,
} from '../lib/chat-store'

import ChatInput from './ChatInput.vue'
import ChatThread from './ChatThread.vue'
import SessionPanel from './SessionPanel.vue'

const input = ref<InstanceType<typeof ChatInput> | null>(null)
const switcherOpen = ref(false)
const chatAgentName = ref('')
const modelSearchText = ref('')
const showModelPicker = ref(false)
const modelPickerHover = ref(false)

const filteredModels = computed(() => {
  const q = modelSearchText.value.trim().toLowerCase()
  if (!q) return chatModels.value
  return chatModels.value.filter(
    (m) =>
      m.id.toLowerCase().includes(q) ||
      m.name.toLowerCase().includes(q) ||
      m.provider.toLowerCase().includes(q),
  )
})

function openTrace(adwId: string) {
  navigate(adwId)
}

async function onSwitch(id: string) {
  switcherOpen.value = false
  await switchChat(id)
}

async function onNew() {
  switcherOpen.value = false
  await newChat()
}

async function onDelete(id: string) {
  if (!confirm(`Delete conversation "${id}"? This cannot be undone.`)) return
  await deleteChat(id)
}

function onModelBlur() {
  if (!modelPickerHover.value) {
    showModelPicker.value = false
  }
}

function onKey(e: KeyboardEvent) {
  if (e.ctrlKey && e.key === '1') {
    e.preventDefault()
    input.value?.focus()
  }
}

onMounted(() => {
  void init()
  void loadHistory()
  void loadChatSessions()
  fetch('/api/settings')
    .then((r) => r.json())
    .then((list: Array<{ key: string; set: boolean; masked: string }>) => {
      const n = list.find((s) => s.key === 'WOTEAMS_AGENT_NAME')
      if (n?.set) chatAgentName.value = n.masked
    })
    .catch(() => {})
  window.addEventListener('keydown', onKey)
})
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <div class="chat">
    <header class="chat-head">
      <div class="head-left">
        <span class="chat-title">Orchestrator Chat</span>
        <span class="sub">talk to {{ chatAgentName || 'Kaia' }} · start smidja sessions</span>
      </div>
      <span class="model-picker" @mouseenter="modelPickerHover = true" @mouseleave="modelPickerHover = false">
        <input
          v-model="modelSearchText"
          class="model-input"
          :placeholder="(chatModel ? chatModel : 'default') + ' ...'"
          @focus="showModelPicker = true"
          @blur="onModelBlur"
          title="Model for Kaia's replies"
          autocomplete="off"
          spellcheck="false"
        />
        <div v-if="showModelPicker && filteredModels.length" class="model-dropdown"
          @mouseenter="modelPickerHover = true"
          @mouseleave="modelPickerHover = false"
        >
          <div
            class="model-opt"
            :class="{ active: !chatModel }"
            @mousedown.prevent="chatModel = ''; modelSearchText = ''; showModelPicker = false"
          >
            default
          </div>
          <div
            v-for="m in filteredModels"
            :key="m.id"
            class="model-opt"
            :class="{ active: chatModel === m.id }"
            @mousedown.prevent="chatModel = m.id; modelSearchText = ''; showModelPicker = false"
          >
            <span class="mo-name">{{ m.name }}</span>
            <span class="mo-meta">{{ m.provider }}</span>
          </div>
          <div v-if="!filteredModels.length && modelSearchText" class="model-no">
            no match — type any model id
          </div>
        </div>
      </span>
      <span class="session-picker">
        <button class="pick-btn" type="button" @click="switcherOpen = !switcherOpen">
          <span class="pick-dot" /> {{ sessionId }}
          <span class="pick-caret">▾</span>
        </button>
        <div v-if="switcherOpen" class="pick-menu">
          <div class="pick-menu-title">Conversations</div>
          <button
            v-for="s in chatSessions"
            :key="s.id"
            class="pick-item"
            :class="{ active: s.id === sessionId }"
            type="button"
            @click="onSwitch(s.id)"
          >
            <span class="pick-item-id">{{ s.id }}</span>
            <span class="pick-item-meta">{{ s.messages }} msg</span>
            <span
              class="pick-del"
              role="button"
              tabindex="0"
              title="Delete conversation"
              @click.stop="onDelete(s.id)"
              @keydown.enter.prevent="onDelete(s.id)"
            >✕</span>
          </button>
          <button class="pick-new" type="button" @click="onNew">＋ New chat</button>
        </div>
      </span>
      <span class="live"><span class="live-dot" /> live</span>
    </header>

    <div class="body">
      <section class="thread-wrap">
        <ChatThread :messages="messages" @launch-click="openTrace" />
        <ChatInput ref="input" :pending="pending" @send="sendMessage" @stop="() => {}" />
      </section>

      <SessionPanel @open="openTrace" />
    </div>
  </div>
</template>

<style scoped>
.chat { display: flex; flex-direction: column; height: calc(100vh - 58px); min-height: 0; }

.chat-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 24px;
  border-bottom: 1px solid var(--border-soft);
  background: rgba(11, 15, 24, 0.5);
  flex: none;
}
.head-left { display: flex; align-items: baseline; gap: 12px; }
.chat-title { font-weight: 700; font-size: 18px; color: var(--text); }
.sub { font-size: 13px; color: var(--dim); }

.live { display: inline-flex; align-items: center; gap: 8px; color: var(--dim); font-size: 14px; white-space: nowrap; }
.live-dot { width: 9px; height: 9px; border-radius: 50%; background: var(--green); box-shadow: 0 0 10px rgba(74, 222, 128, 0.7); animation: pulse 1.6s ease-in-out infinite; }
@keyframes pulse { 50% { opacity: 0.4; } }

.body {
  flex: 1 1 auto;
  display: flex;
  min-height: 0;
}
.thread-wrap {
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
  min-width: 0;
}

/* ── multi-session switcher ──────────────────────────────────────────── */
.session-picker { position: relative; margin-left: 14px; flex: none; }
.model-picker { position: relative; flex: none; }
.model-input {
  font-family: var(--mono);
  font-size: 12px;
  color: var(--text);
  background: var(--panel-2);
  border: 1px solid var(--border);
  border-radius: 999px;
  padding: 5px 12px;
  width: 200px;
  cursor: text;
  outline: none;
}
.model-input:focus { border-color: var(--accent, #ff6b35); }
.model-input::placeholder { color: var(--dim); }
.model-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  margin-top: 4px;
  max-height: 320px;
  overflow-y: auto;
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 10px;
  z-index: 100;
  padding: 4px 0;
}
.model-opt {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 6px 12px;
  font-size: 12px;
  cursor: pointer;
  color: var(--text);
}
.model-opt:hover { background: var(--panel-2); }
.model-opt.active { color: var(--accent, #ff6b35); font-weight: 600; }
.model-opt .mo-name { font-family: var(--mono); }
.model-opt .mo-meta { font-size: 11px; color: var(--dim); }
.model-no { padding: 8px 12px; font-size: 11px; color: var(--dim); font-style: italic; }
.pick-btn {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  font-family: var(--mono);
  font-size: 12px;
  color: var(--dim);
  background: var(--panel-2);
  border: 1px solid var(--border);
  border-radius: 999px;
  padding: 5px 12px;
  cursor: pointer;
  max-width: 220px;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.pick-btn:hover { color: var(--text); border-color: var(--border); }
.pick-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--blue); flex: none; }
.pick-caret { font-size: 9px; color: var(--faint); }
.pick-menu {
  position: absolute;
  right: 0;
  top: calc(100% + 6px);
  width: 260px;
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 8px;
  z-index: 20;
  box-shadow: 0 12px 34px rgba(0, 0, 0, 0.45);
  max-height: 320px;
  overflow-y: auto;
}
.pick-menu-title {
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--faint);
  padding: 4px 8px 8px;
}
.pick-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  width: 100%;
  text-align: left;
  background: transparent;
  border: none;
  border-radius: 7px;
  padding: 7px 8px;
  cursor: pointer;
  color: var(--dim);
}
.pick-item:hover { background: var(--panel-2); color: var(--text); }
.pick-item.active { background: rgba(108, 182, 255, 0.1); color: var(--text); }
.pick-item-id { font-family: var(--mono); font-size: 12px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.pick-item-meta { font-size: 11px; color: var(--faint); flex: none; }
.pick-del {
  flex: none;
  margin-left: 2px;
  font-size: 11px;
  color: var(--faint);
  padding: 1px 5px;
  border-radius: 5px;
  cursor: pointer;
}
.pick-del:hover { color: var(--red); background: rgba(248, 113, 113, 0.12); }
.pick-new {
  width: 100%;
  margin-top: 6px;
  border: 1px dashed var(--border);
  border-radius: 7px;
  background: transparent;
  color: var(--blue);
  font-size: 13px;
  padding: 8px;
  cursor: pointer;
}
.pick-new:hover { border-color: var(--blue); }
</style>
