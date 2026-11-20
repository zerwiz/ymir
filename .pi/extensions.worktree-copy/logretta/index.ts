/**
 * logretta — the council of models: several minds on one question, and a verdict.
 *
 * Lögrétta was the law council of the Althing: the assembly that hears a case, argues
 * it, and hands down one judgement. This is that council for models (plan 92).
 *
 * WHAT IT IS. Two to five seats, each a different model with a ROLE LENS, answering
 * one question; then a debate round where each seat sees the others; then an arbiter
 * that merges the answers and NAMES the disagreements instead of smoothing them.
 *
 * WHAT IT IS NOT. It writes no code, opens no shell, and touches no file. Every seat
 * is a clean-room `pi` child limited to read tools. A verdict is a RECORD — the
 * caller writes it (Elder's `ymir_note` / `ymir_plan`), and any work it implies is a
 * separate errand, with its own gate.
 *
 * WHY CHILDREN. A different model per seat means a different process: pi's own model
 * is fixed per session. fusion-harness proved the shape (`pi -p --mode json
 * --no-extensions --model … --tools read,grep,find,ls`); this is the house's version,
 * with a stack file, a budget, and the local-rail truth printed before a run.
 *
 * THE RAIL'S TRUTH (heimdall, 2026-10-20): llama-swap runs `--models-max 1` with
 * `parallel = 1`. Local seats therefore speak IN TURN; hosted seats run in parallel.
 * `queueLine()` says so before the first token is spent, and the run reports seconds.
 *
 * Configuration (Rule 07 — nothing hardcoded):
 *   LOGRETTA_STACK   path to the stack file
 *   YMIR_HOME        the vault; the stack is read from <home>/config/logretta-stack.yaml
 * With neither, the tool SKIPS LOUDLY rather than inventing a roster.
 *
 * Placement: `.pi/extensions/logretta/` — one home, a directory with an index.ts
 * (RULES/13). Deployed by `bin/seat/valknut-load.sh`.
 */
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import { parseStack, queueLine, stackToon, StackError, type Stack } from "./stack.ts";
import { debatePrompt, opinionPrompt, verdictPrompt } from "./prompt.ts";
import { runRound, type SeatResult } from "./runner.ts";

function resolveRoot(): string {
  const fromEnv = process.env.YMIR_ROOT?.trim();
  if (fromEnv) return fromEnv;
  const pointer = join(homedir(), ".pi", "agent", "extensions", ".ymir-root");
  if (existsSync(pointer)) {
    for (const line of readFileSync(pointer, "utf8").split("\n")) {
      const root = line.trim();
      if (root && existsSync(join(root, "bin"))) return root;
    }
  }
  return process.cwd();
}

