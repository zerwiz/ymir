/**
 * Local settings — WayOfTeams MCP keys for the orchestrator chat (Kaia).
 *
 * Keys are stored in the target repo's `.env` (gitignored per repo convention),
 * chmod 600. The GET endpoint NEVER returns a secret's value — only whether it
 * is set plus a masked hint (last 4 chars), so a public tunnel cannot leak it.
 * POST updates allowlisted keys only.
 */
import { existsSync, readFileSync, writeFileSync, chmodSync } from "node:fs";
import { join } from "node:path";

/** Keys the settings page may read/write. Everything else is rejected. */
export const SETTING_KEYS = [
  "WAYOFTEAMS_MCP_TOKEN", // WayOfTeams per-user JWT (MCP bearer)
  "WOTEAMS_MCP_URL",      // base endpoint (default https://teamsapp.zerwiz.org)
  "WOTEAMS_AGENT_NAME",   // identity in the work registry
  "WOTEAMS_AGENT_ID",
] as const;

export type SettingKey = (typeof SETTING_KEYS)[number];

export interface SettingInfo {
  key: SettingKey;
  set: boolean;
  /** Masked hint for secrets (last 4 chars); plain value for non-secrets (URLs/names). */
  masked: string;
}

const SECRET_KEYS: ReadonlySet<string> = new Set(["WAYOFTEAMS_MCP_TOKEN"]);

function envPath(root: string): string {
  return join(root, ".env");
}

/** Parse a .env file into an ordered map (Key → value). Line/order preserved on write. */
export function parseEnv(text: string): Map<string, string> {
  const out = new Map<string, string>();
  for (const line of text.split(/\r?\n/)) {
    const m = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(line.trim());
    if (m) out.set(m[1], m[2]);
  }
  return out;
}

function readEnv(root: string): Map<string, string> {
  const p = envPath(root);
  if (!existsSync(p)) return new Map();
  return parseEnv(readFileSync(p, "utf8"));
}

function mask(value: string, key: string): string {
  if (SECRET_KEYS.has(key)) {
    const last = value.length > 4 ? value.slice(-4) : value;
    return `set · …${last}`;
  }
  return value;
}

export function listSettings(root: string): SettingInfo[] {
  const env = readEnv(root);
  return SETTING_KEYS.map((key) => {
    const v = env.get(key);
    return { key, set: !!v, masked: v ? mask(v, key) : "" };
  });
}

/**
 * Persist one key into the repo `.env` — update in place if present, append
 * otherwise; other keys/comments survive; file ends up mode 600.
 */
export function saveSetting(root: string, key: string, value: string): SettingInfo {
  if (!(SETTING_KEYS as readonly string[]).includes(key)) {
    throw new Error(`unknown setting key "${key}"`);
  }
  const clean = value.trim().replace(/\r?\n/g, "");
  if (clean.length > 4000) throw new Error("value too long");
  if (/[\0]/.test(clean)) throw new Error("invalid value");

  const p = envPath(root);
  let text = "";
  if (existsSync(p)) text = readFileSync(p, "utf8");
  const lines = text.split(/\r?\n/);
  const linesOut: string[] = [];
  let replaced = false;
  for (const line of lines) {
    const m = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(line.trim());
    if (m && m[1] === key) {
      linesOut.push(`${key}=${clean}`);
      replaced = true;
    } else {
      linesOut.push(line);
    }
  }
  if (!replaced) {
    if (text && !text.endsWith("\n")) linesOut.push("");
    linesOut.push(`${key}=${clean}`);
  }
  writeFileSync(p, linesOut.join("\n"), { mode: 0o600 });
  try {
    chmodSync(p, 0o600);
  } catch {
    /* chmod not available on all filesystems — best effort */
  }
  const v = clean;
  return { key: key as SettingKey, set: !!v, masked: v ? mask(v, key) : "" };
}