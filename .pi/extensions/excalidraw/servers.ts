/**
 * The fork's three services: probe, raise, lower.
 *
 * Nothing starts in the factory (Rule 13 §6) — a tool call is what starts a
 * process, so a session that merely loads this extension starts nothing.
 */

import { spawn, spawnSync } from "node:child_process";
import { join } from "node:path";

import { SERVICES, excalidrawRoot, isServiceName } from "./paths.ts";

import type { Service, ServiceName } from "./paths.ts";

export type ServiceStatus = {
  name: ServiceName;
  port: number;
  running: boolean;
  /** whatever /healthz answered, when it did */
  health: unknown;
  purpose: string;
  ticket: string;
};

const healthURL = (port: number) => `http://127.0.0.1:${port}/healthz`;

const probe = async (service: Service): Promise<{ running: boolean; health: unknown }> => {
  try {
    const response = await fetch(healthURL(service.port), {
      signal: AbortSignal.timeout(1200),
    });
    if (!response.ok) {
      return { running: false, health: `healthz returned ${response.status}` };
    }
    const body = await response.json().catch(() => null);
    return { running: true, health: body };
  } catch (error) {
    return { running: false, health: (error as Error)?.message ?? String(error) };
  }
};

export const status = async (name?: ServiceName): Promise<ServiceStatus[]> => {
  const services = name
    ? [SERVICES[name]]
    : Object.values(SERVICES).sort((a, b) => a.port - b.port);
  return Promise.all(
    services.map(async (service) => {
      const { running, health } = await probe(service);
      return {
        name: service.name,
        port: service.port,
        running,
        health,
        purpose: service.purpose,
        ticket: service.ticket,
      };
    }),
  );
};

/**
 * Raises a service. Extra environment is how the bridge learns its model —
 * it refuses to start without one, by design.
 */
export const start = async (
  name: ServiceName,
  env: Record<string, string | undefined> = {},
): Promise<{ ok: boolean; detail: string }> => {
  const service = SERVICES[name];
  const before = await probe(service);
  if (before.running) {
    return { ok: true, detail: `${name} was already up on :${service.port}` };
  }

  const root = excalidrawRoot();
  const script = join(root, service.script);
  const child = spawn(process.execPath, [script], {
    cwd: root,
    env: { ...process.env, ...env },
    detached: true,
    stdio: "ignore",
  });
  child.unref();

  // Poll for readiness rather than assuming the spawn worked.
  for (let attempt = 0; attempt < 20; attempt += 1) {
    await new Promise((resolve) => setTimeout(resolve, 300));
    const after = await probe(service);
    if (after.running) {
      return {
        ok: true,
        detail: `${name} is up on :${service.port} — ${JSON.stringify(after.health)}`,
      };
    }
  }
  return {
    ok: false,
    detail: `${name} did not answer on :${service.port} within 6s. Run it by hand to see why: node ${service.script}`,
  };
};

/** Lowers a service by whatever holds its port. Never a blanket pkill. */
export const stop = async (
  name: ServiceName,
): Promise<{ ok: boolean; detail: string }> => {
  const service = SERVICES[name];
  const before = await probe(service);
  if (!before.running) {
    return { ok: true, detail: `${name} was not running` };
  }

  // `-sTCP:LISTEN` is load-bearing: a bare `lsof -ti :PORT` also matches a
  // CLIENT socket on that port — and this function probes the port just above,
  // so the prober would appear in the list and stop() would kill itself.
  const found = spawnSync("lsof", ["-ti", `:${service.port}`, "-sTCP:LISTEN"], {
    encoding: "utf8",
  });
  const pids = (found.stdout ?? "")
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
  if (!pids.length) {
    return { ok: false, detail: `${name} answers but no pid holds :${service.port}` };
  }

  let killed = 0;
  for (const pid of pids) {
    try {
      process.kill(Number(pid));
      killed += 1;
    } catch {
      /* it went away between the listing and the kill */
    }
  }

  for (let attempt = 0; attempt < 10; attempt += 1) {
    await new Promise((resolve) => setTimeout(resolve, 200));
    const after = await probe(service);
    if (!after.running) {
      return { ok: true, detail: `${name} stopped (${killed} pid${killed === 1 ? "" : "s"})` };
    }
  }
  return { ok: false, detail: `${name} still answers on :${service.port}` };
};

export { isServiceName };
