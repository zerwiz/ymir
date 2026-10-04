// constellation-load.test.ts — the DEPLOYED extension loads, and registers exactly
// its three tools.
//
// A registry module can pass every unit test and still be an extension pi refuses:
// a factory that throws at load, a lib module the deployed copy cannot find, or a
// duplicate tool name are all load-time failures. So this reproduces the deploy
// `bin/valknut-load.sh` performs — `.pi/shared/extensions/*.ts` plus
// `.pi/extensions/lib/*` copied into ONE extension home, with `.ymir-root`
// recording the tree that owns `bin/` — and drives the deployed factory with a stub
// `pi`, reading back exactly what it registered. That is the question a pi session
// asks at boot, answered here without touching the Allfather's live home.
//
// Run: node --test .pi/extensions/lib/constellation-load.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { cpSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { pathToFileURL } from "node:url";

import shim from "./index.ts";

const ROOT = resolve(import.meta.dirname, "../../..");
const TOOLS = ["constellation_ask", "constellation_card", "constellation_list"]; // sorted, as read back

interface Registered {
  name: string;
  execute: (id: string, params: unknown) => Promise<any>;
}

function stubPi(): { pi: any; registered: Registered[]; events: string[] } {
  const registered: Registered[] = [];
  const events: string[] = [];
  return {
    registered,
    events,
    pi: {
      registerTool(tool: Registered) {
        registered.push(tool);
      },
      on(event: string, _handler: () => void) {
        events.push(event);
      },
    },
  };
}

/** The loader's deploy, into a scratch home: same files, same `.ymir-root`. */
function deployedHome(): string {
  const home = mkdtempSync(join(tmpdir(), "constellation-pi-home-"));
  const extensions = join(home, "extensions");
  mkdirSync(join(extensions, "lib"), { recursive: true });
  cpSync(join(ROOT, ".pi/shared/extensions"), extensions, { recursive: true, filter: (src) => !src.includes("/lib/") });
  cpSync(join(ROOT, ".pi/extensions/lib"), join(extensions, "lib"), {
    recursive: true,
    filter: (src) => !src.endsWith(".test.ts"),
  });
  writeFileSync(join(extensions, ".ymir-root"), `${ROOT}\n`);
  return extensions;
}

test("the deployed extension loads and registers exactly the three constellation tools", async () => {
  const state = mkdtempSync(join(tmpdir(), "constellation-state-"));
  const previousState = process.env.BROKK_STATE_OVERRIDE;
  const previousRegistry = process.env.CONSTELLATION_REGISTRY;
  delete process.env.CONSTELLATION_REGISTRY;
  process.env.BROKK_STATE_OVERRIDE = state;
  const extensions = deployedHome();
  try {
    const deployed = await import(pathToFileURL(join(extensions, "constellation.ts")).href);
    assert.equal(typeof deployed.default, "function", "the factory must export");

    const { pi, registered, events } = stubPi();
    deployed.default(pi);
    assert.deepEqual(
      registered.map((tool) => tool.name).sort(),
      TOOLS,
      "the mesh's surface is list, ask, card — no more, no fewer",
    );
    assert.deepEqual(events, ["session_start"]);
    for (const tool of registered) {
      assert.equal(typeof tool.execute, "function", `${tool.name} must be callable, not a stub`);
    }

    // The load marker: the same proof gna-pi-watch writes for itself, in the same
    // state dir, so a seat can see which extensions actually loaded.
    const marker = readFileSync(join(state, ".pi-constellation-loaded"), "utf8");
    assert.match(marker, /^sha256:[0-9a-f]{64}/);
    assert.match(marker, new RegExp(`${process.pid}\\n$`));
  } finally {
    if (previousState === undefined) delete process.env.BROKK_STATE_OVERRIDE;
    else process.env.BROKK_STATE_OVERRIDE = previousState;
    if (previousRegistry !== undefined) process.env.CONSTELLATION_REGISTRY = previousRegistry;
  }
});

test("with no registry configured, list and ask SKIP loudly rather than reporting an empty mesh", async () => {
  const previous = process.env.CONSTELLATION_REGISTRY;
  delete process.env.CONSTELLATION_REGISTRY;
  const extensions = deployedHome();
  try {
    const deployed = await import(pathToFileURL(join(extensions, "constellation.ts")).href);
    const { pi, registered } = stubPi();
    deployed.default(pi);
    const list = registered.find((tool) => tool.name === "constellation_list")!;
    const ask = registered.find((tool) => tool.name === "constellation_ask")!;

    const listed = await list.execute("t1", {});
    assert.equal(listed.isError, true);
    assert.match(listed.content[0].text, /constellation-skip/);
    assert.match(listed.content[0].text, /no registry configured/);
    assert.doesNotMatch(listed.content[0].text, /0 peers found/);

    const asked = await ask.execute("t2", { peer: "heart-zerwizserver", skill: "well-recall" });
    assert.equal(asked.isError, true);
    assert.match(asked.content[0].text, /constellation-skip/);
  } finally {
    if (previous !== undefined) process.env.CONSTELLATION_REGISTRY = previous;
  }
});

test("the project-local file registers nothing — the deployed copy owns the tools", () => {
  const { pi, registered } = stubPi();
  shim(pi);
  assert.deepEqual(registered, [], "loading twice makes pi refuse the duplicate tool");
});
