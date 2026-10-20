/**
 * The two faults of 2026-10-20, pinned so they cannot come back silently.
 *
 *   1. `pi` was not on the service's PATH, so every chat message died with
 *      "Executable not found in $PATH: pi" while pi worked in a terminal.
 *   2. The memory bridge speaks a FLAT payload; the UI contract is NESTED. Nothing
 *      translated, `inspect?.counts.episodes` threw during render, and the Memory page
 *      came up blank with no error.
 *
 * Both are tested here at the boundary where they broke: the resolver, and the adapter.
 */
import { describe, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync, chmodSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { piCommand, piPath, resetPiPathCache } from "./model-catalog.ts";
import { adaptMemoryPayload } from "./memory-adapt.ts";

describe("piPath — the binary is resolved, never assumed", () => {
  test("YMIR_PI_BIN wins when it points at a real executable", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-path-"));
    const fake = join(dir, "pi");
    writeFileSync(fake, "#!/bin/sh\nexit 0\n");
    chmodSync(fake, 0o755);
    const before = process.env.YMIR_PI_BIN;
    process.env.YMIR_PI_BIN = fake;
    resetPiPathCache();
    expect(piPath()).toBe(fake);
    process.env.YMIR_PI_BIN = before;
    resetPiPathCache();
  });

  test("a stale override is skipped for a real binary on PATH", () => {
    const dir = mkdtempSync(join(tmpdir(), "pi-path-"));
    const real = join(dir, "pi");
    writeFileSync(real, "#!/bin/sh\nexit 0\n");
    chmodSync(real, 0o755);
    const before = { bin: process.env.YMIR_PI_BIN, path: process.env.PATH };
    process.env.YMIR_PI_BIN = join(dir, "does-not-exist");
    process.env.PATH = `${dir}:${before.path}`;
    resetPiPathCache();
    expect(piPath()).toBe(real);
    process.env.YMIR_PI_BIN = before.bin;
    process.env.PATH = before.path;
    resetPiPathCache();
  });

  test("the command uses the resolved path, and keeps argv intact", () => {
    const argv = piCommand(["--print", "--model", "x/y", "a prompt with spaces"]);
    expect(argv.length).toBe(5);
    expect(argv.slice(1)).toEqual(["--print", "--model", "x/y", "a prompt with spaces"]);
  });
});

describe("adaptMemoryPayload — the flat bridge shape becomes the UI contract", () => {
  const bridgeHealth = { status: "up", store: "/home/x/kaia.engram", episodes: 133, agents: ["brokk"] };
  const bridgeInspect = {
    store: "/home/x/kaia.engram", episodes: 133, facts: 36, facts_active: 35,
    entities: 60, edges: 480, agents: ["brokk"], episodes_list: [], facts_list: [],
  };

  test("health gains ok and db", () => {
    const d = adaptMemoryPayload("/health", { ...bridgeHealth });
    expect(d.ok).toBe(true);
    expect(d.db).toBe("/home/x/kaia.engram");
    expect(d.episodes).toBe(133);
  });

  test("inspect gains db and counts (the field the page renders)", () => {
    const d = adaptMemoryPayload("/inspect", { ...bridgeInspect });
    expect(d.db).toBe("/home/x/kaia.engram");
    expect(d.counts).toEqual({ episodes: 133, facts: 36, entities: 60, edges: 480 });
  });

  test("counts are never invented from a missing field", () => {
    const d = adaptMemoryPayload("/inspect", { store: "/x", facts: 2 });
    expect(d.counts.episodes).toBe(0);
    expect(d.counts.facts).toBe(2);
  });

  test("an existing counts object is preserved, not overwritten", () => {
    const d = adaptMemoryPayload("/inspect", { store: "/x", counts: { episodes: 9, facts: 1, entities: 2, edges: 3 } });
    expect(d.counts.episodes).toBe(9);
  });

  test("recall and timeline pass through untouched", () => {
    const recall = { results: [{ score: 1, episode: { id: "e" } }] };
    expect(adaptMemoryPayload("/recall", recall)).toEqual(recall);
    const timeline = { facts: [] };
    expect(adaptMemoryPayload("/timeline", timeline)).toEqual(timeline);
  });

  test("a non-object payload is returned unchanged", () => {
    expect(adaptMemoryPayload("/health", "not json")).toBe("not json");
  });
});
