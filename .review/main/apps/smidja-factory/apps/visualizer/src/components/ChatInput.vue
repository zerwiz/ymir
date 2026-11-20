<script setup lang="ts">
import { nextTick, ref } from 'vue'
import { Paperclip, Send, Square } from 'lucide-vue-next'

const props = defineProps<{ pending: boolean }>()
const emit = defineEmits<{ (e: 'send', text: string): void; (e: 'stop'): void }>()

const box = ref<HTMLTextAreaElement | null>(null)
const text = ref('')

function autosize() {
  const el = box.value
  if (!el) return
  el.style.height = 'auto'
  el.style.height = `${Math.min(el.scrollHeight, 180)}px`
}

function onKeydown(e: KeyboardEvent) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault()
    submit()
  }
}

function submit() {
  const v = text.value.trim()
  if (!v || props.pending) return
  emit('send', v)
  text.value = ''
  nextTick(() => box.value && (box.value.style.height = 'auto'))
}

function focus() {
  box.value?.focus()
}

defineExpose({ focus })
</script>

<template>
  <div class="input-bar">
    <div class="box">
      <button class="icon-btn" type="button" title="Attach (coming soon)" disabled>
        <Paperclip :size="17" />
      </button>
      <textarea
        ref="box"
        v-model="text"
        class="field"
        rows="1"
        placeholder="Message the orchestrator…"
        @input="autosize"
        @keydown="onKeydown"
      />
      <button
        v-if="pending"
        class="icon-btn stop"
        type="button"
        title="Stop generating"
        @click="emit('stop')"
      >
        <Square :size="15" fill="currentColor" />
      </button>
      <button
        v-else
        class="send"
        type="button"
        :disabled="!text.trim()"
        title="Send (Enter)"
        @click="submit"
      >
        <Send :size="17" />
      </button>
    </div>
    <div class="hint">Enter to send · Shift+Enter for a new line · Ctrl+1 to focus</div>
  </div>
</template>

<style scoped>
.input-bar {
  flex: none;
  padding: 14px 24px 16px;
  border-top: 1px solid var(--border-soft);
  background: rgba(11, 15, 24, 0.5);
}
.box {
  max-width: 940px;
  margin: 0 auto;
  display: flex;
  align-items: flex-end;
  gap: 8px;
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 9px 10px;
}
.box:focus-within {
  border-color: color-mix(in srgb, var(--accent) 55%, transparent);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--accent) 12%, transparent);
}
.field {
  flex: 1 1 auto;
  background: transparent;
  border: none;
  outline: none;
  resize: none;
  color: var(--text);
  font-family: inherit;
  font-size: 15.5px;
  line-height: 1.5;
  max-height: 180px;
  padding: 4px 2px;
}
.icon-btn {
  flex: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border-radius: 9px;
  border: none;
  background: transparent;
  color: var(--dim);
  cursor: pointer;
}
.icon-btn:disabled { color: var(--faint); cursor: not-allowed; opacity: 0.6; }
.icon-btn:not(:disabled):hover { background: color-mix(in srgb, var(--text) 5%, transparent); color: var(--text); }
.icon-btn.stop { color: var(--red); }
.icon-btn.stop:hover { background: color-mix(in srgb, var(--red) 12%, transparent); }

.send {
  flex: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border-radius: 9px;
  border: none;
  background: var(--accent);
  color: var(--bg);
  cursor: pointer;
}
.send:disabled { background: var(--panel-2); color: var(--faint); cursor: not-allowed; }
.send:not(:disabled):hover { filter: brightness(1.08); }

.hint {
  max-width: 940px;
  margin: 8px auto 0;
  font-size: 12px;
  color: var(--faint);
  text-align: center;
}
</style>
