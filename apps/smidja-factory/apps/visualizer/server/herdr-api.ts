/**
 * GET /api/herdr/seats · POST /api/herdr/focus — the seats, as herdr sees them.
 *
 * A herdr agent runs in a PANE. That is the whole point of the surface: a person
 * can watch it work, and the Smíðja is where they look. So the board asks herdr
 * who is seated right now, and shows it — name, pane, live state, and the tree
 * the agent is working in.
 *
 * Two rules this file keeps:
 *
 *  - **It asks the door, it does not guess.** `herdr agent list` is the only
 *    source; there is no second table of who is running. When herdr cannot
 *    answer (no session, no binary), the response says so with a reason rather
 *    than an empty list — an empty list reads as "nobody is working", which is
 *    a different and much more dangerous claim (RULES/37).
 *  - **A pane id is not a credential.** Focus is the only write, it names one
 *    pane, and it changes nothing but which pane the human is looking at.
 */
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const run = promisify(execFile);

const HERDR = process.env.HERDR_PATH ?? "herdr";
/** How long a cached seat list may be served. The UI polls; herdr must not be. */
const CACHE_TTL_MS = 1_500;

export interface HerdrSeat {
  name: string;
  pane: string;
  tab: string;
  status: string;
  cwd: string;
  agent: string;
  /** `smj-<run>-<agent>` seats belong to a smidja run; the board marks them. */
  smidja: boolean;
  run: string;
  role: string;
}

export interface HerdrSeatsResponse {
  /** true when herdr answered; false when it could not, and `why` says why. */
  herdr: boolean;
  why: string;
  seats: HerdrSeat[];
  /** Seats this response can see, whether or not they belong to the open run. */
  total: number;
  at: string;
}

let cache: { at: number; data: HerdrSeatsResponse } | null = null;

/** A smidja seat is named `smj-<run8>-<agent>` by smidja_modules/agent_herdr.py. */
function parseSeatName(name: string): { smidja: boolean; run: string; role: string } {
  const match = /^smj-([^-]+)-(.+)$/.exec(name ?? "");
  if (!match) return { smidja: false, run: "", role: "" };
  return { smidja: true, run: match[1], role: match[2] };
}

async function readSeats(): Promise<HerdrSeatsResponse> {
  const at = new Date().toISOString();
  let stdout = "";
  try {
    ({ stdout } = await run(HERDR, ["agent", "list"], { timeout: 8_000 }));
  } catch (error) {
    const message = (error as Error).message ?? String(error);
    const why = /ENOENT/.test(message)
      ? `${HERDR} is not on PATH — this machine has no herdr`
      : `herdr did not answer \`agent list\`: ${message.split("\n")[0].slice(0, 200)}`;
    return { herdr: false, why, seats: [], total: 0, at };
  }

  let agents: Array<Record<string, unknown>> = [];
  try {
    const parsed = JSON.parse(stdout) as { result?: { agents?: Array<Record<string, unknown>> } };
    agents = parsed.result?.agents ?? [];
  } catch {
    return { herdr: false, why: "herdr answered with something that is not JSON", seats: [], total: 0, at };
  }

  const seats: HerdrSeat[] = agents.map((agent) => {
    const name = String(agent.name ?? "");
    const identity = parseSeatName(name);
    return {
      name,
      pane: String(agent.pane_id ?? ""),
      tab: String(agent.tab_id ?? ""),
      status: String(agent.agent_status ?? agent.status ?? "unknown"),
      cwd: String(agent.cwd ?? ""),
      agent: String(agent.agent ?? ""),
      ...identity,
    };
  });

  return { herdr: true, why: "", seats, total: seats.length, at };
}

/**
 * The seats, cached for a poll interval. `run` narrows to one run's seats — the
 * trace view asks for its own team, the global strip asks for all of them.
 */
export async function seats(run?: string): Promise<HerdrSeatsResponse> {
  const now = Date.now();
  if (!cache || now - cache.at > CACHE_TTL_MS) {
    cache = { at: now, data: await readSeats() };
  }
  const data = cache.data;
  if (!run) return data;
  const mine = data.seats.filter((seat) => seat.smidja && seat.run === run.slice(0, 8));
  return { ...data, seats: mine };
}

/** Bring one pane to the front. The only write, and it writes no state. */
export async function focus(pane: string): Promise<{ ok: boolean; why: string }> {
  if (!/^[\w:.@-]+$/.test(pane)) return { ok: false, why: "not a pane id" };
  try {
    await run(HERDR, ["agent", "focus", pane], { timeout: 8_000 });
    return { ok: true, why: "" };
  } catch (error) {
    return { ok: false, why: (error as Error).message.split("\n")[0].slice(0, 200) };
  }
}
