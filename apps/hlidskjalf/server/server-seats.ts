// server-seats.ts — which seats the Nornir board asks for their crons, read from the fleet (plan 278).
//
// The board shows the server seats' loops beside the local one. Until 2026-11-12 the list was two machine
// names written into the public code, which is both a leak (RULES/04, RULES/39) and an assumption no other
// operator's fleet shares. Now the list is resolved, in order:
//
//   1. YMIR_CRON_SERVER_SEATS="seat:sshhost …"   the operator's explicit word (unchanged)
//   2. the fleet registry ($YMIR_FLEET_REGISTRY, else <hoard>/data/fleet.json): every host whose roles
//      include `heart` or `forge`, other than this machine; the ssh host is the registry's name for it
//   3. nothing — a seat with no registry shows only its own loop, and says so
//
// No machine name is written here.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { hostname } from 'node:os';

export type ServerSeat = { seat: string; host: string };

const SERVER_ROLES = new Set(['heart', 'forge']);

export function parseSeatList(env: string): ServerSeat[] {
  return env.split(/\s+/).filter(Boolean).map((e) => {
    const [seat, host] = e.split(':');
    return { seat, host: host || seat };
  });
}

export function fleetServerSeats(registry: string, self: string = hostname()): ServerSeat[] {
  let hosts: Record<string, { roles?: unknown }> = {};
  try {
    hosts = (JSON.parse(readFileSync(registry, 'utf8')) as { hosts?: typeof hosts }).hosts ?? {};
  } catch {
    return [];
  }
  const me = self.split('.')[0].toLowerCase();
  return Object.entries(hosts)
    .filter(([name, h]) => name.toLowerCase() !== me
      && Array.isArray(h?.roles) && (h.roles as unknown[]).some((r) => SERVER_ROLES.has(String(r))))
    .map(([name]) => ({ seat: name, host: name }))
    .sort((a, b) => a.seat.localeCompare(b.seat));
}

export function serverSeats(hoard: string, env = process.env): ServerSeat[] {
  if (env.YMIR_CRON_SERVER_SEATS) return parseSeatList(env.YMIR_CRON_SERVER_SEATS);
  return fleetServerSeats(env.YMIR_FLEET_REGISTRY ?? join(hoard, 'data', 'fleet.json'));
}
