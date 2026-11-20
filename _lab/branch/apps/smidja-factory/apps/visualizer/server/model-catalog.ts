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
import { accessSync, constants, existsSync } from "node:fs";
import { homedir } from "node:os";
import { delimiter, join } from "node:path";

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
/**
 * WHERE `pi` IS — resolved, never assumed.
 *
 * Measured 2026-10-20: the visualizer runs as a systemd USER service whose PATH is
 * `%h/.bun/bin:/usr/bin:/bin`, and pi installs to `~/.npm-global/bin`. Every chat
 * message died with `Executable not found in $PATH: "pi"` while `pi` worked perfectly in
 * a terminal — the classic service-PATH failure, and the reason "Kaia is offline" was
 * showing for a healthy bridge.
 *
 * Order (Rule 07 — one documented default, overridable):
 *   1. `YMIR_PI_BIN` — an explicit path, for a unit or a wrapper that knows better
 *   2. `PI_BIN`      — the conventional name other tools use
 *   3. PATH          — whatever the environment already resolves
 *   4. the install locations a bare npm prefix produces, in this house's order
 *
 * A path that does not exist is skipped, not trusted: a stale override must not win over
 * a real binary on PATH.
 */
const PI_FALLBACKS = [
  "~/.npm-global/bin/pi",
  "~/.local/bin/pi",
  "/usr/local/bin/pi",
  "/opt/homebrew/bin/pi",
  "/usr/bin/pi",
];

function expandHome(p: string): string {
  return p.startsWith("~/") ? join(homedir(), p.slice(2)) : p;
}

/** True when `candidate` is an executable file (or a Windows shim). */
function executable(candidate: string): boolean {
  if (!existsSync(candidate)) return false;
  try {
    accessSync(candidate, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

let cachedPi: { at: number; path: string } | null = null;

/** Tests and a service that changed its environment both need a fresh answer. */
export function resetPiPathCache(): void {
  cachedPi = null;
}

/** The absolute path to `pi`, or "pi" when nothing was found (the OS reports it then). */
export function piPath(): string {
  if (process.platform === "win32") return "pi";
  const now = Date.now();
  if (cachedPi && now - cachedPi.at < CACHE_TTL_MS) return cachedPi.path;

  const explicit = process.env.YMIR_PI_BIN?.trim() || process.env.PI_BIN?.trim();
  if (explicit) {
    const abs = expandHome(explicit);
    if (executable(abs)) {
      cachedPi = { at: now, path: abs };
      return abs;
    }
  }

  for (const dir of (process.env.PATH ?? "").split(delimiter)) {
    if (!dir) continue;
    const candidate = join(dir, "pi");
    if (executable(candidate)) {
      cachedPi = { at: now, path: candidate };
      return candidate;
    }
  }

  for (const fallback of PI_FALLBACKS) {
    const abs = expandHome(fallback);
    if (executable(abs)) {
      cachedPi = { at: now, path: abs };
      return abs;
    }
  }
  return "pi";
}

export function piCommand(args: string[]): string[] {
  if (process.platform === "win32") return ["cmd", "/c", "pi", ...args];
  return [piPath(), ...args];
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