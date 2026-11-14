// realms-registry.test.ts — the realm list is the operator's own, read from the home at run time,
// and the shipped build carries only a generic pair (RULES/04). Written on node:test so CI's Node
// runs it as it stands; bun runs it too.
//   node --test apps/hlidskjalf/server/realms-registry.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  DEFAULT_WORKSPACES,
  realmById,
  realmFromRegistry,
  realmsFromRegistry,
  type WorkspaceRow,
} from '../src/data/realms.ts';
import { baseGrants, sessionFor } from '../src/services/auth.ts';

/* The realm list is private data (RULES/04). It ships as a generic pair and is
 * READ from the operator's own registry in the home at run time. These are the
 * planted worlds that prove both halves: a registry of one's own lands, and a
 * home with none still opens. */

const REGISTRY: WorkspaceRow[] = [
  { id: 'work', name: 'Work', kind: 'work', company: 'a-house', domains: ['company', 'development'] },
  { id: 'personal', name: 'Personal', kind: 'personal', domains: ['me'] },
  { id: 'ocl-1', name: 'Acme Holdings', kind: 'work', company: 'acme', domains: ['company', 'marketing'] },
];

const HERE = dirname(fileURLToPath(import.meta.url));
const SRC = readFileSync(join(HERE, '../src/data/realms.ts'), 'utf8');

describe('the shipped realm list is generic', () => {
  test('it carries exactly two realms, and neither is a person or a company', () => {
    assert.deepEqual(DEFAULT_WORKSPACES.map((r) => r.id), ['work', 'personal']);
    for (const r of DEFAULT_WORKSPACES) {
      assert.equal(r.company, undefined);
      assert.equal(r.name, r.id === 'work' ? 'Work' : 'Personal');
    }
  });

  test('no registry realm name is written in the shipped file', () => {
    // The fence that matters: a realm's own name comes from the home. If one is
    // hardcoded here again, this fails and names it.
    for (const row of REGISTRY) {
      if (row.id === 'work' || row.id === 'personal') continue;
      assert.equal(SRC.includes(row.name as string), false);
    }
  });
});

describe('the registry decides the realms', () => {
  test('every row lands, in the registry order, under the registry name', () => {
    const realms = realmsFromRegistry(REGISTRY);
    assert.deepEqual(realms.map((r) => r.id), ['work', 'personal', 'ocl-1']);
    assert.deepEqual(realms.map((r) => r.name), ['Work', 'Personal', 'Acme Holdings']);
    assert.equal(realms[2].kind, 'work');
    assert.deepEqual(realms[2].domains, ['company', 'marketing']);
  });

  test('a realm the shipped pair does not know wears a stable seal of its own', () => {
    const a = realmFromRegistry({ id: 'ocl-1', name: 'Acme Holdings', kind: 'work' });
    const b = realmFromRegistry({ id: 'ocl-1', name: 'Renamed Holdings', kind: 'work' });
    assert.equal(a.id, 'ocl-1');
    // The name is the operator's; the seal follows the ID, so a rename keeps it.
    assert.equal(b.name, 'Renamed Holdings');
    assert.deepEqual([a.tint, a.tint2, a.glyph], [b.tint, b.tint2, b.glyph]);
    assert.ok(a.glyph.length > 0);
  });

  test('the two realms the build knows keep their own colour and rune', () => {
    for (const known of DEFAULT_WORKSPACES) {
      const fromRegistry = realmFromRegistry({ id: known.id, name: known.name });
      assert.equal(fromRegistry.tint, known.tint);
      assert.equal(fromRegistry.glyph, known.glyph);
    }
  });

  test('a blank or duplicated row is dropped, never drawn twice', () => {
    const realms = realmsFromRegistry([
      { id: 'work', name: 'Work' },
      { id: 'work', name: 'Work again' },
      { id: '', name: 'nameless' },
      { id: 'ocl-1', name: 'Acme Holdings' },
    ] as WorkspaceRow[]);
    assert.deepEqual(realms.map((r) => r.id), ['work', 'ocl-1']);
    assert.equal(realms[0].name, 'Work');
  });
});

describe('a home with no registry still opens', () => {
  test('an empty registry, a null one and a missing one all answer the shipped pair', () => {
    for (const rows of [[], null, undefined]) {
      assert.deepEqual(realmsFromRegistry(rows as WorkspaceRow[] | null | undefined).map((r) => r.id), [
        'work',
        'personal',
      ]);
    }
  });

  test('a realm that is in no list still resolves instead of crashing the page', () => {
    assert.equal(realmById('nowhere', []).id, 'work');
    assert.equal(realmById('ocl-1', realmsFromRegistry(REGISTRY)).name, 'Acme Holdings');
  });
});

describe('the seat is shaped by the same list', () => {
  test('one grant per realm, carrying the registry name and the realm tint', () => {
    const realms = realmsFromRegistry(REGISTRY);
    const grants = baseGrants(realms);
    assert.deepEqual(grants.map((g) => g.realm), ['work', 'personal', 'ocl-1']);
    assert.equal(grants[2].tenant, 'Acme Holdings');
    assert.equal(grants[2].tint, realms[2].tint);
  });

  test('no realm is hidden from the session: every registry row is a tenant', () => {
    const realms = realmsFromRegistry(REGISTRY);
    const session = sessionFor('operator', realms);
    assert.equal(session.tenants.length, REGISTRY.length);
  });

  test('the shipped pair is the default when no realms are handed in', () => {
    assert.deepEqual(baseGrants().map((g) => g.realm), ['work', 'personal']);
    assert.deepEqual(sessionFor('operator').tenants.map((g) => g.realm), ['work', 'personal']);
  });
});