function resolveHome(): string | undefined {
  const fromEnv = process.env.YMIR_HOME?.trim();
  if (fromEnv) return fromEnv;
  try {
    const hoard = execFileSync("bash", [join(resolveRoot(), "bin", "vault", "hodd.sh"), "path"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    return hoard ? dirname(hoard) : undefined;
  } catch {
    return undefined;
  }
}

function stackPath(): string | undefined {
  const explicit = process.env.LOGRETTA_STACK?.trim();
  if (explicit) return explicit;
  const home = resolveHome();
  return home ? join(home, "config", "logretta-stack.yaml") : undefined;
}

function loadStack(): { stack?: Stack; path?: string; problem?: string } {
  const path = stackPath();
  if (!path) return { problem: "no stack configured: set LOGRETTA_STACK or YMIR_HOME (the stack lives at <home>/config/logretta-stack.yaml)" };
  if (!existsSync(path)) {
    return { path, problem: `no stack at ${path}\nhelp: copy config/logretta-stack.example.yaml there and set your models` };
  }
  try {
    return { stack: parseStack(readFileSync(path, "utf8")), path };
  } catch (err: any) {
    const msg = err instanceof StackError ? err.message : String(err?.message ?? err);
    return { path, problem: `the stack is invalid: ${msg}` };
  }
}

const out = (text: string, isError = false) => ({
  content: [{ type: "text" as const, text }],
  isError: isError || undefined,
  details: undefined,
});

/** Keep a seat's answer short enough that a five-seat verdict stays readable. */
function clip(text: string, max: number): string {
  const t = text.trim();
  return t.length <= max ? t : `${t.slice(0, max)}…`;
}

export default function logretta(pi: any) {
  pi.registerTool({
    name: "logretta_stack",
    description:
      "Show the council's roster from the stack file, validate it, and print the honest queue " +
      "(local seats speak in turn on a one-model rail; hosted seats run in parallel). Reads the " +
      "stack at $LOGRETTA_STACK or <YMIR_HOME>/config/logretta-stack.yaml.",
    parameters: { type: "object", properties: {}, required: [] },
    async execute(_id: string) {
      const { stack, path, problem } = loadStack();
      if (problem || !stack) return out(`${problem}\nstack: ${path ?? "(unresolved)"}`, true);
      return out(`${stackToon(stack)}\nstack: ${path}`);
    },
  });

  pi.registerTool({
    name: "logretta_sit",
    description:
      "Sit a council on ONE question: every seat answers through its lens, a debate round lets " +
      "each seat revise after reading the others (delimited as untrusted), and the arbiter merges " +
      "into one verdict that names the disagreements. Read-only: every seat is a clean-room pi " +
      "child limited to read tools. Writes nothing — record the verdict with ymir_note or ymir_plan.",
    parameters: {
      type: "object",
      properties: {
        topic: { type: "string", description: "the question the council must answer" },
        recall: { type: "string", description: "optional: what the house already knows (from the well), handed to every seat" },
        rounds: { type: "number", description: "1 = opinions + verdict only, 2 = add the debate round (default: the stack's own)" },
      },
      required: ["topic"],
    },
    async execute(_id: string, args: any, _signal?: any, onUpdate?: any, ctx?: any) {
      const topic = String(args?.topic ?? "").trim();
      if (!topic) return out("logretta_sit needs `topic` — the question the council must answer.", true);

      const { stack, path, problem } = loadStack();
      if (problem || !stack) return out(`${problem}\nstack: ${path ?? "(unresolved)"}`, true);

      const rounds = args?.rounds === undefined ? stack.rounds : Number(args.rounds);
      if (!Number.isInteger(rounds) || rounds < 1 || rounds > 3) {
        return out(`rounds must be 1–3, got '${args.rounds}'`, true);
      }

      const cwd = String(ctx?.cwd ?? process.cwd());
      const recall = String(args?.recall ?? "");
      const runOpts = { cwd, timeoutSeconds: stack.timeoutSeconds, maxTotalChars: stack.maxTotalChars };
      const lines: string[] = [];
      const say = (line: string) => {
        lines.push(line);
        try {
          onUpdate?.({ content: [{ type: "text", text: lines.join("\n") }] });
        } catch {
          /* streaming is a courtesy, never a requirement */
        }
      };

      say(`council ${stack.name} · ${stack.slots.length} seats · ${queueLine(stack)}`);

      const opinion = await runRound(
        stack.slots.map((s) => ({ slot: s.name, model: s.model, prompt: opinionPrompt(topic, s.name, recall) })),
        runOpts,
      );
      const spoke = opinion.results.filter((r) => r.ok && r.text);
      for (const r of opinion.results) {
        say(r.ok ? `· ${r.slot} (${r.ms}ms, ${r.text.length} chars)` : `· ${r.slot} FAILED: ${r.error}`);
      }
      if (!spoke.length) {
        return out(`${lines.join("\n")}\nno seat produced an answer — nothing to judge`, true);
      }

      let finalists: SeatResult[] = spoke;

      if (rounds >= 2) {
        const debate = await runRound(
          spoke.map((r) => ({
            slot: r.slot,
            model: stack.slots.find((s) => s.name === r.slot)!.model,
            prompt: debatePrompt(
              topic,
              r.slot,
              r.text,
              spoke.filter((o) => o.slot !== r.slot).map((o) => ({ slot: o.slot, text: clip(o.text, 4000) })),
            ),
          })),
          runOpts,
        );
        finalists = debate.results.filter((r) => r.ok && r.text);
        for (const r of debate.results) {
          const moved = (r.text.match(/^(HOLD|CHANGE):/i) ?? [])[1];
          say(r.ok ? `· ${r.slot} revised${moved ? ` (${moved.toUpperCase()})` : ""} (${r.ms}ms)` : `· ${r.slot} revision FAILED: ${r.error}`);
        }
        if (!finalists.length) finalists = spoke;
      }

      const arbiterSlot = stack.slots.find((s) => s.name === stack.arbiter)!;
      const verdict = await runRound(
        [
          {
            slot: stack.arbiter,
            model: arbiterSlot.model,
            prompt: verdictPrompt(topic, stack.arbiter, finalists.map((r) => ({ slot: r.slot, text: clip(r.text, 6000) }))),
          },
        ],
        runOpts,
      );
      const v = verdict.results[0];
      say(`· verdict by ${stack.arbiter} (${v?.ms ?? 0}ms)`);

      if (!v?.ok || !v.text) {
        return out(`${lines.join("\n")}\nthe arbiter failed: ${v?.error ?? "no answer"}`, true);
      }

      const budget = opinion.stoppedForBudget || verdict.stoppedForBudget;
      return out(
        [
          ...lines,
          "",
          `= VERDICT (${stack.name}) =`,
          v.text,
          "",
          `seats: ${finalists.map((r) => r.slot).join(", ")} · seconds: ${opinion.seconds + verdict.seconds}`,
          budget ? "BUDGET: the character budget was reached — the council stopped rather than spend more" : "",
          "record it: ymir_note / ymir_plan (the council writes nothing itself)",
        ]
          .filter(Boolean)
          .join("\n"),
      );
    },
  });
}
