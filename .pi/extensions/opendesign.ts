/**
 * opendesign — the design studio's door. ONE tool, one container, no confusion.
 *
 * Why this file exists (audit §4, 2026-10-03): the studio has a real door
 * (`bin/opendesign.sh start|stop|status`, added when OpenDesign was stopped) and NO tool, so
 * "turn the studio off" cost a shell round-trip through a skill while it sat right there.
 *
 * **OpenDesign is NOT Maestro.** OpenDesign is the design studio on :7456 (a container named
 * `open-design`). Maestro is the film forge on :7860, a different machine's craft, and this
 * file must never touch it. The door below calls exactly one script and reports its exit
 * code; it never guesses a port and never starts "whatever is on 74xx".
 */

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

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


// Pi 1.0 tool contract. The model-facing text is `content`; THROWING is how a tool reports
// failure. Named `piOut`, not `out`, because several handlers declare a LOCAL `const out` —
// and a module helper with a one-word name gets shadowed by them (0.1.100: "out is not a
// function" in seven tools, all the same cause).
const piOut = (text: unknown): { content: { type: "text"; text: string }[]; details: undefined } => ({
  content: [{ type: "text", text: String(text) }],
  details: undefined,
});

export default function opendesign(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ymir_studio",
    label: "Design studio",
    description:
      "The OpenDesign studio — the container on :7456, nothing else. `status` (default) " +
      "reports whether it runs; `start` and `stop` raise and lower it. This NEVER touches " +
      "Maestro, the film forge on :7860, which is a different craft entirely. Thin: it " +
      "calls bin/opendesign.sh, so a human does the same thing.",
    parameters: {
      type: "object",
      properties: {
        action: { type: "string", enum: ["status", "start", "stop"], description: "default: status" },
      },
      required: [],
    },
    execute: async (_toolCallId: string, args: any) => {
      const action = String(args?.action ?? "status");
      try {
        const out = execFileSync("bash", [join(resolveRoot(), "bin", "opendesign.sh"), action], {
          encoding: "utf8",
          timeout: 120_000,
          stdio: ["ignore", "pipe", "pipe"],
        }).trim();
        return piOut(`opendesign[2]{action,verdict}:\n  "${action}","${out ? "done" : "no answer"}"\n\n${out}`);
      } catch (e: any) {
        const detail = String(e?.stderr || e?.message || e).trim().split("\n").slice(0, 4).join("\n");
        return piOut(`opendesign[2]{action,verdict}:\n  "${action}","failed (exit ${e?.status ?? 1})"\n\n${detail}\n` +
            `  note: the studio is a CONTAINER. If docker is not running, that is the answer — this door does not start docker for you.`);
      }
    },
  });
}
