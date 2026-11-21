/**
 * eindri — ONE tool for an errand: start · read · steer · close.
 *
 * Plan 66 §4.4, and the reason it exists: an errand could be started five ways
 * (`eindri-start.sh`, `einherjar-spawn.sh`, `agent-run.sh`, the review spawner, Pi's own
 * `subagent`) and closed four, plus a `brokk-control.sh` that **does not exist**. Only one of
 * them records a seat. That is "we're doing that in so many ways" made measurable.
 *
 * THIN by construction — every action calls the door that already does the work:
 *   start  → bin/agents/einherjar-spawn.sh <id> <project> --mode direct-PR   (the ONE spawn path)
 *   read   → state/<id>.status + state/<id>.meta + the worktree's branch and commits
 *   steer  → bin/fleet/fleet-tell.sh --steer --to <id> "<message>"            (the ONE road to any agent; the id may be machine:errand)
 *   close  → bin/agents/eindri-acclaim.sh <id> --terminal … then bin/agents/eindri-control.sh exit <id>
 *
 * It registers nothing the door already owns (register §12): no place, no push, no note.
 */

import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";


// ── resolution: this file must run on ANY seat, so it may not know a machine ──
// (Rule 07. 2026-10-03: this extension carried a hardcoded operator home path,
//  `$HOME/ymir`. Naming the real path to teach the rule would re-create the leak,
//  so it is written in the public placeholder form on purpose.)
// This is the JS mirror of `ymir_root_verified` in bin/seat/valknut-load.sh — same contract,
// same order: $YMIR_ROOT, then the recorded roots, first one that really holds the house.
// One reader in the shell, one here; they must agree, or a worktree seat reads a dead path.
function resolveRoot(): string {
  const fromEnv = process.env.YMIR_ROOT?.trim();
  if (fromEnv) return fromEnv;
  const pointer = join(homedir(), ".pi", "agent", "extensions", ".ymir-root");
  if (existsSync(pointer)) {
    for (const line of readFileSync(pointer, "utf8").split("\n")) {
      const root = line.trim();
      if (!root) continue;
      if (existsSync(join(root, "bin"))) return root;
    }
  }
  throw new Error(
    "YMIR_ROOT is not set and ~/.pi/agent/extensions/.ymir-root holds no usable root. " +
    "Run `bin/seat/valknut-load.sh --all --global` from your Ymir checkout — install records " +
    "the root, and every extension reads it from there.",
  );
}

const ROOT = resolveRoot();

// ── WHERE THE ERRAND'S RECORD LIVES (2026-11-20) ─────────────────────────────────────────────
// An errand's status and meta are the HOME's (`<home>/state/<id>.meta`), never the checkout's:
// the home is where the helm writes, and a seat that read `<root>/state` answered "NOTHING
// RECORDED — no state/<id>.meta" for an errand whose meta and status both stood in the home
// (measured 2026-11-20 on `ymir_errand read`). This mirrors the shell doors —
// `eindri_helm_state` in bin/agents/eindri-wake-lib.sh: BROKK_HELM_STATE, then
// BROKK_STATE_OVERRIDE, then the home — and keeps the old in-tree `state/` as a last resort, so an
// older seat is still read rather than refused.
export function resolveHome(): string {
  const fromEnv = process.env.YMIR_HOME?.trim();
  if (fromEnv) return fromEnv;
  const hodd = run("bash", [join(ROOT, "bin", "vault", "hodd.sh"), "path"]);
  const hoard = hodd.rc === 0 ? hodd.out.trim() : "";
  if (hoard) return hoard.replace(/\/hodd$/, "");
  return "";
}

const HOME = resolveHome();

/** The state dirs an errand's record is looked for in, in the order the shell doors use. */
export function errandStateDirs(): string[] {
  const override = process.env.BROKK_STATE_OVERRIDE?.trim();
  const helm = process.env.BROKK_HELM_STATE?.trim();
  const dirs = [
    helm || "",
    override && override !== process.env.BROKK_MACHINE_STATE_DIR ? override : "",
    HOME ? join(HOME, "state") : "",
    join(ROOT, "state"),
  ];
  return dirs.filter((d, i) => d && dirs.indexOf(d) === i);
}

