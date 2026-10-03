/**
 * eir — the healer. TWO tools, TWO doors, and nothing else.
 *
 * Why this file exists (audit §4, 2026-10-03): two doors an agent wants at conversational
 * speed had NO tool at all.
 *
 *   ymir_heal   → bin/eir-doctor.sh  check|fix   "is the house healthy" / "heal it"
 *   ymir_update → bin/groa-update.sh check|update  "is there anything new" / "renew Brokk"
 *
 * They are two tools and not one because they are two decisions: *diagnose-and-mend* is a
 * healer, *fast-forward-and-renew* is the updater. A single `ymir_maintain` with a mode
 * argument would have been one name for two acts, and the law is one capability, one name.
 *
 * Both doors FAIL LOUDLY by design — install and update refuse to warn-and-continue — so
 * `ymir_update` reports a non-zero exit as a fact rather than pretending the seat is renewed.
 *
 * NOT tools, deliberately: bin/no-delete-guard.sh and bin/workflow-check.sh are wards and
 * gates. A hook is not a capability an agent calls.
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
      if (root && existsSync(join(root, "bin", "syn-watch-arm.sh"))) return root;
    }
  }
  throw new Error(
    "YMIR_ROOT is not set and ~/.pi/agent/extensions/.ymir-root holds no usable root. " +
    "Run `bin/valknut-load.sh --all --global` from your Ymir checkout.",
  );
}

function run(door: string, args: string[], timeoutMs: number): { rc: number; out: string } {
  try {
    const out = execFileSync("bash", [join(resolveRoot(), "bin", door), ...args], {
      encoding: "utf8",
      timeout: timeoutMs,
      stdio: ["ignore", "pipe", "pipe"],
    });
    return { rc: 0, out: out.trim() };
  } catch (e: any) {
    const out = String(e?.stdout ?? "").trim() || String(e?.message ?? e).split("\n")[0];
    return { rc: typeof e?.status === "number" ? e.status : 1, out };
  }
}


// Pi 1.0 tool contract. The model-facing text is `content`; THROWING is how a tool reports
// failure. Named `piOut`, not `out`, because several handlers declare a LOCAL `const out` —
// and a module helper with a one-word name gets shadowed by them (0.1.100: "out is not a
// function" in seven tools, all the same cause).
const piOut = (text: unknown): { content: { type: "text"; text: string }[]; details: undefined } => ({
  content: [{ type: "text", text: String(text) }],
  details: undefined,
});

export default function eir(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ymir_heal",
    label: "Heal the house",
    description:
      "Eir the healer: diagnose every surface of the house (`check`) or mend what is broken " +
      "(`fix`). Composes every *-ensure.sh and reports per surface. Thin: it calls " +
      "bin/eir-doctor.sh, so a human gets the same diagnosis.",
    parameters: {
      type: "object",
      properties: {
        mode: { type: "string", enum: ["check", "fix"], description: "diagnose (default) or mend" },
      },
      required: [],
    },
    execute: async (_toolCallId: string, args: any) => {
      const mode = String(args?.mode ?? "check");
      const r = run("eir-doctor.sh", [mode], mode === "fix" ? 300_000 : 180_000);
      const verdict = r.rc === 0 ? "whole" : `not whole (exit ${r.rc})`;
      return piOut(`eir_heal[2]{mode,verdict}:\n  "${mode}","${verdict}"\n\n${r.out || "(the healer said nothing — that is itself a finding)"}`);
    },
  });

  pi.registerTool({
    name: "ymir_update",
    label: "Renew Brokk",
    description:
      "Gróa the updater shaman: `check` says whether the checkout has anything new and " +
      "whether the instruction surface moved; `update` fast-forwards Brokk and every " +
      "Eindri-home, never forced, then mends forward. Thin: it calls bin/groa-update.sh. " +
      "Merges stay human — this tool never merges.",
    parameters: {
      type: "object",
      properties: {
        mode: { type: "string", enum: ["check", "update"], description: "report only (default) or renew" },
      },
      required: [],
    },
    execute: async (_toolCallId: string, args: any) => {
      const mode = String(args?.mode ?? "check");
      const r = run("groa-update.sh", [mode === "update" ? "" : "--check"], 600_000);
      const note =
        mode === "update" && r.rc !== 0
          ? `\n  Gróa did not finish cleanly (exit ${r.rc}). The seat may be partly renewed — read the output before running it again.`
          : "";
      return piOut(`${r.out || "(the updater said nothing)"}${note}`);
    },
  });
}
