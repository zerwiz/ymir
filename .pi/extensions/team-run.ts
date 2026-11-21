/**
 * team-run — run the smithy for a bigger task from the agent tool, on a chosen machine. ONE tool, one door.
 *
 * The smithy is its own installed program; `bin/forge/team-run.sh` is the door that runs it where the
 * Allfather says (a named machine, or the least loaded) and answers with a run id, the machine, the
 * runtime, the state and a link. This extension only calls that door, so a person at a shell, the MCP
 * tool and this tool all get the same answer.
 *
 *   run    → team-run.sh run --task … [--on HOST|auto] [--runtime herdr|internal] [--team T] [--project P]
 *   status → team-run.sh status <id>
 *   tail   → team-run.sh tail <id>
 *   stop   → team-run.sh stop <id>
 *   where  → team-run.sh where
 *
 * `runtime` is the choice of where the smithy's agents work: `herdr` seats each one in a visible herdr pane
 * on that machine, `internal` runs them headless inside the engine. Left blank, the machine's own configured
 * default applies.
 */

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Install records the root; the extension reads it. Never a machine path in source (Rule 07).
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
  throw new Error(
    "YMIR_ROOT is not set and ~/.pi/agent/extensions/.ymir-root holds no usable root. " +
    "Run `bin/seat/valknut-load.sh --all --global` from your Ymir checkout.",
  );
}

const piOut = (text: unknown): { content: { type: "text"; text: string }[]; details: undefined } => ({
  content: [{ type: "text", text: String(text) }],
  details: undefined,
});

export default function teamRun(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ymir_team_run",
    label: "Run the smithy",
    description:
      "Run the smithy for a bigger task on a chosen machine and follow it. action=run starts a run from `task` " +
      "and answers with the run id, machine, runtime, state and link. `on` is a machine name or `auto` (the " +
      "least loaded). `runtime` is `herdr` (each agent seated in a visible pane the Allfather can watch and " +
      "steer) or `internal` (headless inside the engine); blank takes the machine's configured default. " +
      "action=status | tail | stop take the run `id`; action=where lists the machines. The answer is six plain " +
      "lines unless phone=false.",
    parameters: {
      type: "object",
      properties: {
        action: { type: "string", enum: ["run", "status", "tail", "stop", "where"], description: "what to do; default run" },
        task: { type: "string", description: "the task, in plain words; only for run" },
        id: { type: "string", description: "the run id; for status, tail and stop" },
        on: { type: "string", description: "a machine name, or auto for the least loaded; default auto" },
        runtime: { type: "string", enum: ["herdr", "internal"], description: "where the smithy's agents work" },
        team: { type: "string", description: "the smithy team that runs it" },
        project: { type: "string", description: "the project path on that machine" },
        chain: { type: "string", description: "a named chain; blank takes the machine's default" },
        phone: { type: "boolean", description: "answer in six short lines; default true" },
      },
      required: [],
    },
    execute: async (_toolCallId: string, args: any) => {
      const action = String(args?.action ?? "run");
      const argv = [action];
      if (action === "run") {
        argv.push("--task", String(args?.task ?? ""));
        argv.push("--on", String(args?.on || "auto"));
        for (const [flag, key] of [["--runtime", "runtime"], ["--team", "team"], ["--project", "project"], ["--chain", "chain"]] as const) {
          if (args?.[key]) argv.push(flag, String(args[key]));
        }
      } else if (action === "status" || action === "tail" || action === "stop") {
        if (!args?.id) return piOut(`${action} needs the run id`);
        argv.push(String(args.id));
        if (args?.on && args.on !== "auto") argv.push("--on", String(args.on));
      }
      if (action !== "where" && args?.phone !== false) argv.push("--phone");
      try {
        const r = spawnSync("bash", [join(resolveRoot(), "bin", "forge", "team-run.sh"), ...argv], {
          encoding: "utf8",
          timeout: 300_000,
        });
        const out = `${r.stdout ?? ""}`.trim();
        return piOut(out || `${r.stderr ?? ""}`.trim() || "the smithy door answered nothing");
      } catch (e: any) {
        const msg = String(e?.message || e).trim().split("\n")[0];
        return piOut(`the smithy door is not answering: ${msg}\n  check: bash bin/forge/team-run.sh where`);
      }
    },
  });
}
