import type { GateId, StreamEvent } from '../types';

/**
 * Per-page domain feeds. Every gate gets its own rolling window of hardcoded,
 * domain-appropriate messages so each page always shows a hot feed about what
 * that page is about. These are UI narration, not memory — the well itself
 * stays strictly real.
 */
interface FeedLine {
  from: string;
  module: string;
  kind: 'ratatoskr' | 'rune';
  message: string;
}

const FEED: Record<string, FeedLine[]> = {
  fleet: [
    { from: 'Brokk', module: 'fleet', kind: 'ratatoskr', message: 'agent card re-signed · A2A 1.0' },
    { from: 'Kaia', module: 'fleet', kind: 'ratatoskr', message: 'capability query fanned to 9 agents' },
    { from: 'Eindri-01', module: 'utgard', kind: 'rune', message: 'worker heartbeat nominal' },
    { from: 'Eindri-02', module: 'yggdrasil', kind: 'rune', message: 'worktree branch advanced' },
    { from: 'Heimdall', module: 'fleet', kind: 'rune', message: 'rune of introduction verified' },
    { from: 'Ratatoskr', module: 'ratatoskr', kind: 'ratatoskr', message: 'peer discovery refreshed' },
    { from: 'Brokk', module: 'fleet', kind: 'rune', message: 'traceability index at 0.984' },
    { from: 'Sindri', module: 'utgard', kind: 'ratatoskr', message: 'specialist lane attached' },
  ],
  tasks: [
    { from: 'Kaia', module: 'ratatoskr', kind: 'ratatoskr', message: 'task state announced to peers' },
    { from: 'Brokk', module: 'tasks', kind: 'rune', message: 'BACKLOG order claimed' },
    { from: 'Eindri-01', module: 'tasks', kind: 'ratatoskr', message: 'SUBMITTED → WORKING' },
    { from: 'Kaia', module: 'tasks', kind: 'ratatoskr', message: 'INPUT_REQUIRED raised for approval' },
    { from: 'Brokk', module: 'tasks', kind: 'rune', message: 'artifact attached to order' },
    { from: 'Ratatoskr', module: 'ratatoskr', kind: 'ratatoskr', message: 'redis queue drained ratatoskr:inbox' },
    { from: 'Kaia', module: 'tasks', kind: 'ratatoskr', message: 'task lifecycle checkpoint written' },
  ],
  well: [
    { from: 'Kaia', module: 'mimirsbrunn', kind: 'rune', message: 'recall hybrid — episodes merged' },
    { from: 'Kaia', module: 'mimirsbrunn', kind: 'rune', message: 'observe episode carved into the engram' },
    { from: 'Mimir', module: 'mimirsbrunn', kind: 'rune', message: 'cache-hit ratio rising' },
    { from: 'Kaia', module: 'mimirsbrunn', kind: 'rune', message: 'cache read served from context' },
    { from: 'Brokk', module: 'mimirsbrunn', kind: 'rune', message: 'well watered after the dispatch' },
    { from: 'Kaia', module: 'mimirsbrunn', kind: 'rune', message: 'dry well — fired cold, never a blocker' },
    { from: 'Mimir', module: 'mimirsbrunn', kind: 'rune', message: 'spreading recall walked the entity graph' },
  ],
  runes: [
    { from: 'Brokk', module: 'runes', kind: 'rune', message: 'checksum chain extended' },
    { from: 'Muninn', module: 'runes', kind: 'rune', message: 'ledger line appended, never rewritten' },
    { from: 'Brokk', module: 'runes', kind: 'rune', message: 'audit entry sealed' },
    { from: 'Nornir', module: 'runes', kind: 'rune', message: 'daily brief carved to memory' },
    { from: 'Muninn', module: 'runes', kind: 'rune', message: 'chain verified end to end' },
    { from: 'Brokk', module: 'runes', kind: 'rune', message: 'rune export rendered' },
  ],
  reviews: [
    { from: 'Forseti', module: 'glitnir', kind: 'rune', message: 'PR diff opened for judgment' },
    { from: 'Forseti', module: 'glitnir', kind: 'rune', message: 'changes requested — blocking item noted' },
    { from: 'Mjollnir', module: 'glitnir', kind: 'rune', message: 'PR opened from issue' },
    { from: 'Brokk', module: 'glitnir', kind: 'rune', message: 'human approval required — never force-merge' },
    { from: 'Forseti', module: 'glitnir', kind: 'rune', message: 'seal granted after review' },
  ],
  processes: [
    { from: 'Valhalla', module: 'processes', kind: 'rune', message: 'daemon heartbeat nominal' },
    { from: 'Valhalla', module: 'processes', kind: 'rune', message: 'dead process detected — bring-back scheduled' },
    { from: 'Valhalla', module: 'processes', kind: 'rune', message: 'systemd unit restarted and counted' },
    { from: 'Valhalla', module: 'processes', kind: 'rune', message: 'docker container healthy' },
    { from: 'Valhalla', module: 'processes', kind: 'rune', message: 'pm2 watch restored' },
    { from: 'Valhalla', module: 'processes', kind: 'rune', message: 'restart budget within cap' },
  ],
  files: [
    { from: 'Skrymir', module: 'files', kind: 'rune', message: 'realm tree indexed' },
    { from: 'Skrymir', module: 'files', kind: 'rune', message: 'file checksum verified' },
    { from: 'Brokk', module: 'files', kind: 'rune', message: 'artifact written to workspace' },
    { from: 'Skrymir', module: 'files', kind: 'rune', message: 'realm boundary respected — no cross-tenant read' },
    { from: 'Brokk', module: 'files', kind: 'rune', message: 'upload staged for review' },
  ],
  chat: [
    { from: 'Kaia', module: 'mimirsbrunn', kind: 'rune', message: 'drinks from the well before every dispatch' },
    { from: 'Kaia', module: 'mimirsbrunn', kind: 'rune', message: 'recall hybrid — the Allfather’s question grounded' },
    { from: 'Kaia', module: 'chat', kind: 'ratatoskr', message: 'dispatch planned — Eindri chosen for the craft' },
    { from: 'Kaia', module: 'chat', kind: 'rune', message: 'reply spoken from the well, never dry' },
    { from: 'Brokk', module: 'chat', kind: 'rune', message: 'thread kept to the last 40 messages' },
    { from: 'Kaia', module: 'chat', kind: 'rune', message: 'answered from the local llama.cpp router' },
    { from: 'Kaia', module: 'chat', kind: 'rune', message: 'watered the well with what this turn taught' },
    { from: 'Kaia', module: 'mimirsbrunn', kind: 'rune', message: 'spreading recall walked the entity graph' },
    { from: 'Kaia', module: 'chat', kind: 'ratatoskr', message: 'addressing the Allfather — never zero direct address' },
    { from: 'Kaia', module: 'chat', kind: 'rune', message: 'conversation stored under state/chat/ for recall' },
    { from: 'Kaia', module: 'chat', kind: 'rune', message: 'faithful counsel — an outcome, not preamble' },
    { from: 'Kaia', module: 'mimirsbrunn', kind: 'rune', message: 'cache read served from prior context' },
    { from: 'Mimir', module: 'mimirsbrunn', kind: 'rune', message: 'the well is warm — drink before you act' },
    { from: 'Kaia', module: 'chat', kind: 'ratatoskr', message: 'sub-agent briefed and tracked to its lane' },
  ],
  forge: [
    { from: 'Gungnir', module: 'gungnir', kind: 'rune', message: 'skill synthesized and awaiting Utgard validation' },
    { from: 'Brokk', module: 'gungnir', kind: 'rune', message: 'agent forged — mythic name matched to craft' },
    { from: 'Gungnir', module: 'gungnir', kind: 'rune', message: 'prompt anvil struck — user.md re-set' },
    { from: 'Völundr', module: 'smidja', kind: 'rune', message: 'roster validated before spawn' },
    { from: 'Gungnir', module: 'gungnir', kind: 'rune', message: 'skill registered in the index' },
  ],
  runtime: [
    { from: 'Sága', module: 'runtime', kind: 'rune', message: 'session digest recited' },
    { from: 'Gleipnir', module: 'runtime', kind: 'rune', message: 'session lock bound to the live pid' },
    { from: 'Bifrost', module: 'runtime', kind: 'rune', message: 'model bridge raised' },
    { from: 'Sága', module: 'runtime', kind: 'rune', message: 'wake queue drained' },
    { from: 'Sýn', module: 'runtime', kind: 'rune', message: 'watch armed for the turn end' },
  ],
  cron: [
    { from: 'Nornir', module: 'nornir', kind: 'rune', message: 'daily briefing job completed' },
    { from: 'Nornir', module: 'nornir', kind: 'rune', message: 'observer job ran Huginn across the fleet' },
    { from: 'Nornir', module: 'nornir', kind: 'rune', message: 'memory housekeeping swept the well' },
    { from: 'Nornir', module: 'nornir', kind: 'rune', message: 'git sync advanced the world tree' },
    { from: 'Nornir', module: 'nornir', kind: 'rune', message: 'schedule ticked — 4 jobs healthy' },
  ],
  sessions: [
    { from: 'Völundr', module: 'smidja', kind: 'rune', message: 'run opened — phases planned' },
    { from: 'Smiðja', module: 'smidja', kind: 'rune', message: 'builder phase committed its work' },
    { from: 'Smiðja', module: 'smidja', kind: 'rune', message: 'quality gate passed — tests green' },
    { from: 'Smiðja', module: 'smidja', kind: 'rune', message: 'reviewer confirmed the ask' },
    { from: 'Smiðja', module: 'smidja', kind: 'rune', message: 'token and cost tallied into the run' },
  ],
  trace: [
    { from: 'Sýn', module: 'smidja', kind: 'rune', message: 'lane opened for a sub-agent dispatch' },
    { from: 'Sýn', module: 'smidja', kind: 'rune', message: 'span nested under the dispatcher' },
    { from: 'Sýn', module: 'smidja', kind: 'rune', message: 'tool call observed and timed' },
    { from: 'Sýn', module: 'smidja', kind: 'rune', message: 'context occupancy measured' },
    { from: 'Sýn', module: 'smidja', kind: 'rune', message: 'lane closed at acceptance' },
  ],
  decisions: [
    { from: 'Forseti', module: 'smidja', kind: 'rune', message: 'failure clustered by phase and model' },
    { from: 'Brokk', module: 'smidja', kind: 'rune', message: 'fix surfaced — strongest model advised' },
    { from: 'Forseti', module: 'smidja', kind: 'rune', message: 'JSON contract violation recorded' },
    { from: 'Brokk', module: 'smidja', kind: 'rune', message: 'repeated failure grouped — one fix, many runs' },
    { from: 'Forseti', module: 'smidja', kind: 'rune', message: 'no blocking failures — the forge holds' },
  ],
  stats: [
    { from: 'Brokk', module: 'smidja', kind: 'rune', message: 'run tallied — tokens and cost reconciled' },
    { from: 'Mimir', module: 'smidja', kind: 'rune', message: 'cache-hit ratio recomputed' },
    { from: 'Brokk', module: 'smidja', kind: 'rune', message: 'local vs online provider split updated' },
    { from: 'Mimir', module: 'smidja', kind: 'rune', message: 'commercial comparison priced against vendors' },
    { from: 'Brokk', module: 'smidja', kind: 'rune', message: 'by-chain rollup refreshed' },
  ],
  profile: [
    { from: 'Snotra', module: 'profile', kind: 'rune', message: 'tenant colour override applied' },
    { from: 'Snotra', module: 'profile', kind: 'rune', message: 'company house recorded' },
    { from: 'Snotra', module: 'profile', kind: 'rune', message: 'personal settings saved to the realm' },
    { from: 'Snotra', module: 'profile', kind: 'rune', message: 'realm default restored on reset' },
  ],
};

let counter = 0;

/** One page-appropriate event for the given gate. */
export function feedEvent(gate: GateId | string): StreamEvent {
  const pool = FEED[gate] ?? FEED.fleet;
  const line = pool[Math.floor(Math.random() * pool.length)];
  counter += 1;
  return {
    id: `feed-${Date.now()}-${counter}`,
    ts: new Date().toISOString(),
    kind: line.kind,
    from: line.from,
    to: line.kind === 'ratatoskr' ? 'Kaia' : undefined,
    state: line.kind === 'ratatoskr' ? 'WORKING' : undefined,
    module: line.module,
    message: line.message,
    checksum: Math.random().toString(16).slice(2, 8),
    gate: gate as GateId,
  };
}

/** Fill a page's feed with a handful of domain messages so it is never cold. */
export function seedGateFeed(gate: GateId | string, n = 12): StreamEvent[] {
  return Array.from({ length: n }, () => feedEvent(gate)).map((e, i) => ({
    ...e,
    ts: new Date(Date.now() - (n - i) * 2400).toISOString(),
  }));
}
