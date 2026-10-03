/**
 * eindri — ONE tool for an errand: start · read · steer · close.
 *
 * Plan 66 §4.4, and the reason it exists: an errand could be started five ways
 * (`eindri-start.sh`, `einherjar-spawn.sh`, `agent-run.sh`, the review spawner, Pi's own
 * `subagent`) and closed four, plus a `brokk-control.sh` that **does not exist**. Only one of
 * them records a seat. That is "we're doing that in so many ways" made measurable.
 *
 * THIN by construction — every action calls the door that already does the work:
 *   start  → bin/einherjar-spawn.sh <id> <project> --mode direct-PR   (the ONE spawn path)
 *   read   → state/<id>.status + state/<id>.meta + the worktree's branch and commits
 *   steer  → bin/eindri-send.sh <id> "<message>"                     (the steering inbox)
 *   close  → bin/eindri-acclaim.sh <id> --terminal … then bin/eindri-control.sh exit <id>
 *
 * It registers nothing the door already owns (register §12): no place, no push, no note.
 */

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";

const ROOT = process.env.YMIR_ROOT || "/home/heimdall/ymir";

type RunResult = { rc: number; out: string };

function run(cmd: string, args: string[], quiet = true): RunResult {
  try {
    const out = execFileSync(cmd, args, { encoding: "utf8", stdio: quiet ? ["ignore", "pipe", "ignore"] : "inherit" });
    return { rc: 0, out: out.trim() };
  } catch (e: any) {
    return { rc: e?.status ?? 1, out: String(e?.stdout ?? "").trim() || String(e?.message ?? "").split("\n")[0] };
  }
}

function field(file: string, key: string): string {
  if (!existsSync(file)) return "";
  return (new RegExp(`^${key}=(.*)$`, "m").exec(readFileSync(file, "utf8"))?.[1] ?? "");
}

function readErrand(id: string): string {
  const base = `${ROOT}/state/${id}`;
  const statusFile = `${base}.status`;
  const status = existsSync(statusFile) ? readFileSync(statusFile, "utf8").trim().split("\n").pop() ?? "" : "";
  const meta = `${base}.meta`;
  const out: string[] = [];
  out.push(`errand[1]{id,status,backend,harness,model,worktree}:`);
  if (!existsSync(meta) && !existsSync(`${base}.status`)) {
    out.push(`  "${id}","NOTHING RECORDED — no state/${id}.meta and no .status`);
    out.push("");
    out.push("That is the fault this door exists for: an errand that left no record cannot be read, steered or closed by name.");
    return out.join("\n");
  }
  out.push(`  "${id}","${status.slice(0, 70)}","${field(meta, "backend")}","${field(meta, "harness")}","${field(meta, "model")}","${field(meta, "worktree")}"`);
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
    handler: async (args: any) => {
      const id = String(args.id);
      const a = String(args.action);
      switch (a) {
        case "read":
          return { output: readErrand(id) };

        case "start": {
          if (!args.project) return { output: "start needs `project` (the repo root)." };
          const r = run("bash", [`${ROOT}/bin/einherjar-spawn.sh`, id, String(args.project),
            "--mode", String(args.mode || "direct-PR"),
            ...(args.harness ? ["--harness", String(args.harness)] : []),
            ...(args.model ? ["--model", String(args.model)] : [])], false);
          return {
            output:
              `${id}: spawn rc=${r.rc}\n${r.out || "(see state/" + id + ".status)"}\n` +
              `one spawn path only - einherjar-spawn.sh. Start here again and you will get a refusal, which is correct.`,
          };
        }

        case "steer": {
          if (!args.message) return { output: "steer needs `message` (one line)." };
          const r = run("bash", [`${ROOT}/bin/eindri-send.sh`, id, String(args.message)], false);
          return { output: `steered ${id}: rc=${r.rc}\n${r.out || ""}` };
        }

        case "close": {
          const term = String(args.terminal || "done");
          const c = run("bash", [`${ROOT}/bin/eindri-acclaim.sh`, id, "--terminal", term,
            ...(args.note ? ["--line", String(args.note)] : [])], false);
          // and stop the seat, so a closed errand leaves nothing running
          const x = run("bash", [`${ROOT}/bin/eindri-control.sh`, "exit", id], false);
          return {
            output:
              `closed ${id} as ${term}\n  claim rc=${c.rc} ${c.out.split("\n").slice(0, 2).join(" · ")}\n` +
              `  seat  rc=${x.rc} ${x.out.split("\n").slice(0, 1).join("")}\n` +
              `  a closed errand leaves no running seat and one durable record.`,
          };
        }

        default:
          return { output: `unknown action "${a}" — use start, read, steer or close.` };
      }
    },
  });
}