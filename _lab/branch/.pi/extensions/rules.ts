/**
 * rules — the house law AS A SURFACE.
 *
 * The Allfather, 2026-10-01: *"we need to build for rules."* An agent that does not know the
 * laws does one of two things: it reads ten files and misses the one that matters, or it invents.
 * `RULES/` is prose today — correct prose, and unread by any tool.
 *
 * This extension registers ONLY what is distinctLY its own (register §12: one tool, one
 * registration — the door keeps `ymir_place/find_home/…`; this file never re-registers any of them).
 *
 *   ymir_rule   <topic>          the laws that govern it, with the line that says so
 *   ymir_gates                   which gate covers which surface — and whether it is wired
 *
 * Everything is READ from `RULES/` and the gate list at call time. Nothing is duplicated here, so
 * the law cannot drift from the law.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";

const ROOT = process.env.YMIR_ROOT || process.cwd();
const RULES = join(ROOT, "RULES");

function read(p: string, n = 40000): string {
  try { return readFileSync(p, "utf8").slice(0, n); } catch { return ""; }
}

/** The sentences of a law that actually MATCH the topic — not its whole file. */
function matchingLines(text: string, topic: string, limit = 8): string[] {
  const t = topic.toLowerCase().trim();
  const terms = t.split(/[^a-z0-9_.-]+/i).filter((w) => w.length > 2);
  const out: Array<{ line: string; score: number }> = [];
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("```") || line.length < 24) continue;
    const low = line.toLowerCase();
    let score = 0;
    for (const term of terms) {
      if (low.includes(term)) score += 2;
      if (low.includes(term.replace(/s$/, ""))) score += 1;   // plural/singular
    }
    if (low.includes(t)) score += 4;                            // the whole phrase
    if (score > 0) out.push({ line: line.replace(/^[#>*\-\s]+/, ""), score });
  }
  return out
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((x) => x.line);
}


// Pi 1.0's tool contract: the model-facing text is `content`, and THROWING is how a tool
// reports failure — returning an object does not mark it as an error. `output:` reached the
// model as an empty success while the harness called a key that did not exist.
const piOut = (text: unknown): { content: { type: "text"; text: string }[]; details: undefined } => ({
  content: [{ type: "text", text: String(text) }],
  details: undefined,
});

export default function rules(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ymir_rule",
    description:
      "The house law that governs a topic, read from RULES/ and quoted by line. Ask before acting " +
      "where a law may apply: what may not be deleted, where data may live, what a port must not " +
      "lose, what may never be committed.",
    parameters: {
      type: "object",
      properties: {
        topic: { type: "string", description: "e.g. delete, secrets, ports, worktrees, commits" },
      },
      required: ["topic"],
    },
    execute: async (_toolCallId: string, args: any) => {
      const topic = String(args.topic);
      const rows: string[] = [];
      if (!existsSync(RULES)) return piOut(`no RULES/ at ${RULES} — this seat has no house law to quote.`);
      for (const f of readdirSync(RULES).filter((x) => x.endsWith(".md")).sort()) {
        const lines = matchingLines(read(join(RULES, f)), topic);
        if (!lines.length) continue;
        rows.push(`${f}`);
        for (const l of lines) rows.push(`    ${l}`);
      }
      if (!rows.length) {
        const all = readdirSync(RULES).filter((x) => x.endsWith(".md")).map((x) => `  ${x}`);
        return piOut(`no law in RULES/ mentions "${topic}".\n\nthe whole law (small enough to read):\n${all.join("\n")}`);
      }
      return piOut(`the law about ${topic}:\n${rows.join("\n")}\n\nquoted from RULES/ — if a law is not there, nothing forbids it; if it is, it binds.`);
    },
  });

  pi.registerTool({
    name: "ymir_gates",
    description:
      "Which gate covers which surface, and whether it is actually WIRED — a gate that exists and " +
      "runs nowhere is how a capability is silently absent.",
    parameters: { type: "object", properties: { surface: { type: "string" } } },
    execute: async (_toolCallId: string) => {
      const rows: string[] = [];
      const ci = read(join(ROOT, "bin", "gates", "ci-verify.sh"));
      const gates = [...ci.matchAll(/^gate\s+(\S+)\s+"([^"]+)"/gm)].map((m) => [m[1], m[2]]);
      if (!gates.length) return piOut("no gates found in bin/gates/ci-verify.sh — the gate list itself is unreadable.");
      rows.push(`ci-verify[${gates.length}]{gate,covers}:`);
      for (const [name, what] of gates) rows.push(`  "${name}","${what}"`);
      rows.push("");
      rows.push(`bin/             the doors this seat can run, each saying what it is:`);
      rows.push(`bin/gates/inventory.sh   what every door does, its verdict and its disposition (--check fails when stale)`);
      rows.push(`bin/gates/capabilities.sh the capability register: job -> door -> tech decision (--check fails when stale)`);
      rows.push(`bin/gates/queue.sh       the work queue, DERIVED from register + questions (--check fails when stale)`);
      rows.push(`bin/seat/verify-seat.sh whether THIS seat is whole; non-zero when a surface is missing`);
      rows.push(`bin/gates/checks/home-index-check.sh whether the home's shelves can be navigated`);
      rows.push("");
      rows.push("a gate that exists and runs nowhere is how a capability is silently absent.");
      return piOut(rows.join("\n"));
    },
  });
}