#!/usr/bin/env node
/**
 * TTD bridge — a self-hosted backend for the Excalidraw AI panel.
 *
 *   TTD_MODEL_BASE_URL=http://127.0.0.1:8080/v1 \
 *   TTD_MODEL=qwen3.6-35b-a3b@q4_k_xl \
 *   node server/ttd-bridge/index.mjs
 *
 * Then set "AI text-to-diagram backend" to this bridge's URL in Settings
 * (http://127.0.0.1:7313).
 *
 * It binds localhost by default. It logs timing and token counts — never a
 * prompt, never a response body, never a credential.
 */

import { createServer } from "node:http";

import {
  buildUpstreamRequest,
  buildVisionRequest,
  createFenceFilter,
  explainFailure,
  fetchFirstUpstream,
  modelFor,
  readConfig,
  sse,
  translateUpstream,
  ttdError,
  withSystemPrompt,
} from "./bridge.mjs";
import { ALLOWED_TOOL_NAMES, narrowToAllowed, toolsFor } from "./tools.mjs";

const config = readConfig();

if (!config.modelBaseURL) {
  console.error(
    "TTD_MODEL_BASE_URL is not set — the bridge refuses to pick a hosted " +
      "default. Point it at a model (e.g. http://127.0.0.1:8080/v1).",
  );
  process.exit(1);
}

const json = (res, status, body) => {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(payload),
  });
  res.end(payload);
};

const applyCors = (req, res) => {
  const origin = req.headers.origin;
  if (origin && config.allowedOrigins.includes(origin)) {
    res.setHeader("access-control-allow-origin", origin);
    res.setHeader("vary", "origin");
  }
  res.setHeader("access-control-allow-methods", "POST, OPTIONS");
  res.setHeader("access-control-allow-headers", "content-type");
};

