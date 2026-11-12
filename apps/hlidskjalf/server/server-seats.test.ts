// server-seats.test.ts — the Nornir board's server seats come from the fleet registry, never from names
// written in the code (plan 278). Written on node:test so CI's Node runs it as it stands; bun runs it too.
//   node --test apps/hlidskjalf/server/server-seats.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fleetServerSeats, parseSeatList, serverSeats } from './server-seats.ts';

const dir = mkdtempSync(join(tmpdir(), 'seats-'));
const reg = join(dir, 'fleet.json');
writeFileSync(reg, JSON.stringify({
  heart: 'heart-host',
  hosts: {
    'heart-host': { roles: ['heart', 'forge'] },
    'gpu-host': { roles: ['forge'] },
    'dev-host': { roles: ['dev'] },
    'phone-host': { roles: ['hand'] },
  },
}));

describe('server seats', () => {
  test('the heart and forge hosts are the server seats', () => {
    assert.deepEqual(fleetServerSeats(reg, 'dev-host').map((s) => s.seat), ['gpu-host', 'heart-host']);
  });
  test('this machine is never its own server seat', () => {
    assert.deepEqual(fleetServerSeats(reg, 'heart-host.lan').map((s) => s.seat), ['gpu-host']);
  });
  test('no registry is no seats, not an invented one', () => {
    assert.deepEqual(fleetServerSeats(join(dir, 'absent.json'), 'dev-host'), []);
  });
  test("the operator's explicit list still wins", () => {
    assert.deepEqual(serverSeats(dir, { YMIR_CRON_SERVER_SEATS: 'a:alias b' }),
      [{ seat: 'a', host: 'alias' }, { seat: 'b', host: 'b' }]);
    assert.deepEqual(parseSeatList('x'), [{ seat: 'x', host: 'x' }]);
  });
  test('the registry under the hoard is the default road', () => {
    const hoard = mkdtempSync(join(tmpdir(), 'hoard-'));
    mkdirSync(join(hoard, 'data'));
    writeFileSync(join(hoard, 'data', 'fleet.json'), readFileSync(reg));
    assert.ok(serverSeats(hoard, {}).length > 0);
  });
  test('the server code names no seat of its own', () => {
    const src = readFileSync(join(import.meta.dirname, 'index.ts'), 'utf8');
    assert.doesNotMatch(src, /DEFAULT_SERVER_SEATS\s*=\s*\[/);
  });
});
