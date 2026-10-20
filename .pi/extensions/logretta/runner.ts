/**
 * runner — one clean-room child per seat, and the budget that stops the council.
 *
 * A seat is a SEPARATE `pi` PROCESS, not an in-process model call: that is the only
 * way two seats can be two different models at once, and it is what fusion-harness
 * proved. The child is spawned with:
 *
 *   -p --mode json --no-session --no-extensions --model <provider/id>
 *   --tools read,grep,find,ls
 *
 * `--no-extensions` stops the council from loading itself (recursion); `--tools` is
 * the read-only allowlist, so no seat can write, edit, or run a shell command. The
 * prompt goes over STDIN, never argv: no shell metacharacter can reach a shell.
 *
 * The budget is the other law here: a council must stop LOUDLY at the line rather
 * than quietly spend more. Wall-clock and total characters are both checked.
 */
import { spawn, type ChildProcess } from "node:child_process";

export interface SeatResult {
  slot: string;
  ok: boolean;
  text: string;
  ms: number;
  error?: string;
}

export interface RunOptions {
  model: string;
  prompt: string;
  cwd: string;
  timeoutSeconds: number;
  /** Test hook: override the pi executable (default: $LOGRETTA_PI or "pi"). */
  piPath?: string;
}

const KILL_GRACE_MS = 3000;

/** The exact argv a seat is given. Exported so a test can prove it is read-only. */
export function seatArgv(model: string): string[] {
  return [
    "-p",
    "--mode",
    "json",
    "--no-session",
    "--no-extensions",
    "--model",
    model,
    "--tools",
    "read,grep,find,ls",
  ];
}

export function runSeat(opts: RunOptions): Promise<SeatResult> {
  const started = Date.now();
  return new Promise((resolve) => {
    const argv = seatArgv(opts.model);
    const exe = opts.piPath ?? process.env.LOGRETTA_PI ?? "pi";
    let child: ChildProcess;
    try {
      child = spawn(exe, argv, { cwd: opts.cwd, stdio: ["pipe", "pipe", "pipe"] });
    } catch (err: any) {
      resolve({ slot: "", ok: false, text: "", ms: Date.now() - started, error: `spawn failed: ${err?.message ?? err}` });
      return;
    }

    let text = "";
    let errText = "";
    let buffer = "";
    let settled = false;
    let timedOut = false;

    const finish = (result: Omit<SeatResult, "slot" | "ms">) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve({ slot: "", ms: Date.now() - started, ...result });
    };

    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
      setTimeout(() => child.kill("SIGKILL"), KILL_GRACE_MS).unref?.();
    }, opts.timeoutSeconds * 1000);

    const applyLine = (line: string) => {
      const trimmed = line.trim();
      if (!trimmed) return;
      let event: any;
      try {
        event = JSON.parse(trimmed);
      } catch {
        return;
      }
      if (event?.type !== "message_update") return;
      const delta = event?.assistantMessageEvent?.delta;
      if (typeof delta === "string" && event.assistantMessageEvent.type === "text_delta") text += delta;
    };

    child.stdout?.on("data", (chunk: Buffer) => {
      buffer += chunk.toString("utf8");
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      for (const line of lines) applyLine(line);
    });
    child.stderr?.on("data", (chunk: Buffer) => {
      errText += chunk.toString("utf8");
    });
    child.on("error", (err) => finish({ ok: false, text, error: err.message }));
    child.on("close", (code) => {
      if (buffer) applyLine(buffer);
      if (timedOut) return finish({ ok: false, text, error: `timed out after ${opts.timeoutSeconds}s` });
      if (code === 0) return finish({ ok: true, text: text.trim() });
      const why = errText.trim() || text.trim() || `exit ${code}`;
      finish({ ok: false, text, error: why.slice(0, 400) });
    });

    child.stdin?.on("error", () => {});
    child.stdin?.end(opts.prompt);
  });
}

export interface CouncilRun {
  results: SeatResult[];
  stoppedForBudget: boolean;
  seconds: number;
}

export interface RoundOptions {
  cwd: string;
  timeoutSeconds: number;
  maxTotalChars: number;
  piPath?: string;
}

/**
 * Run one model call per task, honouring the budget. `tasks` carries one prompt per
 * seat. Remote seats run concurrently; local seats on a one-model rail are queued by
 * the server itself, so they simply take longer — the wall clock is reported, never
 * pretended away.
 */
export async function runRound(
  tasks: { slot: string; model: string; prompt: string }[],
  opts: RoundOptions,
): Promise<CouncilRun> {
  const started = Date.now();
  const results: SeatResult[] = [];
  let chars = 0;
  let stoppedForBudget = false;

  const run = async (task: { slot: string; model: string; prompt: string }) => {
    if (stoppedForBudget) return;
    const r = await runSeat({ ...task, cwd: opts.cwd, timeoutSeconds: opts.timeoutSeconds, piPath: opts.piPath });
    r.slot = task.slot;
    chars += r.text.length;
    if (chars > opts.maxTotalChars) stoppedForBudget = true;
    results.push(r);
  };

  await Promise.all(tasks.map(run));
  results.sort((a, b) => tasks.findIndex((t) => t.slot === a.slot) - tasks.findIndex((t) => t.slot === b.slot));
  return { results, stoppedForBudget, seconds: Math.round((Date.now() - started) / 100) / 10 };
}
