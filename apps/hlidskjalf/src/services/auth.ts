import type { DomainId, Session, TenantGrant, User } from '../types';
import { DOMAINS } from '../data/realms';

/**
 * The session the UI holds — the SEAT'S OWN record, not a credential.
 *
 * The halls are local (plan 275 item 30): there is no login, no invite and no
 * account store, because the desktop session is the authority. So this module no
 * longer mints or verifies anything; it shapes what the UI renders — who is
 * seated, and which workspaces (realms) exist on this machine. The tenant list is
 * the workspace registry's three, so no realm is hidden by a pinned default
 * (item 11's follow-up: the Personal and Svein shelves must stay visible).
 */

const SESSION_KEY = 'ymir.session';

function grant(realm: string, tenant: string, role: TenantGrant['role'], domain: DomainId): TenantGrant {
  const d = DOMAINS[domain];
  return { realm, tenant, role, domain, tint: d.accent, glyph: d.glyph };
}

/** The workspaces (realms) that exist on this machine — the registry's three.
 *  `role` is kept in the shape because a workspace row still carries a display
 *  colour and a house; it grants nothing, and nothing asks for a grant. */
export function baseGrants(): TenantGrant[] {
  return [
    grant('work', 'Work', 'owner', 'ymirlabs'),
    grant('personal', 'Personal', 'owner', 'muninn'),
    grant('svein', 'Svein', 'owner', 'dvalin'),
  ];
}

/**
 * The session for a login the gate has already verified.
 *
 * The gate owns authority; this only shapes what the UI renders. The display
 * name is the operator's own login — never a name borrowed from a previous
 * operator, and never a literal.
 */
export function sessionFor(login: string): Session {
  const user: User = {
    login,
    name: login,
    email: `${login}@ymir.local`,
    avatar: login.slice(0, 2).toUpperCase(),
  };
  return {
    user,
    tenants: baseGrants(),
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
}): Session {
  const id = input.name.toLowerCase().replace(/[^a-z0-9-]/g, '-') || 'workspace';
  const domain: DomainId = input.kind === 'work' ? 'ymirlabs' : 'muninn';
  const base = baseGrants();
  const exists = base.some((t) => t.realm === id);
  const tenants = exists ? base : [...base, grant(id, input.name || id, 'owner', domain)];
  return { ...sessionFor(input.login), tenants };
}

export function tenantFor(session: Session | null, realm: string) {
  return session?.tenants.find((t) => t.realm === realm) ?? null;
}

export const ROLE_LABEL: Record<TenantGrant['role'], string> = {
  owner: 'Owner',
  admin: 'Admin',
  member: 'Member',
};
