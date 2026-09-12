import type { DomainId, Session, TenantGrant, User } from '../types';
import { DOMAINS } from '../data/realms';

/**
 * MOCK GitHub auth (Heimdall / W0028 stand-in).
 *
 * Real flow: GitHub App code flow → token → `/user` → httpOnly JWT session
 * mapped to tenant grants. Until ymir-gate is raised, this issues a mock
 * session persisted to localStorage and scopes every realm to a grant.
 */

const SESSION_KEY = 'ymir.session';

export interface MockIdentity {
  login: string;
  name: string;
  email: string;
  tenants: TenantGrant[];
  /** no tenants yet → first login triggers workspace provisioning */
  firstRun?: boolean;
}

function grant(realm: string, tenant: string, role: TenantGrant['role'], domain: DomainId): TenantGrant {
  const d = DOMAINS[domain];
  return { realm, tenant, role, domain, tint: d.accent, glyph: d.glyph };
}

/**
 * Single-tenant model: one operator (the Allfather), many **workspaces**
 * (work | personal) over knowledge **domains**. Houses are brands, not realms.
 * A grant is now a workspace membership, kept for the UI's shape.
 */
export const MOCK_IDENTITIES: MockIdentity[] = [
  {
    login: 'zerwiz',
    name: 'Allfather (zerwiz)',
    email: 'zerwiz@ymir.local',
    tenants: [
      grant('work', 'Work', 'owner', 'ymirlabs'),
      grant('personal', 'Personal', 'owner', 'muninn'),
    ],
  },
];

function mockJwt(user: User): string {
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = btoa(
    JSON.stringify({ sub: user.login, iss: 'heimdall.mock', iat: Date.now() }),
  );
  return `${header}.${payload}.mock-signature`;
}

const LEGACY_REALMS = new Set(['way-of', 'zerwiz', 'craig']);

export function loadSession(): Session | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Session;
    if (!parsed?.user?.login || !Array.isArray(parsed.tenants)) return null;
    // Retire the multi-tenant realms: a legacy session migrates to the
    // single-tenant canonical workspaces (work + personal). craig is gone.
    if (parsed.tenants.some((t) => LEGACY_REALMS.has(t.realm))) {
      parsed.tenants = [
        grant('work', 'Work', 'owner', 'ymirlabs'),
        grant('personal', 'Personal', 'owner', 'muninn'),
      ];
      saveSession(parsed);
    }
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

/** Mock "Continue with GitHub" — exchanges an identity for a session. */
export function githubAuthorize(identity: MockIdentity): Session {
  const user: User = {
    login: identity.login,
    name: identity.name,
    email: identity.email,
    avatar: identity.login.slice(0, 2).toUpperCase(),
  };
  return {
    user,
    tenants: identity.tenants,
    method: 'github',
    issuedAt: new Date().toISOString(),
    token: mockJwt(user),
  };
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
  const user: User = {
    login: input.login,
    name: 'Allfather',
    email: `${input.login}@ymir.local`,
    avatar: input.login.slice(0, 2).toUpperCase(),
  };
  const domain: DomainId = input.kind === 'work' ? 'ymirlabs' : 'muninn';
  const base: TenantGrant[] = [
    grant('work', 'Work', 'owner', 'ymirlabs'),
    grant('personal', 'Personal', 'owner', 'muninn'),
  ];
  const exists = base.some((t) => t.realm === id);
  const tenants = exists ? base : [...base, grant(id, input.name || id, 'owner', domain)];
  return {
    user,
    tenants,
    method: 'github',
    issuedAt: new Date().toISOString(),
    token: mockJwt(user),
  };
}

export function tenantFor(session: Session | null, realm: string) {
  return session?.tenants.find((t) => t.realm === realm) ?? null;
}

export const ROLE_LABEL: Record<TenantGrant['role'], string> = {
  owner: 'Owner',
  admin: 'Admin',
  member: 'Member',
};
