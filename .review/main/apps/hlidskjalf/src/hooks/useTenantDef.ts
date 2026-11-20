import { useYmir } from '../state/store';
import { realmDef } from '../data/realms';
import type { RealmDef, TenantGrant } from '../types';

/**
 * Resolve a realm definition, honouring the operator's per-tenant colour
 * override. The realm tint is structural — but the user may repaint their seat.
 */
export function useTenantDef(realm: string, grant?: TenantGrant | null): RealmDef {
  const override = useYmir((s) => s.tenantColors[realm]);
  const def = realmDef(realm, grant ?? undefined);
  return override ? { ...def, tint: override, tint2: override } : def;
}
