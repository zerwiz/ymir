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
import { mkdirSync, mkdtempSync, writeFileSync, chmodSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { piCommand, piPath, resetPiPathCache } from "./model-catalog.ts";
import { adaptMemoryPayload } from "./memory-adapt.ts";
import { DEFAULT_CHAT_MODEL, failureReason, volundrPersonaFile, chatModelDefault } from "./chat.ts";

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

describe("failureReason — the real cause, whole (plan 275 item 15)", () => {
  // Measured on this machine, 2026-11-14: pi prints one status line per installed
  // extension on EVERY run, then the provider's answer. The chat used to show
  // the status lines as the cause and cut the provider's words at 300 chars.
  const real =
    'Warning: Model "deepseek-v4-flash" not found for provider "opencode-go". Using custom model id.\n' +
    "[constellation] mesh: unconfigured — no registry configured — set CONSTELLATION_REGISTRY (a git URL or a local path).\n" +
    "[excalidraw] excalidraw: no fork — set EXCALIDRAW_ROOT; fork expects ~/CodeP/excalidraw\n" +
    '400: {"type":"server_error","message":"Upstream request failed: Model is unavailable."}\n';

  test("every [extension] status line is dropped", () => {
    const why = failureReason(real);
    expect(why).not.toContain("[constellation]");
    expect(why).not.toContain("[excalidraw]");
    expect(why).not.toContain("[wayofteams-tools]");
  });

  test("the provider's error is shown whole — not cut at 300 characters", () => {
    const why = failureReason(real);
    expect(why).toContain('400: {"type":"server_error","message":"Upstream request failed: Model is unavailable."}');
    const long = "500: " + "x".repeat(900);
    expect(failureReason(long)).toBe(long);
  });

  test("pi's own warning is kept: it names the model", () => {
    expect(failureReason(real)).toContain("deepseek-v4-flash");
  });

  test("nothing but status lines still says what pi said", () => {
    const only = "[excalidraw] excalidraw: no fork\n";
    expect(failureReason(only)).toBe("[excalidraw] excalidraw: no fork");
  });

  test("the default model is the house's, and one the catalog serves", () => {
    expect(DEFAULT_CHAT_MODEL).toBe("opencode-go/deepseek-v4.1-flash");
    expect(DEFAULT_CHAT_MODEL).not.toBe("opencode-go/deepseek-v4-flash");
  });
});

describe("volundrPersonaFile — the chat answers as Völundr, never as the seat (plan 275, helm 2026-11-14)", () => {
  const withEnv = (value: string | undefined, fn: () => void) => {
    const before = process.env.VOLUNDR_PERSONA;
    const beforeOld = process.env.KAIA_PERSONA;
    delete process.env.VOLUNDR_PERSONA;
    delete process.env.KAIA_PERSONA;
    if (value !== undefined) process.env.VOLUNDR_PERSONA = value;
    try { fn(); } finally {
      delete process.env.VOLUNDR_PERSONA;
      delete process.env.KAIA_PERSONA;
      if (before !== undefined) process.env.VOLUNDR_PERSONA = before;
      if (beforeOld !== undefined) process.env.KAIA_PERSONA = beforeOld;
    }
  };
  const withOldEnv = (value: string | undefined, fn: () => void) => {
    const before = process.env.VOLUNDR_PERSONA;
    const beforeOld = process.env.KAIA_PERSONA;
    delete process.env.VOLUNDR_PERSONA;
    delete process.env.KAIA_PERSONA;
    if (value !== undefined) process.env.KAIA_PERSONA = value;
    try { fn(); } finally {
      delete process.env.VOLUNDR_PERSONA;
      delete process.env.KAIA_PERSONA;
      if (before !== undefined) process.env.VOLUNDR_PERSONA = before;
      if (beforeOld !== undefined) process.env.KAIA_PERSONA = beforeOld;
    }
  };

  test("VOLUNDR_PERSONA wins when it is a real file", () => {
    const dir = mkdtempSync(join(tmpdir(), "volundr-persona-"));
    const file = join(dir, "mine.md");
    writeFileSync(file, "You are Völundr.\n");
    withEnv(file, () => expect(volundrPersonaFile(dir)).toBe(file));
  });

  test("the historical KAIA_PERSONA is still read, so no wrapper breaks", () => {
    const dir = mkdtempSync(join(tmpdir(), "volundr-persona-"));
    const file = join(dir, "mine.md");
    writeFileSync(file, "You are Völundr.\n");
    withOldEnv(file, () => expect(volundrPersonaFile(dir)).toBe(file));
  });

  test("VOLUNDR_PERSONA beats KAIA_PERSONA when both are set", () => {
    const dir = mkdtempSync(join(tmpdir(), "volundr-persona-"));
    const fresh = join(dir, "fresh.md");
    const old = join(dir, "old.md");
    writeFileSync(fresh, "You are Völundr.\n");
    writeFileSync(old, "You are Kaia.\n");
    const before = process.env.KAIA_PERSONA;
    process.env.KAIA_PERSONA = old;
    try {
      withEnv(fresh, () => expect(volundrPersonaFile(dir)).toBe(fresh));
    } finally {
      if (before === undefined) delete process.env.KAIA_PERSONA;
      else process.env.KAIA_PERSONA = before;
    }
  });

  test("a stale persona file is skipped, not trusted", () => {
    const dir = mkdtempSync(join(tmpdir(), "volundr-persona-"));
    withEnv(join(dir, "gone.md"), () => {
      const got = volundrPersonaFile(dir);
      expect(got).not.toBe(join(dir, "gone.md"));
      expect(got).toMatch(/volundr\.md$/);
    });
  });

  test("the operator's home override beats the shipped default", () => {
    const home = mkdtempSync(join(tmpdir(), "volundr-home-"));
    const override = join(home, ".agents/skills/smidja/volundr/persona.md");
    mkdirSync(join(home, ".agents/skills/smidja/volundr"), { recursive: true });
    writeFileSync(override, "You are Völundr, in this operator's own words.\n");
    withEnv(undefined, () => expect(volundrPersonaFile(home)).toBe(override));
  });

  test("the historical home path is still read: an existing kaia/persona.md keeps working", () => {
    const home = mkdtempSync(join(tmpdir(), "volundr-home-"));
    const legacy = join(home, ".agents/skills/smidja/kaia/persona.md");
    mkdirSync(join(home, ".agents/skills/smidja/kaia"), { recursive: true });
    writeFileSync(legacy, "You are Völundr, written before the rename.\n");
    withEnv(undefined, () => expect(volundrPersonaFile(home)).toBe(legacy));
  });

  test("with nothing in the target repo, the app's own default is found", () => {
    const empty = mkdtempSync(join(tmpdir(), "volundr-empty-"));
    withEnv(undefined, () => {
      const got = volundrPersonaFile(empty);
      expect(got).toMatch(/apps\/smidja-factory\/apps\/visualizer\/prompts\/volundr\.md$/);
    });
  });
});

describe("chatModelDefault — the repo is agnostic, the operator's home names the model", () => {
  const withEnv = (value: string | undefined, fn: () => void) => {
    const before = process.env.SMIDJA_CHAT_MODEL;
    if (value === undefined) delete process.env.SMIDJA_CHAT_MODEL;
    else process.env.SMIDJA_CHAT_MODEL = value;
    try { fn(); } finally {
      if (before === undefined) delete process.env.SMIDJA_CHAT_MODEL;
      else process.env.SMIDJA_CHAT_MODEL = before;
    }
  };

  test("no home config and no environment: the repo's generic default", () => {
    const empty = mkdtempSync(join(tmpdir(), "volundr-model-"));
    withEnv(undefined, () => expect(chatModelDefault(empty)).toBe(DEFAULT_CHAT_MODEL));
  });

  test("the home's config/smidja.env names the operator's own model", () => {
    const home = mkdtempSync(join(tmpdir(), "volundr-model-"));
    mkdirSync(join(home, "config"), { recursive: true });
    writeFileSync(join(home, "config/smidja.env"), "# mine\nSMIDJA_CHAT_MODEL=openrouter/some-model\n");
    withEnv(undefined, () => expect(chatModelDefault(home)).toBe("openrouter/some-model"));
  });

  test("an environment variable wins over the file", () => {
    const home = mkdtempSync(join(tmpdir(), "volundr-model-"));
    mkdirSync(join(home, "config"), { recursive: true });
    writeFileSync(join(home, "config/smidja.env"), "SMIDJA_CHAT_MODEL=from-file\n");
    withEnv("from-environment", () => expect(chatModelDefault(home)).toBe("from-environment"));
  });

  test("a blank line in the file falls back to the default, never to an empty id", () => {
    const home = mkdtempSync(join(tmpdir(), "volundr-model-"));
    mkdirSync(join(home, "config"), { recursive: true });
    writeFileSync(join(home, "config/smidja.env"), "SMIDJA_CHAT_MODEL=\n");
    withEnv(undefined, () => expect(chatModelDefault(home)).toBe(DEFAULT_CHAT_MODEL));
  });
});