const readBody = (req) =>
  new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on("data", (chunk) => {
      size += chunk.length;
      // A prompt is text; 1 MiB is generous and stops an unbounded upload.
      if (size > 1024 * 1024) {
        reject(new Error("Request body too large."));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });

/**
 * The chat routes: `generate` and `converse` — one rail, one prompt per mode.
 *
 * `generate` is UNTOUCHED and must stay so: its client parses the reply as
 * Mermaid, so it gets the bare-Mermaid instruction, a fence filter, and NO tools.
 *
 * `converse` is the new mode from feature-0037: plain words, no diagram required,
 * no fence filter (a fence is a markdown habit, not an error, in prose), and the
 * whiteboard's own tools. The conversation is carried into `generate` by the
 * panel sending the accepted messages, so the figure reflects what was agreed
 * instead of being a fresh guess.
 */
const handleChat = async (mode, req, res) => {
  let payload;
  try {
    payload = JSON.parse(await readBody(req));
  } catch (error) {
    return json(res, 400, { error: error.message });
  }

  const messages = Array.isArray(payload?.messages) ? payload.messages : [];
  if (!messages.length) {
    return json(res, 400, { error: "messages is required" });
  }

  const startedAt = Date.now();
  const controller = new AbortController();
  req.on("close", () => controller.abort());

  // The panel sends the person's words; the bridge adds the instruction that
  // makes the reply usable — Mermaid for `generate`, plain conversation for
  // `converse`.
  const systemPrompt = mode === "converse" ? config.conversePrompt : config.systemPrompt;
  const instructed = withSystemPrompt(messages, systemPrompt);

  // Tools are the converse route's alone. A client may NARROW the surface, never
  // widen it: `narrowToAllowed` filters against the board's own list and any
  // name outside it is dropped.
  const tools = mode === "converse" ? narrowToAllowed(payload.tools) ?? toolsFor(mode) : [];

  res.writeHead(200, {
    "content-type": "text/event-stream",
    "cache-control": "no-cache, no-transform",
    connection: "keep-alive",
  });

  // Walk the upstreams. This happens BEFORE any frame is written, which is the
  // only place a fallback is allowed — see `fetchFirstUpstream`.
  const { response, upstream, failed, lastError } = await fetchFirstUpstream(
    config.upstreams,
    (candidate) =>
      buildUpstreamRequest(
        {
          baseURL: candidate.baseURL,
          model: modelFor(candidate, payload.model),
          apiKey: candidate.apiKey,
        },
        { messages: instructed, signal: controller.signal, tools },
      ),
    { signal: controller.signal },
  );

  if (!response) {
    // The wall is shown: a usage limit becomes a sentence with a reset time, not
    // a bare status code (plan 233 §16).
    const wall = failed.find((entry) => entry.status !== undefined);
    const explained = wall
      ? explainFailure(wall)
      : { kind: "error", message: `No model answered. ${lastError ?? "".trim()}`.trim() };
    res.write(sse(ttdError(explained.message)));
    res.end();
    // Names the machines, never the prompt.
    console.log(
      JSON.stringify({
        event: mode === "converse" ? "ttd-converse" : "ttd",
        ok: false,
        kind: explained.kind,
        ms: Date.now() - startedAt,
        model: payload.model || config.model,
        failed,
        messages: messages.length,
        tools: tools.length,
      }),
    );
    return;
  }

  let tokens = null;
  let firstDeltaAt = null;

  try {
    // A fence filter belongs to `generate` only: in prose a fence is harmless.
    const fenceFilter = mode === "generate" ? createFenceFilter() : null;
    for await (const frame of translateUpstream(response, {
      ...(fenceFilter ? { transform: fenceFilter } : {}),
      onUsage: (usage) => {
        tokens = usage;
      },
    })) {
      if (firstDeltaAt === null && frame.includes('"type":"content"')) {
        firstDeltaAt = Date.now();
      }
      res.write(frame);
    }
  } catch (error) {
    // No failover here, deliberately: content may already be in the panel.
    res.write(sse(ttdError(error?.message ?? String(error))));
  } finally {
    res.end();
    // Timing, counts and WHICH MACHINE — never the prompt, never the completion.
    console.log(
      JSON.stringify({
        event: mode === "converse" ? "ttd-converse" : "ttd",
        ok: true,
        ms: Date.now() - startedAt,
        firstDeltaMs: firstDeltaAt === null ? null : firstDeltaAt - startedAt,
        model: payload.model || upstream.model,
        upstream: upstream.name,
        failovers: failed.length,
        tools: tools.length,
        tokens: tokens
          ? { prompt: tokens.prompt_tokens, completion: tokens.completion_tokens }
          : null,
        messages: messages.length,
      }),
    );
  }
};

const handleTextToDiagram = (req, res) => handleChat("generate", req, res);
const handleConverse = (req, res) => handleChat("converse", req, res);

/**
 * Diagram to code — the VISION route.
 *
 * A drawing goes in and code comes out. It needs a model that can SEE, which is a
 * different model from the text one, so it is configured separately: with no
 * `TTD_VISION_MODEL` the route refuses with exactly that reason rather than
 * pretending, and the panel shows it.
 */
const handleDiagramToCode = async (req, res) => {
  let payload;
  try {
    payload = JSON.parse(await readBody(req));
  } catch (error) {
    return json(res, 400, { error: error.message });
  }

  res.writeHead(200, {
    "content-type": "text/event-stream",
    "cache-control": "no-cache, no-transform",
    connection: "keep-alive",
  });

  if (!config.visionModel) {
    res.write(
      sse(
        ttdError(
          "No vision model is configured for this bridge. Set TTD_VISION_MODEL to a " +
            "model that can see images (one launched with an mmproj projector).",
        ),
      ),
    );
    res.end();
    return;
  }

  const startedAt = Date.now();
  const controller = new AbortController();
  req.on("close", () => controller.abort());

  const buildRequest = (candidate) =>
    buildVisionRequest(
      {
        baseURL: candidate.baseURL,
        // The vision model is its own setting, not the upstream's text model.
        model: payload.model || config.visionModel,
        apiKey: candidate.apiKey,
      },
      {
        texts: payload.texts,
        image: payload.image,
        signal: controller.signal,
      },
    );

  // Whether an image is present does not depend on WHICH upstream is asked, so
  // one build settles it — and the refusal costs no request at all.
  if (!buildRequest(config.upstreams[0]).hasImage) {
    res.write(sse(ttdError("The request carried no image to read.")));
    res.end();
    return;
  }

  const { response, upstream, failed, lastError } = await fetchFirstUpstream(
    config.upstreams,
    buildRequest,
    { signal: controller.signal },
  );

  if (!response) {
    res.write(sse(ttdError(`No model answered. ${lastError ?? "".trim()}`.trim())));
    res.end();
    console.log(
      JSON.stringify({
        event: "ttd-vision",
        ok: false,
        ms: Date.now() - startedAt,
        model: payload.model || config.visionModel,
        failed,
      }),
    );
    return;
  }

  let firstDeltaAt = null;
  try {
    const fenceFilter = createFenceFilter();
    for await (const frame of translateUpstream(response, { transform: fenceFilter })) {
      if (firstDeltaAt === null && frame.includes('"type":"content"')) {
        firstDeltaAt = Date.now();
      }
      res.write(frame);
    }
  } catch (error) {
    res.write(sse(ttdError(error?.message ?? String(error))));
  } finally {
    res.end();
    // Timing only. The prompt and the IMAGE are never logged.
    console.log(
      JSON.stringify({
        event: "ttd-vision",
        ok: true,
        ms: Date.now() - startedAt,
        firstDeltaMs: firstDeltaAt === null ? null : firstDeltaAt - startedAt,
        model: payload.model || config.visionModel,
        upstream: upstream.name,
        failovers: failed.length,
      }),
    );
  }
};

const server = createServer(async (req, res) => {
  applyCors(req, res);

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    return res.end();
  }

  const url = new URL(req.url ?? "/", "http://localhost");

  if (req.method === "GET" && url.pathname === "/healthz") {
    return json(res, 200, {
      ok: true,
      model: config.model || null,
      vision: Boolean(config.visionModel),
      // The two modes are the contract: `generate` is bare Mermaid, `converse`
      // is plain words with the board's own tools.
      modes: { generate: true, converse: true },
      tools: [...ALLOWED_TOOL_NAMES],
      // The base URL is operator-supplied, so echoing it leaks nothing.
      upstream: config.modelBaseURL,
      // The order the request path walks. Deliberately NOT probed: a health check
      // that waits on a cold model is not a health check. `hasKey` says whether a
      // key is held, never what it is.
      upstreams: config.upstreams.map((candidate, index) => ({
        name: candidate.name,
        upstream: candidate.baseURL,
        model: candidate.model || null,
        hasKey: Boolean(candidate.apiKey),
        primary: index === 0,
      })),
    });
  }

  if (req.method === "POST" && url.pathname === "/v1/ai/text-to-diagram/chat-streaming") {
    return handleTextToDiagram(req, res);
  }

  // The conversation before the diagram (feature-0037). Same rail, plain words,
  // the whiteboard's own tools — and no Mermaid requirement.
  if (req.method === "POST" && url.pathname === "/v1/ai/converse/chat-streaming") {
    return handleConverse(req, res);
  }

  if (
    req.method === "POST" &&
    url.pathname === "/v1/ai/diagram-to-code/generate-streaming"
  ) {
    return handleDiagramToCode(req, res);
  }

  return json(res, 404, { error: `no route ${req.method} ${url.pathname}` });
});

server.listen(config.port, config.host, () => {
  // The fallback is announced, not hidden: an operator reading the journal should
  // be able to see that a second door exists without reading the unit file.
  const fallback = config.upstreams[1];
  console.log(
    `TTD bridge on http://${config.host}:${config.port} → ${config.modelBaseURL}${
      config.model ? ` (model ${config.model})` : ""
    }${fallback ? ` → fallback ${fallback.baseURL}` : " (no fallback)"}`,
  );
});
