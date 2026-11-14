import type { DomainId, RealmDef, Session, TenantGrant, User } from '../types';
// The explicit `.ts` is deliberate: the realm list is read by a node:test that runs
// in CI's pinned Node, which resolves no extensionless specifier (the app's bundler
// does, and tsconfig allows the extension for exactly this).
import { DEFAULT_WORKSPACES, DOMAINS } from '../data/realms.ts';

/**
 * The session the UI holds — the SEAT'S OWN record, not a credential.
 *
 * The halls are local (plan 275 item 30): there is no login, no invite and no
 * account store, because the desktop session is the authority. So this module no
 * longer mints or verifies anything; it shapes what the UI renders — who is
 * seated, and which workspaces (realms) exist on this machine. That list is the
 * operator's own registry, read from the home at run time, so no realm is hidden
 * by a pinned default (item 11's follow-up) and no realm's name is written here.
 */

const SESSION_KEY = 'ymir.session';

/** Which house a workspace without a colour of its own belongs to. */
const DOMAIN_OF_KIND: Record<string, DomainId> = { work: 'ymirlabs', personal: 'muninn' };

function grant(
  realm: string,
  tenant: string,
  role: TenantGrant['role'],
  domain: DomainId,
  tint?: string,
  glyph?: string,
): TenantGrant {
  const d = DOMAINS[domain];
  return { realm, tenant, role, domain, tint: tint ?? d.accent, glyph: glyph ?? d.glyph };
}

/** The workspaces (realms) that exist on this machine — the registry's own rows,
 *  or the shipped pair when the gate has not answered yet.
 *  `role` is kept in the shape because a workspace row still carries a display
 *  colour and a house; it grants nothing, and nothing asks for a grant. */
export function baseGrants(realms: RealmDef[] = DEFAULT_WORKSPACES): TenantGrant[] {
  return realms.map((r) =>
    grant(
      r.id,
      r.name ?? r.tenant ?? r.id,
      'owner',
      r.domain ?? DOMAIN_OF_KIND[r.kind ?? 'work'] ?? 'ymirlabs',
      r.tint,
      r.glyph,
    ),
  );
}

/**
 * The session for a login the gate has already verified.
 *
 * The gate owns authority; this only shapes what the UI renders. The display
 * name is the operator's own login — never a name borrowed from a previous
 * operator, and never a literal.
 */
export function sessionFor(login: string, realms: RealmDef[] = DEFAULT_WORKSPACES): Session {
  const user: User = {
    login,
    name: login,
    email: `${login}@ymir.local`,
    avatar: login.slice(0, 2).toUpperCase(),
  };
  return {
    user,
    tenants: baseGrants(realms),
    method: 'gate',
    issuedAt: new Date().toISOString(),
    token: '',
  };
}

export function loadSession(): Session | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Session;
    if (!parsed?.user?.login || !Array.isArray(parsed.tenants)) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function saveSession(session: Session): void {
  try {
    localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  } catch {
    /* ignore */
  }
}

export function clearSession(): void {
  try {
    localStorage.removeItem(SESSION_KEY);
  } catch {
    /* ignore */
  }
}

/** Provision a workspace for the operator (single tenant). The real disk work
 *  is done by the gate API (`/api/setup/run`); this shapes the session. */
export function provisionWorkspace(input: {
  login: string;
  name: string;
  kind: 'work' | 'personal';
  domains: string[];
}, realms: RealmDef[] = DEFAULT_WORKSPACES): Session {
  const id = input.name.toLowerCase().replace(/[^a-z0-9-]/g, '-') || 'workspace';
  const domain: DomainId = input.kind === 'work' ? 'ymirlabs' : 'muninn';
  const base = baseGrants(realms);
  const exists = base.some((t) => t.realm === id);
  const tenants = exists ? base : [...base, grant(id, input.name || id, 'owner', domain)];
  return { ...sessionFor(input.login, realms), tenants };
}

export function tenantFor(session: Session | null, realm: string) {
  return session?.tenants.find((t) => t.realm === realm) ?? null;
}

export const ROLE_LABEL: Record<TenantGrant['role'], string> = {
  owner: 'Owner',
  admin: 'Admin',
  member: 'Member',
};
