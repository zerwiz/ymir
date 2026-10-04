// extension-smoke.mjs — call every Ymir tool the way PI CALLS it.
//
// This is the check that was missing on 2026-10-03, and its absence is why the whole hall died:
// the previous smoke test called `tool.handler(args)` — the same wrong key the source used — so
// it agreed with the code and proved the bug instead of the tool.
//
// The harness calls `definition.execute(toolCallId, params, signal, onUpdate, ctx)` and reads
// `{ content, details }` back. So this calls EXACTLY that and fails if the result has no
// `content` — because an empty result reaches the model as a silent success.
//
//   node --experimental-strip-types tools/extension-smoke.mjs [extension ...]
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const targets = process.argv.slice(2);
// ymir-well is deliberately ABSENT from the default set: its `well_observe` wrote 28 episodes
// of the literal string "undefined" into Kaia's well when this test called it with `{}`. A
// memory write from a test is never correct, and the well is the operator's own memory.
const names = targets.length ? targets : [
  "elder", "ymirhome", "managandr", "eir", "opendesign", "odrerir",
  "rules", "herdr", "eindri", "skuld-branch-supervision", "gna-pi-watch",
];

let bad = 0;
let called = 0;
let verified = 0;   // proved callable; not executed, because it might write
const skipped = [];

