import type { GateId, DomainDef, RealmDef, TaskState, AgentStatus } from '../types';

// One runtime, MANY realms (plan 275 items 11 and 21). The Work · Personal · Svein
// mode chips and the switching they offered are retired: there is one Hlidskjalf
// and it shows EVERY realm. A realm is a FOLDER (svartalfaheim/<realm>) and a
// LABEL, never a mode that hides the other two — pinning the runtime to `work`
// stranded the Personal and Svein data, which the rule "never remove a feature"
// forbids. So `WORKSPACES` stays the full list (the registry's three), `DEFAULT_REALM`
// is only the default SCOPE a realm-scoped page starts on, and a page that needs a
// scope offers the three as a filter.
export const WORKSPACES: RealmDef[] = [
  {
    id: 'work',
    tenant: 'Work',
    name: 'Work',
    kind: 'work',
    company: 'wayof',
    domains: ['company', 'marketing', 'development', 'life'],
    tint: '#c9973f',
    tint2: '#7d5f2a',
    glyph: 'ᛉ',
  },
  {
    id: 'personal',
    tenant: 'Personal',
    name: 'Personal',
    kind: 'personal',
    domains: ['me', 'life', 'development'],
    tint: '#96a0a8',
    tint2: '#5f686e',
    glyph: 'ᛗ',
  },
  {
    id: 'svein',
    tenant: 'Svein',
    name: 'Svein',
    kind: 'work',
    // The company a realm belongs to is private data (RULES/04): it is named in
    // the operator's registry (hodd/identity/workspaces.yaml), never here.
    domains: ['company', 'marketing', 'development', 'life'],
    tint: '#8aa39b',
    tint2: '#4f6b64',
    glyph: 'ᛋ',
  },
];

/** The realm a realm-scoped page opens on. It is a default FILTER, not a mode:
 *  every realm stays reachable and visible. */
export const DEFAULT_REALM = 'work';

/** A realm's display name, for a label or a filter chip. */
export const realmLabel = (id: string): string =>
  WORKSPACES.find((r) => r.id === id)?.name ?? id;

/** Back-compat alias — the active `realm` id is now a workspace id. */
export const REALMS = WORKSPACES;

export const DOMAIN_LABEL: Record<string, string> = {
  company: 'Company',
  marketing: 'Marketing',
  development: 'Development',
  life: 'Life',
  me: 'Me',
};

export const DOMAINS: Record<string, DomainDef> = {
  ymirlabs: { id: 'ymirlabs', name: 'Ymir Labs', accent: '#c9973f', glyph: 'ᛦ' },
  brokkforge: { id: 'brokkforge', name: 'Brokk Forge', accent: '#f59e0b', glyph: 'ᛒ' },
  runestone: { id: 'runestone', name: 'Runestone Labs', accent: '#f43f5e', glyph: 'ᚱ' },
  muninn: { id: 'muninn', name: 'Muninn Labs', accent: '#96a0a8', glyph: 'ᛗ' },
  dvalin: { id: 'dvalin', name: 'Dvalin', accent: '#9a8f75', glyph: 'ᛞ' },
  utgard: { id: 'utgard', name: 'Utgard Studios', accent: '#c2584a', glyph: 'ᚢ' },
  askr: { id: 'askr', name: 'Askr', accent: '#34d399', glyph: 'ᚨ' },
  mannheim: { id: 'mannheim', name: 'Mannheim', accent: '#6b6250', glyph: 'ᛘ' },
};

export const realmById = (id: string): RealmDef =>
  REALMS.find((r) => r.id === id) ?? REALMS[0];

export interface AccentPreset {
  id: string;
  name: string;
  tint: string | null;
  tint2: string | null;
}

/**
 * Personal accent presets. `realm` follows the tenant tint (the structural
 * default); every other preset lets the operator paint their own seat. The ids
 * are stored preferences and stay as they were; since 2026-11-12 (RULES/54) the
 * cool presets wear house colours under house names.
 */
export const ACCENTS: AccentPreset[] = [
  { id: 'realm', name: 'Realm default', tint: null, tint2: null },
  { id: 'azure', name: 'Bronze', tint: '#c9973f', tint2: '#7d5f2a' },
  { id: 'indigo', name: 'Hearth', tint: '#eca654', tint2: '#c9973f' },
  { id: 'violet', name: 'Steel', tint: '#96a0a8', tint2: '#5f686e' },
  { id: 'magenta', name: 'Blood', tint: '#c2584a', tint2: '#7c3a30' },
  { id: 'crimson', name: 'Crimson', tint: '#f43f5e', tint2: '#e11d48' },
  { id: 'ember', name: 'Ember', tint: '#f87171', tint2: '#ef4444' },
  { id: 'orange', name: 'Orange', tint: '#fb923c', tint2: '#f97316' },
  { id: 'amber', name: 'Amber', tint: '#f59e0b', tint2: '#d97706' },
  { id: 'lime', name: 'Lime', tint: '#a3e635', tint2: '#84cc16' },
  { id: 'emerald', name: 'Emerald', tint: '#34d399', tint2: '#10b981' },
  { id: 'teal', name: 'Teal', tint: '#2dd4bf', tint2: '#14b8a6' },
  { id: 'cyan', name: 'Bone', tint: '#cfc3a9', tint2: '#9a8f75' },
  { id: 'steel', name: 'Worn bone', tint: '#9a8f75', tint2: '#6b6250' },
];

