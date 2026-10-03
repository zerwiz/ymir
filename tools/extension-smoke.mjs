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
const targets = process.argv.slice(2);
const names = targets.length ? targets : [
  "elder", "ymirhome", "managandr", "eir", "opendesign", "odrerir",
  "rules", "herdr", "eindri", "skuld-branch-supervision", "gna-pi-watch",
];

let bad = 0;
let called = 0;
const skipped = [];

for (const name of names) {
  let mod;
  try {
    mod = await import(`/home/heimdall/ymir/.pi/shared/extensions/${name}.ts`);
  } catch (e) {
    const msg = String(e.message);
    // Pi resolves its OWN packages (@earendil-works/pi-ai, pi-tui) from the global install;
    // bare node, run from the repo, cannot. That is a limitation of THIS harness, not a defect
    // in the extension — so it is SKIPPED and said so, rather than reported as broken, because a
    // gate that cries wolf gets ignored and then misses the next real one.
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
      console.log(`  ${t.name.padEnd(28)} threw: ${String(e.message).slice(0, 58)}`);
    }
  }
}

if (skipped.length) {
  console.log("\n  skipped (Pi provides the package, bare node cannot):");
  for (const s2 of skipped) console.log(`    · ${s2}`);
}
console.log(`\nextension_smoke[3]{called,broken,skipped}:`);
console.log(`  "${called}","${bad}","${skipped.length}"`);
process.exit(bad ? 1 : 0);
