/**
 * Mythology name engine — every Eindri earns a name whose myth matches its craft.
 * Gungnir naming law: capability → Norse figure → descriptor.
 */

export interface MythFigure {
  name: string;
  myth: string;
  descriptor: string;
  domains: string[];
  glyph: string;
}

export const MYTH_FIGURES: MythFigure[] = [
  { name: 'Brokk', myth: 'the bellows-smith', descriptor: 'forger', domains: ['build', 'forge', 'orchestration', 'dev', 'development', 'pipeline'], glyph: 'ᛒ' },
  { name: 'Sindri', myth: 'the smith', descriptor: 'smith', domains: ['code', 'frontend', 'backend', 'refactor', 'synthesis', 'typescript', 'react'], glyph: 'ᛊ' },
  { name: 'Eitri', myth: 'the craftsman', descriptor: 'craftsman', domains: ['design', 'ux', 'ui', 'css', 'component'], glyph: 'ᛖ' },
  { name: 'Bragi', myth: 'the skald', descriptor: 'skald', domains: ['marketing', 'content', 'seo', 'social', 'copy', 'brand', 'writing'], glyph: 'ᛒ' },
  { name: 'Huginn', myth: 'the raven (thought)', descriptor: 'sage', domains: ['research', 'analysis', 'search', 'rag', 'knowledge', 'discovery'], glyph: 'ᚺ' },
  { name: 'Muninn', myth: 'the raven (memory)', descriptor: 'keeper', domains: ['memory', 'recall', 'embeddings', 'vector', 'engram', 'well'], glyph: 'ᛗ' },
  { name: 'Tyr', myth: 'the one-handed judge', descriptor: 'judge', domains: ['validation', 'compliance', 'test', 'testing', 'audit', 'qa', 'lint'], glyph: 'ᛏ' },
  { name: 'Heimdall', myth: 'the watchman at Bifrost', descriptor: 'watcher', domains: ['auth', 'security', 'gateway', 'oauth', 'jwt', 'guard', 'identity'], glyph: 'ᚺ' },
  { name: 'Ratatoskr', myth: 'the squirrel of Yggdrasil', descriptor: 'messenger', domains: ['a2a', 'message', 'bus', 'queue', 'redis', 'dispatch', 'event'], glyph: 'ᚱ' },
  { name: 'Yggdrasil', myth: 'the world-tree', descriptor: 'weaver', domains: ['git', 'worktree', 'branch', 'merge', 'isolation'], glyph: 'ᛃ' },
  { name: 'Mimir', myth: 'the keeper of the well', descriptor: 'oracle', domains: ['knowledge', 'wisdom', 'documentation', 'docs'], glyph: 'ᛗ' },
  { name: 'Skrymir', myth: 'the giant of the halls', descriptor: 'giant', domains: ['files', 'storage', 's3', 'minio', 'browser', 'assets'], glyph: 'ᛊ' },
  { name: 'Valhalla', myth: 'the hall of the slain', descriptor: 'warden', domains: ['process', 'monitor', 'health', 'pm2', 'docker', 'supervision', 'uptime'], glyph: 'ᚢ' },
  { name: 'Hermod', myth: 'the messenger who crossed Hel', descriptor: 'bridge', domains: ['mcp', 'integration', 'bridge', 'cross-realm', 'tool'], glyph: 'ᚺ' },
  { name: 'Utgard', myth: 'the walled realm', descriptor: 'wall', domains: ['sandbox', 'container', 'docker', 'security', 'cgroups', 'seccomp'], glyph: 'ᚢ' },
  { name: 'Gungnir', myth: "Odin's spear that never misses", descriptor: 'spear', domains: ['skill', 'synthesis', 'tooling', 'cli'], glyph: 'ᚷ' },
  { name: 'Mjollnir', myth: 'the hammer that returns', descriptor: 'hammer', domains: ['issue', 'pr', 'bug', 'pipeline', 'github', 'fix'], glyph: 'ᛗ' },
  { name: 'Hlidskjalf', myth: "Odin's high seat", descriptor: 'seat', domains: ['dashboard', 'ui', 'observability', 'portal', 'frontend'], glyph: 'ᚺ' },
  { name: 'Gjallarhorn', myth: "Heimdall's horn", descriptor: 'horn', domains: ['tunnel', 'cloudflare', 'network', 'ingress', 'proxy'], glyph: 'ᚷ' },
  { name: 'Norns', myth: 'the weavers of fate', descriptor: 'weaver', domains: ['schedule', 'cron', 'time', 'planning', 'automation'], glyph: 'ᚾ' },
  { name: 'Idunn', myth: 'keeper of the apples', descriptor: 'healer', domains: ['maintenance', 'recovery', 'backup', 'restore', 'healing'], glyph: 'ᛁ' },
  { name: 'Andvari', myth: 'the dwarf of the hoard', descriptor: 'treasurer', domains: ['secrets', 'keys', 'vault', 'env', 'credentials', 'stripe'], glyph: 'ᚨ' },
  { name: 'Forseti', myth: 'the settler of disputes', descriptor: 'arbiter', domains: ['review', 'approval', 'mediation', 'pr', 'policy'], glyph: 'ᚠ' },
  { name: 'Loki', myth: 'the shape-changer', descriptor: 'trickster', domains: ['chaos', 'fuzz', 'edge-case', 'red-team', 'stress'], glyph: 'ᛚ' },
  { name: 'Surtr', myth: 'the fire giant', descriptor: 'ember', domains: ['security', 'firewall', 'red-team', 'pentest', 'threat'], glyph: 'ᛊ' },
  { name: 'Skadi', myth: 'the winter huntress', descriptor: 'hunter', domains: ['monitor', 'alert', 'telemetry', 'metrics', 'trace', 'observe'], glyph: 'ᛊ' },
  { name: 'Njord', myth: 'the lord of the sea', descriptor: 'trader', domains: ['finance', 'billing', 'revenue', 'business', 'growth'], glyph: 'ᚾ' },
  { name: 'Freyr', myth: 'the giver of peace and plenty', descriptor: 'grower', domains: ['growth', 'life', 'wellbeing', 'habit', 'personal'], glyph: 'ᚠ' },
];