/**
 * Resolve a realm definition for any tenant — known realms keep their
 * canonical tint; a freshly provisioned tenant is derived from its house seal.
 */
export function realmDef(
  id: string,
  grant?: { tenant?: string; domain?: string; tint?: string; glyph?: string },
): RealmDef {
  const known = WORKSPACES.find((r) => r.id === id);
  if (known) return known;
  const house = DOMAINS[grant?.domain ?? 'ymirlabs'];
  return {
    id,
    tenant: grant?.tenant ?? id,
    name: grant?.tenant ?? id,
    domain: house.id,
    tint: grant?.tint ?? house.accent,
    tint2: grant?.tint ?? house.accent,
    glyph: grant?.glyph ?? house.glyph,
  };
}

export interface GateDef {
  id: GateId;
  label: string;
  glyph: string;
  hint: string;
}

export const GATES: GateDef[] = [
  { id: 'skirnir', label: 'Skírnir – Tala', glyph: 'ᚨ', hint: 'Assistent · mikrofon med samtycke · lokalt svar' },
  { id: 'fleet', label: 'Fleet', glyph: 'ᚠ', hint: 'Agent Cards · status · A2A graph' },
  { id: 'tasks', label: 'Tasks', glyph: 'ᛏ', hint: 'A2A lifecycle board' },
  { id: 'well', label: 'Well', glyph: 'ᛜ', hint: 'Mimirsbrunn recall · timeline' },
  { id: 'runes', label: 'Runes', glyph: 'ᚱ', hint: 'Append-only ledger' },
  { id: 'reviews', label: 'Reviews', glyph: 'ᛉ', hint: 'Glitnir PR cards' },
  { id: 'processes', label: 'Processes', glyph: 'ᛞ', hint: 'Valhalla supervision' },
  { id: 'files', label: 'Files', glyph: 'ᛊ', hint: 'Skrymir file browser' },
  { id: 'chat', label: 'OmniChat', glyph: 'ᚴ', hint: 'Kaia · orchestration' },
  { id: 'forge', label: 'Forge', glyph: 'ᚨ', hint: 'Create · edit · Eindri & skills' },
  { id: 'runtime', label: 'Runtime', glyph: 'ᛖ', hint: 'Sága digest · session seating' },
  { id: 'cron', label: 'Cron', glyph: 'ᛃ', hint: 'Nornir schedule · job health' },
  { id: 'sessions', label: 'Sessions', glyph: 'ᛋ', hint: 'Smiðja runs · phase progress' },
  { id: 'worktrees', label: 'Worktrees', glyph: 'ᛥ', hint: 'Yggdrasil worktrees · branch · owning agent' },
  { id: 'trace', label: 'Trace', glyph: 'ᛚ', hint: 'Lanes · phases · tool calls' },
  { id: 'decisions', label: 'Decisions', glyph: 'ᚦ', hint: 'Failures grouped · the fix' },
  { id: 'stats', label: 'Stats', glyph: 'ᛗ', hint: 'Tokens · cost · by chain & model' },
  { id: 'managandr', label: 'Mánagandr', glyph: 'ᛅ', hint: 'Read calendar · reckoning · lanes' },
  { id: 'snotra', label: 'Snotra', glyph: 'ᛊ', hint: 'Meetings · record · prepare · approve · send' },
  { id: 'mail', label: 'Gná', glyph: 'ᚷ', hint: 'The one mail desk · needs you · unsure · waiting · done' },
  { id: 'profile', label: 'Profile', glyph: 'ᛝ', hint: 'Personal & company settings' },
];

export const TASK_STATES: TaskState[] = [
  'SUBMITTED',
  'WORKING',
  'INPUT_REQUIRED',
  'AUTH_REQUIRED',
  'COMPLETED',
  'FAILED',
  'REJECTED',
  'CANCELED',
];

export const TERMINAL_STATES: TaskState[] = [
  'COMPLETED',
  'FAILED',
  'REJECTED',
  'CANCELED',
];

export const TASK_STATE_META: Record<
  TaskState,
  { glyph: string; label: string; tone: AgentStatus | 'info' }
> = {
  SUBMITTED: { glyph: 'ᛋ', label: 'Submitted', tone: 'info' },
  WORKING: { glyph: 'ᚹ', label: 'Working', tone: 'info' },
  INPUT_REQUIRED: { glyph: 'ᛁ', label: 'Input required', tone: 'degraded' },
  AUTH_REQUIRED: { glyph: 'ᚨ', label: 'Auth required', tone: 'degraded' },
  COMPLETED: { glyph: 'ᚲ', label: 'Completed', tone: 'nominal' },
  FAILED: { glyph: 'ᚠ', label: 'Failed', tone: 'down' },
  REJECTED: { glyph: 'ᚱ', label: 'Rejected', tone: 'down' },
  CANCELED: { glyph: 'ᛪ', label: 'Canceled', tone: 'degraded' },
};

export const STATUS_META: Record<AgentStatus, { glyph: string; label: string; tone: string }> = {
  nominal: { glyph: 'ᛟ', label: 'NOMINAL', tone: 'ok' },
  degraded: { glyph: 'ᛇ', label: 'DEGRADED', tone: 'warn' },
  down: { glyph: 'ᛪ', label: 'DOWN', tone: 'danger' },
};
