/**
 * Model catalog — the machine's pi-resolvable models, shared by every surface
 * that spawns pi (orchestrator chat, future pickers).
 *
 * There are two registries in the smidja:
 *   1. ROSTER models (roster.yaml)  — what smidja RUNS use for each agent role
 *   2. PI catalog (`pi --list-models`) — what this machine's pi can actually
 *      RESOLVE (providers the user has configured: lmstudio, opencode-go, ...)
 *
 * They differ (a roster id like `lmstudio/qwen3.5-9b` may not exist in the
 * machine's pi catalog, which is exactly the "Model not found" chat failure).
 * So: the CHAT picker shows the pi catalog; roster lists gain an `available`
 * flag by matching against it. One module, cached, used everywhere.
 */
import { existsSync } from "node:fs";
import { join } from "node:path";

export interface PiModel {
  id: string;       // provider/name — what pi resolves
  name: string;
  provider: string;
}

const CACHE_TTL_MS = 60_000;
let cache: { at: number; cwd: string; models: PiModel[] } | null = null;

/**
 * Cross-platform `pi` invocation. pi installs as a .cmd shim on Windows
 * (npm) and a shell binary on macOS/Linux/WSL, so we route Windows through
 * `cmd /c` and the rest directly. Bun.spawn resolves PATH for both.
 * For calls that carry free text (chat prompts) the args array is passed
 * through cmd's command-line builder, which quotes them safely.
 */
export function piCommand(args: string[]): string[] {
  return process.platform === "win32"
    ? ["cmd", "/c", "pi", ...args]
    : ["pi", ...args];
}

/** Shell `pi --list-models` (in the repo root) and normalize to {provider/name}. */
export async function piModels(cwd: string): Promise<PiModel[]> {
  if (cache && Date.now() - cache.at < CACHE_TTL_MS && cache.cwd === cwd) {
    return cache.models;
  }
  let models: PiModel[] = [];
  try {
    const proc = Bun.spawn(piCommand(["--list-models"]), {
      stdout: "pipe",
      stderr: "pipe",
      cwd,
      env: { ...(Bun.env as Record<string, string>) },
    });
    const out = await new Response(proc.stdout).text();
    for (const line of out.split(/\r?\n/)) {
      const cols = line.trim().split(/\s+/);
      if (cols.length < 2) continue;
      if (cols[0].startsWith("[") || /^provider$/i.test(cols[0])) continue;
      const provider = cols[0];
      const name = cols[1];
      if (!/^[A-Za-z0-9._-]+$/.test(provider) || !/^[A-Za-z0-9._/:@-]+$/.test(name)) continue;
      models.push({ id: `${provider}/${name}`, name, provider });
    }
    // Dedup (a model can repeat across runs) + stable sort.
    const seen = new Set<string>();
    models = models.filter((m) => (seen.has(m.id) ? false : (seen.add(m.id), true)));
    models.sort((a, b) => a.provider.localeCompare(b.provider) || a.name.localeCompare(b.name));
  } catch {
    models = [];
  }
  cache = { at: Date.now(), cwd, models };
  return models;
}

/**
 * True when the roster model id exists in the machine's pi catalog (i.e. the
 * chat / any pi spawn can run it). Match on the exact "provider/name" id.
 */
export function isPiResolvable(id: string, catalog: PiModel[]): boolean {
  return catalog.some((m) => m.id === id);
}

/** Cache-bust for tests / model installation. */
export function resetPiModelCache(): void {
  cache = null;
}

/** The repo .env (for parity with settings.ts); unused placeholder removed at
 * next sweep — kept for importing existsSync/join in this module's future use. */
void existsSync;
void join;