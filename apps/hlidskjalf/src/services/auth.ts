import type { HouseId, Session, TenantGrant, User } from '../types';
import { HOUSES } from '../data/realms';

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

function grant(realm: string, tenant: string, role: TenantGrant['role'], house: HouseId): TenantGrant {
  const h = HOUSES[house];
  return { realm, tenant, role, house, tint: h.accent, glyph: h.glyph };
}

/**
 * Tenant model:
 *   WayOf is the company. zerwiz (the captain) and craig are both members of
 *   WayOf; each also carries a personal realm. Boundaries are still sacred —
 *   a grant is required to enter any realm.
 */
export const MOCK_IDENTITIES: MockIdentity[] = [
  {
    login: 'zerwiz',
    name: 'Josef (zerwiz)',
    email: 'zerwiz@ymir.local',
    tenants: [
      grant('way-of', 'WayOf', 'owner', 'ymirlabs'),
      grant('zerwiz', 'Zerwiz', 'owner', 'muninn'),
      grant('craig', 'Craig', 'admin', 'brokkforge'),
    ],
  },
  {
    login: 'craig',
    name: 'Craig',
    email: 'craig@ymir.local',
    tenants: [
      grant('way-of', 'WayOf', 'member', 'ymirlabs'),
      grant('craig', 'Craig', 'owner', 'brokkforge'),
    ],
  },
  {
    login: 'newdev',
    name: 'New Developer',
    email: 'newdev@ymir.local',
    tenants: [],
    firstRun: true,
  },
];

function mockJwt(user: User): string {
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = btoa(
    JSON.stringify({ sub: user.login, iss: 'heimdall.mock', iat: Date.now() }),
  );
  return `${header}.${payload}.mock-signature`;
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

/** First-run workspace provisioning (mock of the W0029 provisioner). */
export function provisionWorkspace(input: {
  login: string;
  name: string;
  house: HouseId;
  cloneRepos: boolean;
}): Session {
  const realm = input.login.toLowerCase().replace(/[^a-z0-9-]/g, '-');
  const user: User = {
    login: input.login,
    name: input.name,
    email: `${input.login}@ymir.local`,
    avatar: input.login.slice(0, 2).toUpperCase(),
  };
  return {
    user,
    tenants: [
      grant(realm, input.name || input.login, 'owner', input.house),
    ],
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