/** Where the errand's record is, or the first candidate when it has none (so the message names a path). */
function errandBase(id: string): { base: string; found: boolean } {
  const dirs = errandStateDirs();
  for (const d of dirs) {
    const base = join(d, id);
    if (existsSync(`${base}.meta`) || existsSync(`${base}.status`)) return { base, found: true };
  }
  return { base: join(dirs[0] ?? join(ROOT, "state"), id), found: false };
}

/** A tool result is read, not scrolled: keep the head, and say how much was cut. */
function brief(text: string, limit = 3000): string {
  const out = (text ?? "").trim();
  if (out.length <= limit) return out;
  return `${out.slice(0, limit)}\n… ${out.length - limit} more chars (full output: state/ or the script's own log)`;
}

type RunResult = { rc: number; out: string };

function run(cmd: string, args: string[]): RunResult {
  try {
    // CAPTURE, ALWAYS. A child that inherits our stdio writes straight at the terminal pi
    // owns: its tables land on top of the editor, the status line and the spinner, and pi
    // never sees those bytes, so nothing in its renderer can repair the damage. That is the
    // "random texts over the UI" fault of 2026-10-23 (#412). The `quiet=false` branch that
    // remained here was dead — no caller ever passed it — and dead is exactly where a
    // painting path hides, so the parameter is gone rather than defaulted. A tool RETURNS
    // text; pi renders it. The only inherited stdio left in the harness is the terminal
    // editor in `open-editor.ts`, which stops the TUI first.
    const out = execFileSync(cmd, args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
    return { rc: 0, out: (out ?? "").trim() };
  } catch (e: any) {
    if (e instanceof TypeError || e?.status === undefined) {
      // Not an exit status: the process was killed by a signal or never ran.
      return { rc: 1, out: String(e?.message ?? "unknown failure").split("\n")[0] };
    }
    return { rc: e.status, out: String(e?.stdout ?? "").trim() || String(e?.message ?? "").split("\n")[0] };
  }
}

function field(file: string, key: string): string {
  if (!existsSync(file)) return "";
  return (new RegExp(`^${key}=(.*)$`, "m").exec(readFileSync(file, "utf8"))?.[1] ?? "");
}

// EXPORTED for the test (bin/agents/tests/test_errand_doors_find_the_seat.sh): the reader is a
// pure function of the state dirs, and a reader that cannot be called cannot be proved.
export function readErrand(id: string): string {
  const { base, found } = errandBase(id);
  const statusFile = `${base}.status`;
  const status = existsSync(statusFile) ? readFileSync(statusFile, "utf8").trim().split("\n").pop() ?? "" : "";
  const meta = `${base}.meta`;
  const out: string[] = [];
  out.push(`errand[1]{id,status,backend,harness,model,worktree}:`);
  if (!found) {
    out.push(`  "${id}","NOTHING RECORDED — no ${base}.meta and no .status"`);
    out.push("");
    out.push(`Looked in: ${errandStateDirs().join(", ") || "(no state dir resolved)"}.`);
    out.push("That is the fault this door exists for: an errand that left no record cannot be read, steered or closed by name.");
    return out.join("\n");
  }
  out.push(`  "${id}","${status.slice(0, 70)}","${field(meta, "backend")}","${field(meta, "harness")}","${field(meta, "model")}","${field(meta, "worktree")}"`);
  const seat = field(meta, "seat_pane") || field(meta, "window");
  if (seat) out.push(`  seat: ${seat}${field(meta, "seat_pane") ? "" : " (recorded `window`)"}`);
  const wt = field(meta, "worktree");
  if (wt && existsSync(wt)) {
    const g = (a: string[]) => run("git", a).out;
    out.push("");
    out.push(`  branch: ${g(["rev-parse", "--abbrev-ref", "HEAD"])}`);
    out.push(`  commits ahead of main: ${g(["rev-list", "--count", "origin/main..HEAD"])}`);
    out.push(`  changed files: ${g(["status", "--porcelain"]).split("\n").filter(Boolean).length}`);
  }
  const inbox = `${base}.inbox`;
  if (existsSync(inbox)) {
    const un = run("bash", ["-c", `ls "$1" 2>/dev/null | wc -l`, "_", inbox]).out;
    out.push(`  steering inbox: ${un} message(s)`);
  }
  return out.join("\n");
}


// Pi 1.0 tool contract. The model-facing text is `content`; THROWING is how a tool reports
// failure. Named `piOut`, not `out`, because several handlers declare a LOCAL `const out` —
// and a module helper with a one-word name gets shadowed by them (0.1.100: "out is not a
// function" in seven tools, all the same cause).
const piOut = (text: unknown): { content: { type: "text"; text: string }[]; details: undefined } => ({
  content: [{ type: "text", text: String(text) }],
  details: undefined,
});

export default function eindri(pi: any) {
  pi.registerTool({
    name: "ymir_errand",
    description:
      "ONE tool for an errand. start = the one spawn path (einherjar-spawn.sh); read = its status, " +
      "seat and worktree; steer = one line into its inbox; close = claim the outcome and stop the " +
      "seat. Use this INSTEAD of eindri-start.sh / einherjar-spawn.sh / agent-run.sh / the review " +
      "spreader — five ways to start one thing is why errands are hard to find.",
    parameters: {
      type: "object",
      properties: {
        action: { type: "string", description: "start | read | steer | close" },
        id: { type: "string", description: "the errand id (kebab-case, stable)" },
        project: { type: "string", description: "start only: the repo root" },
        harness: { type: "string", description: "start only: pi | opencode" },
        model: { type: "string", description: "start only" },
        mode: { type: "string", description: "start only: direct-PR | local-only | no-mistakes" },
        message: { type: "string", description: "steer only: one line" },
        terminal: { type: "string", description: "close only: done | failed | needs-decision" },
        note: { type: "string", description: "close only: the one line the record should carry" },
      },
      required: ["action", "id"],
    },
    execute: async (_toolCallId: string, args: any) => {
      const id = String(args.id);
      const a = String(args.action);
      switch (a) {
        case "read":
          return piOut(readErrand(id));

        case "start": {
          if (!args.project) return piOut("start needs `project` (the repo root).");
          const r = run("bash", [`${ROOT}/bin/agents/einherjar-spawn.sh`, id, String(args.project),
            "--mode", String(args.mode || "direct-PR"),
            ...(args.harness ? ["--harness", String(args.harness)] : []),
            ...(args.model ? ["--model", String(args.model)] : [])]);
          return piOut(`${id}: spawn rc=${r.rc}\n${brief(r.out) || "(see state/" + id + ".status)"}\n` +
              `one spawn path only - einherjar-spawn.sh. Start here again and you will get a refusal, which is correct.`);
        }

        case "steer": {
          if (!args.message) return piOut("steer needs `message` (one line).");
          const r = run("bash", [`${ROOT}/bin/fleet/fleet-tell.sh`, "--steer", "--to", id, "--", String(args.message)]);
          return piOut(`steered ${id}: rc=${r.rc}\n${brief(r.out)}`);
        }

        case "close": {
          const term = String(args.terminal || "done");
          const c = run("bash", [`${ROOT}/bin/agents/eindri-acclaim.sh`, id, "--terminal", term,
            ...(args.note ? ["--line", String(args.note)] : [])]);
          // and stop the seat, so a closed errand leaves nothing running
          const x = run("bash", [`${ROOT}/bin/agents/eindri-control.sh`, "exit", id]);
          return piOut(`closed ${id} as ${term}\n  claim rc=${c.rc} ${c.out.split("\n").slice(0, 2).join(" · ")}\n` +
              `  seat  rc=${x.rc} ${x.out.split("\n").slice(0, 1).join("")}\n` +
              `  a closed errand leaves no running seat and one durable record.`);
        }

        default:
          return piOut(`unknown action "${a}" — use start, read, steer or close.`);
      }
    },
  });
}