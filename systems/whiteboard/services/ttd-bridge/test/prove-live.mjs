#!/usr/bin/env node
/**
 * prove-bridge.mjs — the command that proves the bridge's three promises.
 *
 *   node systems/whiteboard/services/ttd-bridge/test/prove-live.mjs
 *
 * It starts the REAL bridge against a stub rail on an ephemeral port, so the
 * proof costs nothing and depends on nothing. The stub records exactly what the
 * bridge SENT — which is the part that matters — and answers in the OpenAI-shaped
 * stream the bridge translates:
 *
 *   1. `converse` asks a question and does not answer with a diagram, and its
 *      request carries the whiteboard's own tools;
 *   2. `generate` is unchanged — bare Mermaid out, no tools in, a fence stripped;
 *   3. a rail's usage wall comes back as a sentence with a reset time, never a
 *      bare status code.
 */

import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { createServer as createNetServer } from "node:net";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const serviceDir = resolve(here, "..");
const entry = join(serviceDir, "index.mjs");

const lines = [];
const say = (line) => {
  lines.push(line);
  console.log(line);
};

const freePort = () =>
  new Promise((accept) => {
    const probe = createNetServer();
    probe.listen(0, "127.0.0.1", () => {
      const { port } = probe.address();
      probe.close(() => accept(port));
    });
  });

const seen = [];

/** The stub rail: it answers whatever the test tells it to, and records the request. */
const startStub = async (replyFor) => {
  const port = await freePort();
  const server = createServer(async (req, res) => {
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    const body = JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");
    const system = body.messages?.find((message) => message.role === "system")?.content ?? "";
    seen.push({ body, system });
    const reply = replyFor({ body, system, index: seen.length - 1 });

    if (reply.status && reply.status !== 200) {
      res.writeHead(reply.status, {
        "content-type": "application/json",
        ...(reply.headers ?? {}),
      });
      res.end(JSON.stringify({ error: { message: reply.body ?? "refused" } }));
      return;
    }

    res.writeHead(200, { "content-type": "text/event-stream", "cache-control": "no-cache" });
    for (const piece of reply.pieces ?? []) {
      res.write(`data: ${JSON.stringify({ choices: [{ delta: { content: piece } }] })}\n\n`);
    }
    res.write(
      `data: ${JSON.stringify({ choices: [{ delta: {}, finish_reason: "stop" }], usage: { prompt_tokens: 12, completion_tokens: 7 } })}\n\n`,
    );
    res.write("data: [DONE]\n\n");
    res.end();
  });
  await new Promise((done) => server.listen(port, "127.0.0.1", done));
  return { port, server };
};

const readSse = async (response) => {
  const text = await response.text();
  const frames = text
    .split("\n")
    .filter((line) => line.startsWith("data: "))
    .map((line) => {
      try {
        return JSON.parse(line.slice(6));
      } catch {
        return null;
      }
    })
    .filter(Boolean);
  return {
    content: frames
      .filter((frame) => frame.type === "content")
      .map((frame) => frame.delta)
      .join(""),
    errors: frames.filter((frame) => frame.type === "error").map((frame) => frame.error.message),
    done: frames.find((frame) => frame.type === "done") ?? null,
  };
};

const waitFor = async (url) => {
  for (let i = 0; i < 120; i += 1) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return await response.json();
      }
    } catch {
      /* not up yet */
    }
    await new Promise((done) => setTimeout(done, 60));
  }
  throw new Error(`the bridge never answered ${url}`);
};