const AETTS = ['galdr', 'mimir', 'yggd', 'rat', 'heimd', 'bifr', 'val', 'skyr', 'gung', 'mjoll', 'hlid'] as const;

export interface NameSuggestion {
  figure: MythFigure;
  score: number;
}

/** Rank myth figures against a free-text capability/role description. */
export function suggestFigures(text: string, limit = 3): NameSuggestion[] {
  const tokens = text
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((t) => t.length > 2);

  const scored = MYTH_FIGURES.map((figure) => {
    let score = 0;
    for (const d of figure.domains) {
      if (tokens.some((t) => t.includes(d) || d.includes(t))) score += 2;
      if (text.toLowerCase().includes(d)) score += 1;
    }
    return { figure, score };
  })
    .filter((s) => s.score > 0)
    .sort((a, b) => b.score - a.score);

  if (scored.length >= limit) return scored.slice(0, limit);

  // fill with a stable selection (by name) if not enough domain hits
  const used = new Set(scored.map((s) => s.figure.name));
  const filler = MYTH_FIGURES.filter((f) => !used.has(f.name))
    .slice(0, limit - scored.length)
    .map((figure) => ({ figure, score: 0 }));
  return [...scored, ...filler];
}

export function aettFor(text: string): string {
  const t = text.toLowerCase();
  if (/memory|recall|well|engram|vector/.test(t)) return 'mimir';
  if (/git|worktree|branch|tree/.test(t)) return 'yggd';
  if (/message|a2a|bus|queue/.test(t)) return 'rat';
  if (/auth|guard|security|identity/.test(t)) return 'heimd';
  if (/gateway|proxy|ingress|bridge/.test(t)) return 'bifr';
  if (/process|health|monitor|supervis/.test(t)) return 'val';
  if (/file|storage|asset/.test(t)) return 'skyr';
  if (/skill|synthesis|tool/.test(t)) return 'gung';
  if (/issue|pr|bug|pipeline/.test(t)) return 'mjoll';
  if (/dashboard|ui|portal|observ/.test(t)) return 'hlid';
  return 'galdr';
}

export const AETTS_LIST = AETTS;
