import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

function req(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env ${name}`);
  return v;
}

/** A secret from NAME, or from the file named by NAME_FILE (so keys need not sit in .env). */
function secret(name: string): string {
  const direct = process.env[name];
  if (direct) return direct;
  const file = process.env[`${name}_FILE`];
  if (file) return fs.readFileSync(file, 'utf8').trim();
  throw new Error(`Missing env ${name} (or ${name}_FILE)`);
}

function desk(v: string | undefined): 'local' | 'orgo' {
  const s = (v ?? '').trim().toLowerCase() || 'local';
  if (s !== 'local' && s !== 'orgo') throw new Error(`BILSKIRNIR_DESK must be "local" or "orgo", not ${JSON.stringify(v)}`);
  return s;
}

// plan 275 (2026-11-13): agent homes are named by their PHYSICAL path — Hermes ties a profile to the path it was
// given, and a path through the pin (~/ymir-runtime → releases/<sha>) changes at every release (profile_mismatch).
// An empty HERMES_HOME_PRIMARY is no answer either: `||`, never `??`.
const physical = (p: string) => { try { return fs.realpathSync(p); } catch { return p; } };
const hermesHome = physical(process.env.HERMES_HOME_PRIMARY || path.join(os.homedir(), '.hermes'));

export const env = {
  port: Number(process.env.PORT ?? 8787),
  appUrl: process.env.APP_URL ?? 'http://localhost:5173',
  /** Public URL of this server, used for OAuth callbacks. */
  serverUrl: process.env.SERVER_URL ?? `http://localhost:${process.env.PORT ?? 8787}`,
  /** Needed only on the xAI voice road (BILSKIRNIR_VOICE=xai) and for X search; the house road runs without it. */
  xaiKey: (process.env.BILSKIRNIR_VOICE ?? 'house').trim().toLowerCase() === 'xai' ? req('XAI_API_KEY') : (process.env.XAI_API_KEY ?? ''),
  xaiModel: process.env.XAI_MODEL ?? 'grok-4.7',
  /** Composio is an optional integration: empty or `unset` means it is off, never that the hall cannot start. */
  composioKey: process.env.COMPOSIO_API_KEY || 'unset',
  /** Only needed when BILSKIRNIR_DESK=orgo. */
  orgoKey: (() => { try { return secret('ORGO_API_KEY'); } catch { return ''; } })(),
  /**
   * Which computer the agents work on: `local` (default) is the hall's own desk, a container on this
   * machine started by house/desk.sh; `orgo` is an Orgo cloud computer (ORGO_API_KEY + ORGO_COMPUTER_ID).
   */
  desk: desk(process.env.BILSKIRNIR_DESK),
  sessionSecret: req('SESSION_SECRET'),
  devLogin: process.env.DEV_LOGIN === '1',
  /** Ymir runs this app on the operator's own machine: no sign-in. Set to the operator's email to enter as them. */
  localOperator: (process.env.LOCAL_OPERATOR ?? '').trim(),
  /** Loopback by default — a local app is never a public door (Ymir RULES/24). */
  host: process.env.HOST ?? '127.0.0.1',
  dbPath: process.env.DB_PATH ?? new URL('../../data/grokbot.db', import.meta.url).pathname,

  // ---- Hermes engine ----
  /** The `hermes` CLI used to start a gateway for each extra bot. */
  hermesBin: process.env.HERMES_BIN ?? 'hermes',
  /** The primary bot's Hermes home and API server (an agent that already runs; never restarted by us). */
  hermesHome,
  hermesUrl: (process.env.HERMES_URL ?? 'http://127.0.0.1:8642').replace(/\/+$/, ''),
  hermesKey: process.env.HERMES_KEY ?? '',
  /** Where each extra bot's own Hermes home lives. Must be outside ~/.hermes so it is a separate tenant. */
  enginesDir: physical(process.env.ENGINES_DIR || new URL('../../data/engines', import.meta.url).pathname),
  enginePortBase: Number(process.env.ENGINE_PORT_BASE ?? 8650),
  /** URL the Hermes gateways use to reach this server's MCP endpoint. */
  mcpBaseUrl: (process.env.MCP_BASE_URL ?? `http://127.0.0.1:${process.env.PORT ?? 8787}`).replace(/\/+$/, ''),
  /** Extra MCP servers every managed bot gets, as a JSON object of Hermes `mcp_servers` entries (e.g. X's XMCP). */
  extraMcpServers: process.env.EXTRA_MCP_SERVERS ?? '',
  primaryBotName: process.env.PRIMARY_BOT_NAME || 'unnamed',
  primaryBotLabel: process.env.PRIMARY_BOT_LABEL || '',

  // ---- the one shared computer ----
  /** The Orgo computer every bot works on (one screen each). Empty = legacy one-box-per-user mode is not supported. */
  orgoComputerId: process.env.ORGO_COMPUTER_ID ?? '',
  /** This server runs on that computer, so shell commands run locally instead of through Orgo's API. */
  localBox: process.env.HQ_LOCAL === '1',
  /**
   * DevTools URL of a Chrome that already runs on the default screen and belongs to the primary bot
   * (e.g. http://127.0.0.1:9333). When set, we never start or stop that screen's Chrome ourselves.
   */
  primaryCdpUrl: process.env.PRIMARY_CDP_URL ?? '',
  /** Bots that can each have a screen (Orgo allows four screens on one Linux computer). */
  maxBots: Number(process.env.MAX_BOTS ?? 4),
  /** Comma-separated emails allowed to sign in; empty = anyone who can reach the app. */
  allowedEmails: (process.env.ALLOWED_EMAILS ?? '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean),
};