let bridge;
const startBridge = async (stubPort) => {
  const port = await freePort();
  const child = spawn(process.execPath, [entry], {
    cwd: serviceDir,
    env: {
      ...process.env,
      TTD_MODEL_BASE_URL: `http://127.0.0.1:${stubPort}/v1`,
      TTD_MODEL: "stub-model",
      TTD_MODEL_API_KEY: "",
      TTD_BRIDGE_PORT: String(port),
      TTD_BRIDGE_HOST: "127.0.0.1",
      TTD_BRIDGE_ORIGINS: "http://localhost:7311",
      TTD_VISION_MODEL: "",
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  child.stdout.on("data", () => {});
  child.stderr.on("data", (chunk) => say(`bridge stderr: ${String(chunk).trim()}`));
  child.once("exit", (code) => {
    if (code !== null && code !== 0) {
      say(`bridge exited with ${code}`);
    }
  });
  await waitFor(`http://127.0.0.1:${port}/healthz`);
  return { child, port, url: `http://127.0.0.1:${port}` };
};

let stub;
try {
  stub = await startStub(({ system, index }) => {
    const converse = /Ask before you draw/.test(system);
    // The rail's wall, on the third call, so it is proved through the SAME door
    // the two modes use.
    if (index === 2) {
      return { status: 429, headers: { "retry-after": "8100" } };
    }
    if (converse) {
      return {
        pieces: [
          "Before I draw this, two questions. ",
          "Is the request sent by the app or by the gateway? ",
          "And must a refusal be visible to the person?",
        ],
      };
    }
    // A model that wraps its answer in a fence, which the generate route strips.
    return { pieces: ["```mermaid\n", "flowchart TD\n  A[Start] --> B[End]\n", "```\n"] };
  });

  bridge = await startBridge(stub.port);
  const health = await fetch(`${bridge.url}/healthz`).then((r) => r.json());
  say(`healthz  modes=${JSON.stringify(health.modes)} tools=${health.tools.length} vision=${health.vision}`);

  // ── 1. converse: a question, not a diagram ───────────────────────────────
  const converse = await readSse(
    await fetch(`${bridge.url}/v1/ai/converse/chat-streaming`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ messages: [{ role: "user", content: "make a diagram of our process" }] }),
    }),
  );
  const asked = converse.content.split("?").length - 1;
  say(`converse reply            questions=${asked} mermaid=${/flowchart|graph TD|-->/.test(converse.content)}`);
  say(`  "${converse.content}"`);
  const sentTools = seen[0].body.tools?.map((tool) => tool.function.name) ?? [];
  say(`  the request carried      tool_choice=${seen[0].body.tool_choice} tools=${sentTools.length} [${sentTools.join(",")}]`);

  // ── 2. generate: bare Mermaid, no tools, fence stripped ──────────────────
  const generated = await readSse(
    await fetch(`${bridge.url}/v1/ai/text-to-diagram/chat-streaming`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ messages: [{ role: "user", content: "start then end" }] }),
    }),
  );
  const bare = generated.content.trim();
  say(`generate reply            fenced=${bare.includes("\`\`\`")} starts=${JSON.stringify(bare.slice(0, 14))}`);
  say(`  "${bare}"`);
  say(`  the request carried      tools=${seen[1].body.tools === undefined ? "none" : seen[1].body.tools.length} tool_choice=${seen[1].body.tool_choice ?? "none"}`);
  say(`  system prompt            bare-Mermaid=${/Reply with the Mermaid source ONLY/.test(seen[1].system)} ask-first=${/Ask before you draw/.test(seen[1].system)}`);

  // ── 3. the wall, said in words ───────────────────────────────────────────
  const wall = await readSse(
    await fetch(`${bridge.url}/v1/ai/converse/chat-streaming`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ messages: [{ role: "user", content: "hello" }] }),
    }),
  );
  say(`usage wall                errors=${wall.errors.length}`);
  say(`  "${wall.errors[0] ?? "(none)"}"`);

  const ok =
    asked > 0 &&
    asked <= 2 &&
    !/flowchart|-->/.test(converse.content) &&
    sentTools.length === 7 &&
    !bare.includes("```") &&
    bare.startsWith("flowchart TD") &&
    seen[1].body.tools === undefined &&
    /Reply with the Mermaid source ONLY/.test(seen[1].system) &&
    /usage limit is reached/.test(wall.errors[0] ?? "") &&
    /2 hours 15 minutes/.test(wall.errors[0] ?? "");

  say(ok ? "RESULT: proven" : "RESULT: NOT PROVEN");
  process.exitCode = ok ? 0 : 1;
} catch (error) {
  say(`FAILED: ${error.message}`);
  process.exitCode = 1;
} finally {
  // Close everything the script opened, or node waits on the stub's listening
  // socket and a proof that printed its answer never hands the prompt back.
  bridge?.child.kill("SIGTERM");
  if (stub) {
    await new Promise((done) => stub.server.close(done));
  }
}
