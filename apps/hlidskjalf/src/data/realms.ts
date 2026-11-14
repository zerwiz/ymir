import type { GateId, DomainDef, RealmDef, TaskState, AgentStatus } from '../types';

// One runtime, MANY realms (plan 275 items 11 and 21). The mode chips and the
// switching they offered are retired: there is one Hlidskjalf and it shows EVERY
// realm. A realm is a FOLDER (`svartalfaheim/<realm>`) and a LABEL, never a mode
// that hides the others — pinning the runtime to one of them stranded the rest,
// which the rule "never remove a feature" forbids. So the realm list is a FILTER
// on every page that scopes its work, and `DEFAULT_REALM` is only the scope a
// realm-scoped page opens on.
//
// WHOSE realms they are is private data (RULES/04). The list is READ from the
// operator's own registry — `hodd/identity/workspaces.yaml` in the home, served
// by the gate at `GET /api/workspaces` — and never written into this file. What
// ships is a generic default of two, so a home with one operator, no registry and
// no realms shelf still opens Hlidskjalf and still works.
export const DEFAULT_WORKSPACES: RealmDef[] = [
  {
    id: 'work',
    tenant: 'Work',
    name: 'Work',
    kind: 'work',
    domains: ['company', 'marketing', 'development', 'life'],
    tint: '#c9973f',
    tint2: '#7d5f2a',
    glyph: 'ᛉ',
  },
];

/** The realms a machine has, from the registry row it answered with. A realm the
 *  shipped build already knows keeps its own colour and rune; one it does not
 *  (nobody can ship a private shelf) takes the seal its own id picks, so it looks
 *  the same on every reload and no two realms take the same one by accident. */
export interface WorkspaceRow {
  id: string;
  name?: string;
  kind?: string;
  company?: string;
  domains?: string[];
}

/** The house seals a registry realm may wear, in a fixed order. */
const SEALS: Array<{ tint: string; tint2: string; glyph: string }> = [
  { tint: '#c9973f', tint2: '#7d5f2a', glyph: 'ᛉ' },
  { tint: '#96a0a8', tint2: '#5f686e', glyph: 'ᛗ' },
  { tint: '#8aa39b', tint2: '#4f6b64', glyph: 'ᛋ' },
  { tint: '#c2584a', tint2: '#7c3a30', glyph: 'ᚢ' },
  { tint: '#9a8f75', tint2: '#6b6250', glyph: 'ᛞ' },
  { tint: '#34d399', tint2: '#10b981', glyph: 'ᚨ' },
];

/** A stable seal per id: the same realm wears the same tint on every machine. */
function sealOf(id: string): { tint: string; tint2: string; glyph: string } {
  let h = 0;
  for (let i = 0; i < id.length; i += 1) h = (h * 31 + id.charCodeAt(i)) % 100000;
  return SEALS[h % SEALS.length];
}

/** One registry row → the realm definition the UI draws. */
export function realmFromRegistry(row: WorkspaceRow): RealmDef {
  const known = DEFAULT_WORKSPACES.find((r) => r.id === row.id);
  const seal = sealOf(row.id);
  const kind = row.kind === 'personal' ? 'personal' : 'work';
  return {
    id: row.id,
    tenant: row.name || row.id,
    name: row.name || row.id,
    kind,
    ...(row.company ? { company: row.company } : {}),
    ...(row.domains?.length ? { domains: row.domains as RealmDef['domains'] } : {}),
    tint: known?.tint ?? seal.tint,
    tint2: known?.tint2 ?? seal.tint2,
    glyph: known?.glyph ?? seal.glyph,
    ...(known?.domains ? { domains: known.domains } : {}),
    ...(known?.company ? { company: known.company } : {}),
  };
}

/** The realm list a machine answers with, or the shipped pair when it answers
 *  with nothing — a registry that cannot be read is not an empty home. */
export function realmsFromRegistry(rows: WorkspaceRow[] | null | undefined): RealmDef[] {
  const seen = new Set<string>();
  const out: RealmDef[] = [];
  for (const row of rows ?? []) {
    if (!row?.id || seen.has(row.id)) continue;
    seen.add(row.id);
    out.push(realmFromRegistry(row));
  }
  return out.length ? out : DEFAULT_WORKSPACES;
}

/** The realm a realm-scoped page opens on. It is a default FILTER, not a mode:
 *  every realm stays reachable and visible. */
export const DEFAULT_REALM = 'work';

/** A realm's display name, for a label or a filter chip. */
export const realmLabel = (id: string, realms: RealmDef[] = DEFAULT_WORKSPACES): string =>
  realms.find((r) => r.id === id)?.name ?? id;

/** Back-compat alias — the shipped pair, for code that draws before the registry
 *  has answered. A surface that shows a person's realms reads the store. */
export const REALMS = DEFAULT_WORKSPACES;

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

export const realmById = (id: string, realms: RealmDef[] = DEFAULT_WORKSPACES): RealmDef =>
  realms.find((r) => r.id === id) ?? realms[0] ?? DEFAULT_WORKSPACES[0];

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
  const known = DEFAULT_WORKSPACES.find((r) => r.id === id);
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
  { id: 'chat', label: 'OmniChat', glyph: 'ᚴ', hint: 'Völundr · the smiths' },
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
