import { create } from 'zustand';
import type {
  AgentCard,
  ChatMessage,
  FileNode,
  GateId,
  DomainId,
  ProcessInfo,
  PullRequest,
  ReviewsInfo,
  RecallEpisode,
  RealmId,
  RuneEntry,
  Session,
  SkillDef,
  StreamEvent,
  Task,
} from '../types';
import { realmDef, ACCENTS, GATES } from '../data/realms';
import {
  clearSession,
  loadSession,
  provisionWorkspace,
  sessionFor,
  saveSession,
} from '../services/auth';
import {
  gateApi,
  type ChatModel,
  type ChatSession,
  type CronInfo,
  type CronSeat,
  type MimirHealth,
  type RuntimeInfo,
  type SmidjaDecision,
  type SmidjaDetail,
  type SmidjaSession,
  type SmidjaStats,
} from '../services/api';

export type Density = 'comfortable' | 'compact';

/* --- Personal accent: paint your own seat ---------------------- */
function hexToRgba(hex: string, alpha: number): string {
  const h = hex.replace('#', '');
  const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h;
  const n = Number.parseInt(full || '38bdf8', 16);
  const r = (n >> 16) & 255;
  const g = (n >> 8) & 255;
  const b = n & 255;
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

export function applyAccent(
  accentId: string,
  custom: string | null,
  realmTint?: string,
): void {
  const root = document.documentElement;
  if (accentId === 'realm') {
    if (realmTint) {
      root.style.setProperty('--realm-tint', realmTint);
      root.style.setProperty('--realm-tint-2', realmTint);
      root.style.setProperty('--realm-tint-dim', hexToRgba(realmTint, 0.14));
    } else {
      root.style.removeProperty('--realm-tint');
      root.style.removeProperty('--realm-tint-2');
      root.style.removeProperty('--realm-tint-dim');
    }
    return;
  }
  let tint: string;
  let tint2: string;
  if (accentId === 'custom' && custom) {
    tint = custom;
    tint2 = custom;
  } else {
    const preset = ACCENTS.find((a) => a.id === accentId) ?? ACCENTS[0];
    tint = preset.tint ?? '#c9973f';
    tint2 = preset.tint2 ?? tint;
  }
  root.style.setProperty('--realm-tint', tint);
  root.style.setProperty('--realm-tint-2', tint2);
  root.style.setProperty('--realm-tint-dim', hexToRgba(tint, 0.14));
}

function loadAccent(): { accentId: string; customAccent: string | null } {
  try {
    return {
      accentId: localStorage.getItem('ymir.accent') ?? 'realm',
      customAccent: localStorage.getItem('ymir.accent.custom'),
    };
  } catch {
    return { accentId: 'realm', customAccent: null };
  }
}

export const STREAM_MIN = 46;
export const STREAM_MAX = 680;

/** The stream can be drawn all the way up to just under the header. */
function streamMax(): number {
  const vh = typeof window !== 'undefined' ? window.innerHeight : STREAM_MAX;
  return Math.max(STREAM_MAX, vh - 64);
}

function loadStreamHeight(): number {
  try {
    const v = Number(localStorage.getItem('ymir.stream-height'));
    if (Number.isFinite(v) && v >= STREAM_MIN) return Math.min(streamMax(), v);
  } catch {
    /* ignore */
  }
  return 192;
}

interface YmirState {
  session: Session | null;
  realm: RealmId;
  gate: GateId;
  density: Density;
  accentId: string;
  customAccent: string | null;
  tenantColors: Record<string, string>;
  streamHeight: number;
  companyName: string;
  companyHouse: DomainId;
  streamPaused: boolean;
  query: string;
  traceability: number;
  live: boolean | null;
  runtime: RuntimeInfo | null;
  cron: CronInfo | null;
  cronSeats: CronSeat[] | null;
  mimir: MimirHealth | null;
  smidjaDb: string;
  smidjaSessions: SmidjaSession[];
  smidjaStats: SmidjaStats | null;
  smidjaDecisions: SmidjaDecision[];
  selectedSession: string | null;
  sessionDetail: SmidjaDetail | null;

  agents: AgentCard[];
  /** Harness usage: opencode and pi sessions, not only the smithy's runs. */
  usage: import('../services/api').YmirUsage | null;
  tasks: Task[];
  runes: RuneEntry[];
  streams: Record<string, StreamEvent[]>;
  recall: RecallEpisode[];
  processes: ProcessInfo[];
  reviews: ReviewsInfo | null;
  files: FileNode;
  chat: ChatMessage[];
  chatSessions: ChatSession[];
  chatSession: string;
  chatModels: ChatModel[];
  chatModel: string;
  chatAgents: string[];
  chatPending: boolean;
  skills: SkillDef[];

  /** Establish the UI session for a login the gate has verified. */
  establishSession: (login: string) => void;
  provision: (input: { login: string; name: string; kind: 'work' | 'personal'; domains: string[] }) => void;
  signOut: () => void;
  loadLive: () => Promise<void>;
  refreshSmidja: () => Promise<void>;
  /** Re-read the LIVE fleet: the dead leave, and the count follows the source. */
  refreshAgents: () => Promise<void>;
  refreshReviews: () => Promise<void>;
  setSelectedSession: (id: string | null) => void;
  loadSessionDetail: (id: string) => Promise<void>;

  setRealm: (realm: RealmId) => void;
  setGate: (gate: GateId) => void;
  setDensity: (density: Density) => void;
  setAccent: (accentId: string) => void;
  setCustomAccent: (hex: string) => void;
  setTenantColor: (realm: string, hex: string) => void;
  resetTenantColor: (realm: string) => void;
  setStreamHeight: (height: number) => void;
  setCompanyName: (name: string) => void;
  setCompanyHouse: (domain: DomainId) => void;
  addAgent: (agent: AgentCard) => void;
  updateAgent: (id: string, patch: Partial<AgentCard>) => void;
  addSkill: (skill: SkillDef) => void;
  updateSkill: (id: string, patch: Partial<SkillDef>) => void;
  toggleStream: () => void;
  setQuery: (query: string) => void;
  pushStream: (event: StreamEvent) => void;
  pushChat: (message: ChatMessage) => void;
  sendChat: (body: string) => void;
  loadChat: () => Promise<void>;
  newChat: () => void;
  switchChat: (id: string) => void;
  deleteChat: (id: string) => void;
  setChatModel: (id: string) => void;
  toggleChatAgent: (name: string) => void;
  updateReview: (id: string, patch: Partial<PullRequest>) => void;
  updateProcess: (id: string, patch: Partial<ProcessInfo>) => void;
}

// Derived from the gate registry so adding a gate can never drift from routing.
const GATE_IDS: GateId[] = GATES.map((g) => g.id);

// The chat keeps a rolling window of the last 40 messages in view and in context.
const CHAT_WINDOW = 40;

// Every page keeps its own rolling window of the last 40 stream messages.
const STREAM_WINDOW = 40;

/** Route a stream event to the gate it belongs to, so each page sees its own. */
function gateForModule(module?: string): GateId | undefined {
  const m = (module ?? '').toLowerCase();
  if (/well|mimir|memory|engram/.test(m)) return 'well';
  if (/smidja|session|trace|phase/.test(m)) return 'sessions';
  if (/forge|gungnir|eindri|skill/.test(m)) return 'forge';
  if (/rune|ledger|audit/.test(m)) return 'runes';
  if (/cron|nornir/.test(m)) return 'cron';
  if (/review|glitnir|pr\b/.test(m)) return 'reviews';
  if (/process|valhalla|daemon/.test(m)) return 'processes';
  return undefined;
}

export function gateFromHash(): GateId {
  const raw = window.location.hash.replace(/^#\/?/, '');
  return (GATE_IDS as string[]).includes(raw) ? (raw as GateId) : 'fleet';
}

/** Honest empty state — live mode fills from the gate API; nothing is invented. */
function emptyState() {
  return {
    agents: [] as YmirState['agents'],
    usage: null,
    tasks: [] as YmirState['tasks'],
    runes: [] as YmirState['runes'],
    streams: { all: [] } as YmirState['streams'],
    recall: [] as YmirState['recall'],
    processes: [] as YmirState['processes'],
    reviews: null as YmirState['reviews'],
    files: { name: 'realm', type: 'dir', path: '/', children: [] } as YmirState['files'],
    chat: [] as YmirState['chat'],
    skills: [] as YmirState['skills'],
  };
}

function loadTenantColors(): Record<string, string> {
  try {
    return JSON.parse(localStorage.getItem('ymir.tenant-colors') ?? '{}') as Record<string, string>;
  } catch {
    return {};
  }
}

function loadCompany(): { companyName: string; companyHouse: DomainId } {
  try {
    return {
      companyName: localStorage.getItem('ymir.company.name') ?? 'WayOf',
      companyHouse: (localStorage.getItem('ymir.company.domain') as DomainId) ?? 'ymirlabs',
    };
  } catch {
    return { companyName: 'WayOf', companyHouse: 'ymirlabs' };
  }
}

function realmTintOf(state: Pick<YmirState, 'session' | 'realm' | 'tenantColors'>): string | undefined {
  return (
    state.tenantColors[state.realm] ??
    state.session?.tenants.find((t) => t.realm === state.realm)?.tint
  );
}

const initialSession = loadSession();

function initialRealm(session: Session | null): RealmId {
  try {
    const stored = localStorage.getItem('ymir.workspace') ?? localStorage.getItem('ymir.realm');
    if (stored) return stored;
  } catch {
    /* ignore */
  }
  if (session && session.tenants.length > 0) return session.tenants[0].realm;
  return 'work';
}

export const useYmir = create<YmirState>((set, get) => ({
  session: initialSession,
  realm: initialRealm(initialSession),
  gate: gateFromHash(),
  density: 'comfortable',
  ...loadAccent(),
  tenantColors: loadTenantColors(),
  streamHeight: loadStreamHeight(),
  ...loadCompany(),
  streamPaused: false,
  query: '',
  traceability: 0.984,
  live: null,
  runtime: null,
  cron: null,
  cronSeats: null,
  mimir: null,
  smidjaDb: 'absent',
  smidjaSessions: [],
  smidjaStats: null,
  smidjaDecisions: [],
  selectedSession: null,
  sessionDetail: null,
  chatSessions: [],
  chatSession: 'default',
  chatModels: [],
  chatModel: '',
  chatAgents: [],
  chatPending: false,
  ...emptyState(),

  loadLive: async () => {
    // Smíðja loads on its own track so a slow endpoint never holds its gates hostage.
    void get().refreshSmidja();
    try {
      // An endpoint that answers with {error} has FAILED: keep the last good value
      // rather than handing the panel a shape it cannot read.
      const ok = <T,>(x: T | null | undefined, prev: T): T =>
        x && !(x as unknown as { error?: unknown }).error ? (x as T) : prev;
      const [agents, usage, tasks, runes, recall, processes, reviews, files, runtime, cron, cronSeats, mimir, skills] =
        await Promise.all([
          // Each call degrades on its own — one bad endpoint must not blank the app.
          gateApi.agents().then((v) => ok(v, get().agents)).catch(() => get().agents),
          gateApi.usage().then((v) => ok(v, get().usage)).catch(() => get().usage),
          gateApi.tasks().then((v) => ok(v, get().tasks)).catch(() => get().tasks),
          gateApi.runes().then((v) => ok(v, get().runes)).catch(() => get().runes),
          gateApi.well('').then((v) => ok(v, get().recall)).catch(() => get().recall),
          gateApi.processes().then((v) => ok(v, get().processes)).catch(() => get().processes),
          gateApi.reviews().then((v) => ok(v, get().reviews)).catch(() => get().reviews),
          gateApi.files(get().realm).then((v) => ok(v, get().files)).catch(() => get().files),
          gateApi.runtime().then((v) => ok(v, get().runtime)).catch(() => get().runtime),
          gateApi.cron().then((v) => ok(v, get().cron)).catch(() => get().cron),
          gateApi.cronSeats().then((v) => ok(v, get().cronSeats ?? [])).catch(() => get().cronSeats ?? []),
          gateApi.mimirHealth().catch(() => null),
          gateApi.skills().then((v) => ok(v, get().skills)).catch(() => get().skills),
        ]);
      set({ agents, tasks, runes, recall, processes, reviews, files, runtime, cron, cronSeats, mimir, skills, usage, live: true });
    } catch {
      // Gate API unreachable — stay on the last good data and mark it.
      set({ live: false });
    }
  },

  refreshAgents: async () => {
    const agents = await gateApi.agents().catch(() => undefined);
    if (agents) set({ agents });
  },
  refreshReviews: async () => {
    // The board must show a PR that opened since the page loaded (2026-09-24
    // audit): refresh the Glitnir cards on a gentle 30s beat. The server memo
    // (60s) caps the gh read, so this is one cheap round-trip, never a throng.
    const info = await gateApi.reviews().catch(() => undefined);
    if (info) set({ reviews: info, live: true });
  },
  refreshSmidja: async () => {
    try {
      const [health, sessions, stats, decisions] = await Promise.all([
        gateApi.smidjaHealth().catch(() => ({ db: 'absent', sessions: 0 })),
        gateApi.smidjaSessions().catch(() => []),
        gateApi.smidjaStats().catch(() => null),
        gateApi.smidjaDecisions().catch(() => ({ total_failed: 0, decisions: [] })),
      ]);
      set({
        smidjaDb: health.db,
        smidjaSessions: sessions,
        smidjaStats: stats,
        smidjaDecisions: decisions.decisions,
        live: true,
      });
    } catch {
      // keep the last good data
    }
  },

  setSelectedSession: (id) => set({ selectedSession: id, sessionDetail: null }),
  loadSessionDetail: async (id) => {
    try {
      const detail = await gateApi.smidjaSession(id);
      set({ sessionDetail: detail, selectedSession: id });
    } catch {
      set({ sessionDetail: null });
    }
  },

  establishSession: (login) => {
    // The gate already decided; this only shapes what the UI renders.
    const session = sessionFor(login);
    saveSession(session);
    const realm = initialRealm(session);
    document.documentElement.dataset.realm = realm;
    const { accentId, customAccent, tenantColors } = get();
    applyAccent(
      accentId,
      customAccent,
      tenantColors[realm] ?? session.tenants.find((x) => x.realm === realm)?.tint,
    );
    set({ session, realm, ...emptyState() });
    void get().loadLive();
  },

  provision: (input) => {
    const session = provisionWorkspace(input);
    saveSession(session);
    const slug = input.name.toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/(^-|-$)/g, '');
    const realm = session.tenants.find((t) => t.realm === slug)?.realm ?? session.tenants[0]?.realm ?? 'work';
    document.documentElement.dataset.realm = realm;
    const { accentId, customAccent, tenantColors } = get();
    applyAccent(
      accentId,
      customAccent,
      tenantColors[realm] ?? session.tenants.find((t) => t.realm === realm)?.tint,
    );
    set({ session, realm, ...emptyState() });
    void get().loadLive();
  },

  signOut: () => {
    clearSession();
    set({ session: null, live: null, query: '' });
  },

  setRealm: (realm) => {
    // Single tenant: switch freely between workspaces (work | personal | …).
    try {
      localStorage.setItem('ymir.workspace', realm);
      document.documentElement.dataset.realm = realm;
    } catch {
      /* ignore */
    }
    const { accentId, customAccent, tenantColors } = get();
    applyAccent(accentId, customAccent, tenantColors[realm] ?? realmDef(realm).tint);
    set({ realm, ...emptyState() });
    void get().loadLive();
  },

  setGate: (gate) =>
    set(() => {
      if (window.location.hash !== `#/${gate}`) {
        window.location.hash = `#/${gate}`;
      }
      return { gate };
    }),

  setDensity: (density) => set({ density }),

  setAccent: (accentId) => {
    const { customAccent } = get();
    try {
      localStorage.setItem('ymir.accent', accentId);
    } catch {
      /* ignore */
    }
    applyAccent(accentId, customAccent, realmTintOf(get()));
    set({ accentId });
  },

  setCustomAccent: (hex) => {
    try {
      localStorage.setItem('ymir.accent', 'custom');
      localStorage.setItem('ymir.accent.custom', hex);
    } catch {
      /* ignore */
    }
    applyAccent('custom', hex);
    set({ accentId: 'custom', customAccent: hex });
  },

  setTenantColor: (realm, hex) => {
    const tenantColors = { ...get().tenantColors, [realm]: hex };
    try {
      localStorage.setItem('ymir.tenant-colors', JSON.stringify(tenantColors));
    } catch {
      /* ignore */
    }
    if (get().accentId === 'realm') {
      applyAccent('realm', get().customAccent, hex);
    }
    set({ tenantColors });
  },

  resetTenantColor: (realm) => {
    const next = { ...get().tenantColors };
    delete next[realm];
    try {
      localStorage.setItem('ymir.tenant-colors', JSON.stringify(next));
    } catch {
      /* ignore */
    }
    const session = get().session;
    const fallback = session?.tenants.find((t) => t.realm === realm)?.tint;
    if (get().accentId === 'realm') {
      applyAccent('realm', get().customAccent, fallback);
    }
    set({ tenantColors: next });
  },

  setCompanyName: (name) => {
    try {
      localStorage.setItem('ymir.company.name', name);
    } catch {
      /* ignore */
    }
    set({ companyName: name });
  },

  setCompanyHouse: (house) => {
    try {
      localStorage.setItem('ymir.company.domain', house);
    } catch {
      /* ignore */
    }
    set({ companyHouse: house });
  },

  setStreamHeight: (height) => {
    const clamped = Math.min(streamMax(), Math.max(STREAM_MIN, Math.round(height)));
    try {
      localStorage.setItem('ymir.stream-height', String(clamped));
    } catch {
      /* ignore */
    }
    set({ streamHeight: clamped });
  },

  addAgent: (agent) => set((s) => ({ agents: [...s.agents, agent] })),
  updateAgent: (id, patch) =>
    set((s) => ({ agents: s.agents.map((a) => (a.id === id ? { ...a, ...patch } : a)) })),
  addSkill: (skill) => set((s) => ({ skills: [skill, ...s.skills] })),
  updateSkill: (id, patch) =>
    set((s) => ({ skills: s.skills.map((k) => (k.id === id ? { ...k, ...patch } : k)) })),

  toggleStream: () => set((s) => ({ streamPaused: !s.streamPaused })),
  setQuery: (query) => set({ query }),

  pushStream: (event) =>
    set((s) => {
      const g = event.gate ?? gateForModule(event.module) ?? s.gate;
      const tagged = { ...event, gate: g };
      const base = s.streams ?? {};
      const cur = base[g] ?? [];
      const all = base.all ?? [];
      return {
        streams: {
          ...base,
          [g]: [tagged, ...cur].slice(0, STREAM_WINDOW),
          all: [tagged, ...all].slice(0, STREAM_WINDOW),
        },
      };
    }),
  pushChat: (message) =>
    set((s) => ({ chat: [...s.chat, message].slice(-CHAT_WINDOW) })),

  sendChat: (body) => {
    const text = body.trim();
    if (!text) return;
    const { chatSession, chatModel, chatAgents } = get();
    get().pushChat({ id: `u-${Date.now()}`, from: 'user', body: text, ts: new Date().toISOString() });
    const pendingId = `k-${Date.now()}`;
    get().pushChat({
      id: pendingId,
      from: 'kaia',
      body: '',
      ts: new Date().toISOString(),
      thinking: true,
    });
    set({ chatPending: true });

    const finish = (patch: Partial<ChatMessage>) =>
      set((s) => ({
        chat: s.chat.map((m) => (m.id === pendingId ? { ...m, thinking: false, ...patch } : m)),
        chatPending: false,
      }));
    const refreshSessions = () => {
        void gateApi.chatSessions().then((rows) => set({ chatSessions: rows })).catch(() => {});
    };

    void gateApi
      .chat(text, {
        session: chatSession,
        model: chatModel || undefined,
        agents: chatAgents.length ? chatAgents : undefined,
      })
      .then(({ reply }) => finish(reply))
      .catch(() =>
        finish({
          body: 'The bridge did not answer. Check the gate API (npm run api) and Bifrost (bin/bifrost-bridge.sh).',
          error: true,
        }),
      )
      .finally(refreshSessions);
  },

  loadChat: async () => {
    try {
      const [history, sessions, models] = await Promise.all([
        gateApi.chatHistory(get().chatSession).catch(() => [] as ChatMessage[]),
        gateApi.chatSessions().catch(() => [] as ChatSession[]),
        gateApi.chatModels().catch(() => [] as ChatModel[]),
      ]);
      set({ chat: history.slice(-CHAT_WINDOW), chatSessions: sessions, chatModels: models });
    } catch {
      /* stay on the seeded thread */
    }
  },
  newChat: () => {
    const id = `chat-${Date.now().toString(36)}`;
    set((s) => ({
      chatSession: id,
      chat: [],
      chatPending: false,
      chatSessions: [{ id, messages: 0, updated_at: new Date().toISOString() }, ...s.chatSessions],
    }));
  },
  switchChat: (id) => {
    set({ chatSession: id, chat: [], chatPending: false });
    void gateApi
      .chatHistory(id)
      .then((history) => set({ chat: history.slice(-CHAT_WINDOW) }))
      .catch(() => {});
  },
  deleteChat: (id) => {
    void gateApi
      .deleteChatSession(id)
      .catch(() => {})
      .finally(() => {
        const rest = get().chatSessions.filter((x) => x.id !== id);
        set({ chatSessions: rest });
        if (get().chatSession === id) get().switchChat(rest[0]?.id ?? 'default');
      });
  },
  setChatModel: (id) => set({ chatModel: id }),
  toggleChatAgent: (name) =>
    set((s) => ({
      chatAgents: s.chatAgents.includes(name)
        ? s.chatAgents.filter((a) => a !== name)
        : [...s.chatAgents, name],
    })),
  updateReview: (id, patch) =>
    set((s) => ({
      reviews: s.reviews
        ? { ...s.reviews, cards: s.reviews.cards.map((r) => (r.id === id ? { ...r, ...patch } : r)) }
        : s.reviews,
    })),
  updateProcess: (id, patch) =>
    set((s) => ({ processes: s.processes.map((p) => (p.id === id ? { ...p, ...patch } : p)) })),
}));

// Apply the saved accent before first paint.
{
  const a = loadAccent();
  applyAccent(a.accentId, a.customAccent, realmTintOf(useYmir.getState()));
}

// A persisted session boots straight into live mode.
if (initialSession) void useYmir.getState().loadLive();

export const currentRealmDef = () => {
  const { realm } = useYmir.getState();
  return realmDef(realm);
};
