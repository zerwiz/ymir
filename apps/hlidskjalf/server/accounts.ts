/**
 * Accounts and invites for the gate.
 *
 * One operator owns the instance. The invite code is how someone *else* is let
 * in to try it: registration is closed unless a live code is presented, and a
 * code carries its own ceiling, so a shared link cannot quietly become an open
 * door.
 *
 * Two rules hold here:
 *  - the store is machine state, so it lives in the user's config dir and never
 *    inside the repo (nothing personal is ever tracked);
 *  - passwords are hashed with Bun's argon2id; the plaintext never lands.
 */
import { chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

export type Account = { login: string; hash: string; created: string };
export type Invite = { code: string; created: string; used: number; limit: number };
type Store = { version: 1; accounts: Account[]; invites: Invite[] };

/** Where the machine keeps its accounts (`YMIR_CONFIG_DIR` overrides, for tests). */
export const CONFIG_DIR = process.env.YMIR_CONFIG_DIR ?? join(homedir(), '.config', 'ymir');
export const STORE = join(CONFIG_DIR, 'accounts.json');

/** Default ceiling on how many accounts one invite may create. */
export const DEFAULT_INVITE_LIMIT = Number(process.env.YMIR_INVITE_LIMIT ?? 5);

/** The shortest password the gate will accept. */
const MIN_PASSWORD = 8;
const LOGIN_RE = /^[a-z0-9][a-z0-9._-]{1,31}$/;

function empty(): Store {
  return { version: 1, accounts: [], invites: [] };
}

export function load(): Store {
  if (!existsSync(STORE)) return empty();
  try {
    const s = JSON.parse(readFileSync(STORE, 'utf8')) as Store;
    return { version: 1, accounts: s.accounts ?? [], invites: s.invites ?? [] };
  } catch {
    return empty();
  }
}

function save(s: Store): void {
  mkdirSync(CONFIG_DIR, { recursive: true });
  writeFileSync(STORE, `${JSON.stringify(s, null, 2)}\n`, { mode: 0o600 });
  try {
    chmodSync(STORE, 0o600);
  } catch {
    /* best effort — the mode above is the real guard */
  }
}

/* ---- invites -------------------------------------------------------------- */

/** A code that is readable aloud but not guessable. */
export function mintCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1 — said aloud, not mistyped
  const block = () =>
    Array.from({ length: 4 }, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join('');
  return `YMIR-${block()}-${block()}`;
}

export type InviteCheck = { ok: true; invite: Invite } | { ok: false; reason: string };

/** Is this code live, and may it still admit another account? */
export function inviteCheck(code: string): InviteCheck {
  const wanted = code.trim().toUpperCase();
  if (!wanted) return { ok: false, reason: 'an invite code is required' };
  const invite = load().invites.find((i) => i.code === wanted);
  if (!invite) return { ok: false, reason: 'that invite code is not valid' };
  if (invite.used >= invite.limit) return { ok: false, reason: 'that invite code has been used up' };
  return { ok: true, invite };
}

/** Mint a code and record it. `limit` is how many accounts it may create. */
export function addInvite(limit = DEFAULT_INVITE_LIMIT): Invite {
  const s = load();
  const invite: Invite = { code: mintCode(), created: new Date().toISOString(), used: 0, limit };
  s.invites.push(invite);
  save(s);
  return invite;
}

export function listInvites(): Invite[] {
  return load().invites;
}

/** Remove a code. Returns whether anything was removed. */
export function revokeInvite(code: string): boolean {
  const s = load();
  const wanted = code.trim().toUpperCase();
  const before = s.invites.length;
  s.invites = s.invites.filter((i) => i.code !== wanted);
  if (s.invites.length !== before) {
    save(s);
    return true;
  }
  return false;
}

/** Is registration open at all? False when no live code exists. */
export function invitesOpen(): boolean {
  return load().invites.some((i) => i.used < i.limit);
}

/* ---- accounts ------------------------------------------------------------- */

export function findAccount(login: string): Account | undefined {
  const wanted = login.trim().toLowerCase();
  return load().accounts.find((a) => a.login === wanted);
}

export function listAccounts(): { login: string; created: string }[] {
  return load().accounts.map(({ login, created }) => ({ login, created }));
}

export type RegisterResult = { ok: true; login: string } | { ok: false; reason: string };

/**
 * Create an account, spending one use of the invite.
 *
 * The invite is checked *again* here, so a caller cannot skip it, and the store
 * is re-read so two simultaneous registrations cannot both spend the last use.
 */
export async function register(login: string, password: string, code: string): Promise<RegisterResult> {
  const name = login.trim().toLowerCase();
  if (!LOGIN_RE.test(name)) {
    return { ok: false, reason: 'a username is 2–32 characters: letters, digits, dot, dash, underscore' };
  }
  if (password.length < MIN_PASSWORD) {
    return { ok: false, reason: `a password of at least ${MIN_PASSWORD} characters is required` };
  }
  const check = inviteCheck(code);
  if (!check.ok) return { ok: false, reason: check.reason };

  const s = load();
  if (s.accounts.some((a) => a.login === name)) return { ok: false, reason: 'that username is taken' };
  const live = s.invites.find((i) => i.code === check.invite.code);
  if (!live) return { ok: false, reason: 'that invite code is not valid' };
  if (live.used >= live.limit) return { ok: false, reason: 'that invite code has been used up' };

  const hash = await Bun.password.hash(password, { algorithm: 'argon2id' });
  s.accounts.push({ login: name, hash, created: new Date().toISOString() });
  live.used += 1;
  save(s);
  return { ok: true, login: name };
}

/** Check a stored account's password. Returns the login on success. */
export async function verify(login: string, password: string): Promise<string | null> {
  const account = findAccount(login);
  if (!account) return null;
  const ok = await Bun.password.verify(password, account.hash).catch(() => false);
  return ok ? account.login : null;
}
