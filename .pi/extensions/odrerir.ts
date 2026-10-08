/**
 * odrerir — the live hall's one read of the whole house.
 *
 * The Allfather, 2026-10-01: *"functional with odrerir the app."* The hall is the live surface;
 * what it lacked was a single honest read of what the house is actually doing — so the app, or a
 * reader, had to reach into five doors and reconcile them by hand.
 *
 * ONE tool, THIN over the doors that already answer. It registers nothing the door owns
 * (register §12) and it writes nothing:
 *
 *   ymir_hall   the state the hall draws — in ONE read: seat verdict, the capability register's
 *               counts, the derived queue's tally, the door inventory's verdicts, the last runes.
 *
 * Every figure comes from the door that owns it, so the hall cannot show a number that disagrees
 * with the tree. If a door cannot answer, its row says so — a missing answer is never a zero.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";


// ── resolution: this file must run on ANY seat, so it may not know a machine ──
// (Rule 07. 2026-10-03: this extension carried a hardcoded `/home/heimdall/ymir`.)
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


// The vault, resolved by the house's own resolver — never `$HOME/Documents/ymirhome`,
// which is this seat's layout and not a rule (Rule 04; 0.1.53 lost a push to that guess,
// and the ward now scans .pi/ so a guess here fails the build).
function resolveHome(): string {
  const fromEnv = process.env.YMIR_HOME?.trim();
  if (fromEnv) return fromEnv;
  const v = execFileSync("bash", [join(resolveRoot(), "bin", "vault", "hodd.sh"), "path"], {
    encoding: "utf8", stdio: ["ignore", "pipe", "ignore"],
  }).trim();
  if (!v) throw new Error("the vault path is empty — run `bin/vault/hodd.sh path` and read what it says");
  return v;
}

const ROOT = resolveRoot();

function run(args: string[]): string {
  try {
    return execFileSync("bash", args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], timeout: 60000 }).trim();
  } catch { return ""; }
}


// Pi 1.0's tool contract: the model-facing text is `content`, and THROWING is how a tool
// reports failure — returning an object does not mark it as an error. `output:` reached the
// model as an empty success while the harness called a key that did not exist.
const piOut = (text: unknown): { content: { type: "text"; text: string }[]; details: undefined } => ({
  content: [{ type: "text", text: String(text) }],
  details: undefined,
});

export default function odrerir(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ymir_hall",
    description:
      "The whole house in ONE read, for the live hall: is this seat whole, how many doors exist and " +
      "how many are proved, what is queued and by whose hand it waits, and the last runes carved. " +
      "Thin over the doors that own those answers, and it WRITES nothing. A door that cannot " +
      "answer is reported as unable, never as zero.",
    parameters: { type: "object", properties: { runes: { type: "number", description: "how many runes (default 5)" } } },
    execute: async (_toolCallId: string, args: any) => {
      const out: string[] = [];
      const missing = (what: string, why: string) => out.push(`  ${what.padEnd(14)} UNABLE — ${why}`);

      out.push("hall[1]{read_at}:");
      out.push(`  "${new Date().toISOString()}"`);
      out.push("");

      // 1 · is the seat whole? (bin/seat/verify-seat.sh — the door that can say NO)
      const seat = run([`${ROOT}/bin/seat/verify-seat.sh`, "--no-exit"]);
      if (!seat) missing("seat", "bin/seat/verify-seat.sh did not answer");
      else {
        const verdict = /"WHOLE"/.test(seat) ? "WHOLE" : (/,(\d+)"\s*$/.exec(seat)?.[1] ? `NOT WHOLE (${/,(\d+)"\s*$/.exec(seat)?.[1]} missing)` : "NOT WHOLE");
        out.push(`  ${"seat".padEnd(14)} ${verdict}`);
        for (const l of seat.split("\n").slice(1, 8)) if (/^\s{2}\S/.test(l)) out.push(`      ${l.trim()}`);
      }

      // 2 · the capability register's own counts (the register, not a recount)
      const reg = `${ROOT}/.agents/assets/agents/capabilities.md`;
      if (!existsSync(reg)) missing("capabilities", "no register generated yet — bin/gates/capabilities.sh");
      else {
        const t = readFileSync(reg, "utf8");
        const g = (k: string) => new RegExp(`"${k}",(\\d+)`).exec(t)?.[1] ?? "?";
        out.push(`  ${"doors".padEnd(14)} shell ${g("shell doors \\(bin/\\*\\.sh\\)")} · engine ${g("runtime modules \\(src/ymir_runtime/\\*\\.py\\)")} · skills ${g("skills \\(\\.agents/skills/\\*\\)")} · tools ${g("Pi extension tools")}`);
      }

      // 3 · the derived queue's tally
      const q = run([`${ROOT}/bin/gates/queue.sh`, "--check"]);
      const tally = /blocked=(\d+) owed=(\d+) open=(\d+) done=(\d+)/.exec(q);
      out.push(`  ${"queue".padEnd(14)} ${tally ? `blocked=${tally[1]} owed=${tally[2]} open=${tally[3]} done=${tally[4]}` : "UNABLE — bin/gates/queue.sh did not answer"}`);

      // 4 · the doors, by verdict (the inventory, not a guess)
      const inv = `${ROOT}/bin/README.md`;
      if (!existsSync(inv)) missing("inventory", "bin/README.md not generated — bin/gates/inventory.sh");
      else {
        const t = readFileSync(inv, "utf8");
        const verdict = /verdict: (.+)/.exec(t)?.[1] ?? "?";
        const disp = /disposition: (.+)/.exec(t)?.[1] ?? "?";
        out.push(`  ${"inventory".padEnd(14)} ${verdict}`);
        out.push(`  ${"".padEnd(14)} ${disp}`);
      }

      // 5 · the last runes, carved
      const runes = `${resolveHome()}/hodd/memory/runes_audit.md`;
      if (!existsSync(runes)) missing("runes", "no ledger at " + runes);
      else {
        const lines = readFileSync(runes, "utf8").trim().split("\n");
        out.push(`  ${"runes".padEnd(14)} ${lines.length} lines carved; last:`);
        for (const l of lines.slice(-Number(args.runes ?? 5))) out.push(`      ${l.slice(0, 110)}`);
      }

      out.push("");
      out.push("every figure came from the door that owns it — the hall cannot show a number the tree does not hold.");
      out.push("a door that could not answer is shown UNABLE, never as zero: an absent answer is not an empty one.");
      return piOut(out.join("\n"));
    },
  });
}