/**
 * GET /api/rosters, /api/rosters/:name, /api/models — the team & model picker
 * data for the orchestrator chat.
 *
 * Resolves the target repo's roster.yaml by shelling out to the companion
 * Python helper (server/roster_resolve.py), which mirrors scripts/resolve-config.py's
 * exact per-role model resolution. We shell out (not a YAML parser in TS) so the
 * picker always reflects what a real `smidja run` would use, with no duplicated
 * resolution logic and no extra dependency.
 *
 * The result is cached per repo-root for a short window; roster.yaml changes are
 * rare and the picker is not latency-critical, but we don't want to spawn python
 * on every keystroke either.
 */
import { existsSync } from "node:fs";
import { join } from "node:path";
import { repoRootOf as repoRoot } from "./db.ts";
import type { ModelInfo, RosterInfo, RostersResponse, ModelsResponse } from "../shared/types.ts";

/** Where the python helper lives, relative to this server dir. */
function helperPath(): string {
  return join(import.meta.dir, "roster_resolve.py");
}

interface ResolvedPayload {
  rosters: RosterInfo[];
  models: ModelInfo[];
}

const cache = new Map<string, { ts: number; data: ResolvedPayload }>();
const CACHE_TTL_MS = 5_000;

async function resolvePayload(dbPath: string): Promise<ResolvedPayload> {
  const root = repoRoot(dbPath);
  const key = root;
  const hit = cache.get(key);
  if (hit && Date.now() - hit.ts < CACHE_TTL_MS) return hit.data;

  const helper = helperPath();
  if (!existsSync(helper)) {
    throw new Error(`roster helper not found: ${helper}`);
  }

  const proc = Bun.spawn(
    ["python3", helper, root],
    { stdout: "pipe", stderr: "pipe" },
  );
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exit = await proc.exited;
  if (exit !== 0) {
    throw new Error(`roster resolve failed (${exit}): ${stderr.trim() || "unknown error"}`);
  }

  const data = JSON.parse(stdout) as ResolvedPayload;
  cache.set(key, { ts: Date.now(), data });
  return data;
}

export async function rosters(dbPath: string): Promise<RostersResponse> {
  return (await resolvePayload(dbPath)).rosters;
}

export async function roster(dbPath: string, name: string): Promise<RosterInfo> {
  const list = await rosters(dbPath);
  const found = list.find((r) => r.name === name);
  if (!found) throw new Error(`unknown roster '${name}'`);
  return found;
}

export async function models(dbPath: string): Promise<ModelsResponse> {
  return (await resolvePayload(dbPath)).models;
}
