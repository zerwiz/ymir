<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { SettingInfo } from '../lib/types'

const FIELDS = [
  {
    key: 'WAYOFTEAMS_MCP_TOKEN',
    label: 'WayOfTeams MCP token',
    hint: 'Per-user JWT from WayOfTeams → Settings → MCP. Stored locally in the repo .env (gitignored); the chat pi process uses it to load the full WayOfTeams MCP surface.',
    secret: true,
    placeholder: 'paste token (replaces current)',
  },
  {
    key: 'WOTEAMS_MCP_URL',
    label: 'MCP endpoint',
    hint: 'Base endpoint. Default https://teamsapp.zerwiz.org — the client auto-probes /mcp/v2 → legacy /mcp → REST.',
    secret: false,
    placeholder: 'https://teamsapp.zerwiz.org',
  },
  {
    key: 'WOTEAMS_AGENT_NAME',
    label: 'Orchestrator name (Kaia)',
    hint: 'What your orchestrator registers as in the WayOfTeams work registry (agents_list / update_my_work). Default: kaia-chat.',
    secret: false,
    placeholder: 'kaia-chat',
  },
] as const

const settings = ref<Record<string, SettingInfo>>({})
const values = ref<Record<string, string>>({})
const status = ref<string | null>(null)
const error = ref<string | null>(null)
const saving = ref(false)

async function load() {
  try {
    const res = await fetch('/api/settings')
    const list = (await res.json()) as SettingInfo[]
    const map: Record<string, SettingInfo> = {}
    for (const s of list) map[s.key] = s
    settings.value = map
  } catch (e) {
    error.value = (e as Error).message
  }
}

async function save(key: string) {
  const value = (values.value[key] ?? '').trim()
  if (!value && settings.value[key]?.set && !confirm(`Clear ${key}?`)) return
  saving.value = true
  error.value = null
  status.value = null
  try {
    const res = await fetch('/api/settings/save', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ key, value }),
    })
    if (!res.ok) throw new Error((await res.json()).error ?? 'save failed')
    const saved = (await res.json()) as SettingInfo
    settings.value[key] = saved
    values.value[key] = ''
    status.value = `${key} saved (${saved.set ? saved.masked : 'cleared'})`
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  void load()
})
</script>

<template>
  <div class="settings">
    <div class="settings-head">
      <h1>Settings</h1>
      <p class="sub">WayOfTeams MCP keys — stored locally in the repo <code>.env</code>, never echoed back.</p>
    </div>

    <p v-if="error" class="err">{{ error }}</p>
    <p v-if="status" class="ok">{{ status }}</p>

    <section v-for="f in FIELDS" :key="f.key" class="card">
      <div class="card-top">
        <h2>{{ f.label }}</h2>
        <span v-if="settings[f.key]?.set" class="badge">{{ settings[f.key].masked }}</span>
        <span v-else class="badge off">not set</span>
      </div>
      <p class="hint">{{ f.hint }}</p>
      <div class="row">
        <input
          :type="f.secret ? 'password' : 'text'"
          v-model="values[f.key]"
          :placeholder="f.placeholder"
          autocomplete="off"
          spellcheck="false"
          class="input"
        />
        <button class="save" type="button" :disabled="saving" @click="save(f.key)">
          {{ values[f.key]?.trim() ? 'Save' : 'Clear' }}
        </button>
      </div>
    </section>

    <p class="note">
      Kaia (the orchestrator chat) gets these keys on every message — the chat's pi process
      loads <code>@wayofmono/wayofteams-tools</code> directly, so it works even if your own
      interactive pi doesn't have the package installed.
    </p>
  </div>
</template>

<style scoped>
.settings { max-width: 760px; margin: 0 auto; padding: 32px 24px; }
.settings-head h1 { font-size: 22px; margin: 0 0 4px; color: var(--text); }
.sub { color: var(--dim); margin: 0 0 18px; font-size: 13px; }
code { font-family: var(--mono); font-size: 12px; background: var(--panel-2); padding: 1px 5px; border-radius: 4px; }
.err { color: var(--danger, #f87171); font-size: 13px; }
.ok { color: var(--green, #4ade80); font-size: 13px; }
.card { background: var(--panel); border: 1px solid var(--border); border-radius: 12px; padding: 16px 18px; margin-bottom: 14px; }
.card-top { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.card-top h2 { font-size: 14px; margin: 0; color: var(--text); }
.badge { font-family: var(--mono); font-size: 11px; color: var(--green, #4ade80); background: rgba(74, 222, 128, 0.1); padding: 2px 8px; border-radius: 999px; }
.badge.off { color: var(--dim); background: var(--panel-2); }
.hint { color: var(--dim); font-size: 12px; margin: 8px 0 12px; line-height: 1.5; }
.row { display: flex; gap: 10px; }
.input {
  flex: 1;
  font-family: var(--mono);
  font-size: 13px;
  background: var(--panel-2);
  color: var(--text);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 9px 12px;
  min-width: 0;
}
.save {
  font-size: 13px;
  color: var(--fg, #fff);
  background: var(--accent, #ff6b35);
  border: none;
  border-radius: 8px;
  padding: 9px 18px;
  cursor: pointer;
}
.save:disabled { opacity: 0.5; }
.note { color: var(--dim); font-size: 12px; margin-top: 18px; line-height: 1.6; }
</style>