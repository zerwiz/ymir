/**
 * gna-fleet-tell — Gná, the messenger: ONE tool for talking to, and steering, any agent on any machine.
 *
 * THIN by construction: it calls the door, so an agent, a human and a cron row get the same answer.
 *   → bin/fleet/fleet-tell.sh [--steer|--answer|--stop] --to <target>… "<line>"
 *
 * The door reuses each machine's own bin/agents/tell.sh, over ssh, and falls back to typing into the
 * agent's herdr pane when the wire refuses. It returns one TOON row per target, and every line it sends
 * is signed with the sender's seat and machine.
 */

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

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

// Pi 1.0 tool contract: the model-facing text is `content`; a module helper with a one-word name gets shadowed.
const piOut = (text: unknown): { content: { type: "text"; text: string }[]; details: undefined } => ({
  content: [{ type: "text", text: String(text) }],
  details: undefined,
});

export default function gnaFleetTell(pi: any) {
  pi.registerTool({
    name: "gna_fleet_tell",
    label: "Fleet tell",
    description:
      "The ONE road for talking to and steering any agent on any machine of the fleet. `to` names the targets: " +
      "a machine (its arm holder), an errand id, `machine:errand`, a pane id, or `machine:pane`; `all` reaches every " +
      "arm holder. `verb`: tell (default) · steer (a steering line to a worker) · answer (answer a worker's open " +
      "question; `record_only` records without speaking) · stop (ask a worker to stop at a safe point). It uses each " +
      "machine's own tell.sh over ssh, falls back to typing into the agent's herdr pane, signs the line with your " +
      "seat and machine, and returns one row per target. Use this for ANY message to another agent.",
    parameters: {
      type: "object",
      properties: {
        to: { type: "array", items: { type: "string" }, description: "targets: machine · errand · machine:errand · pane · machine:pane" },
        all: { type: "boolean", description: "every arm holder in the fleet registry" },
        line: { type: "string", description: "the one line to send (for stop: the optional reason)" },
        verb: { type: "string", description: "tell | steer | answer | stop (default tell)" },
        record_only: { type: "boolean", description: "answer only: record the answer, do not speak it" },
        pane_only: { type: "boolean", description: "skip the wire, type into the pane" },
        arm_only: { type: "boolean", description: "use the wire only, never type into a pane" },
        dry_run: { type: "boolean", description: "resolve and report, send nothing" },
        from: { type: "string", description: "the sender's seat name (default: this seat)" },
      },
      required: [],
    },
    execute: async (_toolCallId: string, args: any) => {
      const argv = [join(resolveRoot(), "bin", "fleet", "fleet-tell.sh")];
      const verb = String(args?.verb ?? "tell");
      if (["steer", "answer", "stop"].includes(verb)) argv.push(`--${verb}`);
      for (const t of Array.isArray(args?.to) ? args.to : []) argv.push("--to", String(t));
      if (args?.all) argv.push("--all");
      if (args?.record_only) argv.push("--record-only");
      if (args?.pane_only) argv.push("--pane-only");
      if (args?.arm_only) argv.push("--arm-only");
      if (args?.dry_run) argv.push("--dry-run");
      if (args?.from) argv.push("--from", String(args.from));
      argv.push("--", String(args?.line ?? ""));
      const r = spawnSync("bash", argv, { encoding: "utf8", timeout: 300000 });
      const text = `${r.stdout || ""}${r.stderr ? "\n" + r.stderr : ""}`.trim();
      return piOut(text || `fleet-tell printed nothing (exit ${r.status})`);
    },
  });
}