for (const name of names) {
  let mod;
  try {
    // Resolve the shelf; never name the machine (Rule 07). $YMIR_ROOT, else the pointer
    // bin/valknut-load.sh records in ~/.pi/agent/extensions/.ymir-root.
    // Three doors, in order — and the LAST one can never be wrong: this file lives INSIDE the
    // checkout, so the shelf is a fixed climb from here. CI has no pointer and no env; it only
    // has the checkout. Without this third door the gate failed in CI for exactly the reason it
    // had passed everywhere else: assuming a machine that may not be the one running.
    const checkout = fileURLToPath(new URL("..", import.meta.url));
    const pointer = join(homedir(), ".pi", "agent", "extensions", ".ymir-root");
    const root = process.env.YMIR_ROOT?.trim()
      || (existsSync(pointer)
          ? readFileSync(pointer, "utf8").split("\n").map((l) => l.trim())
              .find((l) => l && existsSync(join(l, "bin", "syn-watch-arm.sh")))
          : "")
      || (existsSync(join(checkout, ".pi", "shared", "extensions")) ? checkout : "");
    if (!root) {
      console.log(`  ${name.padEnd(28)} NO ROOT — set YMIR_ROOT or run bin/valknut-load.sh --all --global`);
      bad++;
      continue;
    }
    // Resolve an extension the way PI resolves it (Rule 13 §3): a direct `.ts`, or a
    // DIRECTORY whose entry point is `index.ts`. Pi's loader does exactly this and does
    // not recurse deeper, so anything else is not an extension. Hard-coding `${name}.ts`
    // is what broke this gate the moment a multi-file extension became a folder.
    const shelf = join(root, ".pi", "shared", "extensions");
    const asFile = join(shelf, `${name}.ts`);
    const asDir = join(shelf, name, "index.ts");
    const entry = existsSync(asFile) ? asFile
                : existsSync(asDir) ? asDir
                : null;
    if (!entry) throw new Error(`no extension named ${name}: neither ${name}.ts nor ${name}/index.ts`);
    mod = await import(entry);
  } catch (e) {
    const msg = String(e.message);
    // Pi resolves its OWN packages (@earendil-works/pi-ai, pi-tui) from the global install;
    // bare node, run from the repo, cannot. That is a limitation of THIS harness, not a defect
    // in the extension — so it is SKIPPED and said so, rather than reported as broken, because a
    // gate that cries wolf gets ignored and then misses the next real one.
    // Same rule at LOAD time: several extensions resolve the root at module top-level, so on a
    // checkout with no vault the refusal happens before any tool exists. That is the extension
    // being CORRECT — it refuses to guess where the house is — and it must not be reported as a
    // break, or the gate teaches people to ignore it.
    if (msg.includes("YMIR_ROOT is not set") || msg.includes("vault path is empty")) {
      skipped.push(`${name} (no root on this machine — refuses to guess at load, which is correct)`);
      continue;
    }
    if (msg.includes("Cannot find package '@earendil-works/")) {
      skipped.push(`${name} (needs Pi's own packages — verified by loading in Pi, not here)`);
      continue;
    }
    console.log(`  ${name.padEnd(28)} LOAD FAILED  ${msg.slice(0, 60)}`);
    bad++;
    continue;
  }
  const tools = [];
  try {
    mod.default({ registerTool: (t) => tools.push(t), on: () => {}, registerCommand: () => {}, registerShortcut: () => {} });
  } catch (e) {
    console.log(`  ${name.padEnd(28)} REGISTER FAILED  ${String(e.message).slice(0, 60)}`);
    bad++;
    continue;
  }
  if (!tools.length) {
    console.log(`  ${name.padEnd(28)} no tools (hook/command extension — fine)`);
    continue;
  }

  for (const t of tools) {
    // THE HARNESS'S OWN CALL. Not the source's key: that is the whole point.
    if (typeof t.execute !== "function") {
      console.log(`  ${t.name.padEnd(28)} NOT CALLABLE — execute is ${typeof t.execute}`);
      bad++;
      continue;
    }
    try {
      // A SMOKE TEST MUST NOT WRITE — and it cannot know every tool that writes.
      // This one called EVERY tool with `{}`, and `ymir_plan` — which writes — created 28 junk
      // files named `NN-undefined.md` in the operator's private vault. A test that can write to
      // someone's records is not a test; it is an accident with a green tick.
      //
      // So the rule is safe by default: every tool is proved CALLABLE, and only the explicit
      // read-only allowlist is actually EXECUTED. Adding a tool to the allowlist is a decision
      // someone has to make deliberately; adding one to the wrong list is now impossible.
      const READ_ONLY = new Set([
        "ymir_hall", "ymir_rule", "ymir_gates", "ymir_seats", "ymir_find_home",
        "ymir_calendar", "ymir_studio", "ymir_heal", "ymir_update", "skuld_plan",
        "brokk_branch_outcomes", "skuld_branch_report",
      ]);
      if (!READ_ONLY.has(t.name)) {
        verified++;
        continue;   // proved callable above; deliberately NOT executed
      }
      const r = await t.execute("smoke-call-id", {}, undefined, () => {}, {});
      called++;
      if (!r || !Array.isArray(r.content)) {
        console.log(`  ${t.name.padEnd(28)} returned ${JSON.stringify(r)?.slice(0, 50)} — no content[]`);
        bad++;
      }
    } catch (e) {
      // Throwing is the DOCUMENTED way to report failure, so a throw is not automatically a
      // broken tool — but a throw on empty arguments for a tool that should describe its own
      // requirements is worth seeing.
      const msg = String(e.message);
    // An extension that REFUSES because there is no resolvable root is not broken — it is
    // correct. A CI checkout has no vault and no recorded root, so half the house honestly
    // declines to guess. Reporting that as a failure would train everyone to ignore the gate.
    if (msg.includes("YMIR_ROOT is not set") || msg.includes("vault path is empty")) {
      skipped.push(`${t.name} (no root on this machine — it refuses to guess, which is correct)`);
      continue;
    }
    console.log(`  ${t.name.padEnd(28)} threw: ${msg.slice(0, 58)}`);
    }
  }
}

if (skipped.length) {
  console.log("\n  skipped (Pi provides the package, bare node cannot):");
  for (const s2 of skipped) console.log(`    · ${s2}`);
}
console.log(`\nextension_smoke[4]{called,verified_not_executed,broken,skipped}:`);
console.log(`  "${called}","${verified}","${bad}","${skipped.length}"`);
process.exit(bad ? 1 : 0);
