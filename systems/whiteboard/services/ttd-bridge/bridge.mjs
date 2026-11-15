/**
 * TTD bridge — the translation layer between the Excalidraw AI panel and any
 * OpenAI-compatible model.
 *
 * The panel's client contract is unchanged: it POSTs the prompt and parses an
 * SSE stream of `{type:"content",delta}` … `{type:"done",finishReason}`.
 * This module converts an upstream OpenAI `chat.completions` stream into that
 * contract, so the model behind it can be local (llama.cpp), Claude, OpenCode
 * Zen, or anything else OpenAI-shaped.
 *
 * Deliberate: this file never logs or returns a prompt, and never returns an
 * upstream API key. See `tickets/open/feature-0005-uw-local-ai-text-to-diagram-backend.md`.
 */

export { explainFailure } from "./usage-limit.mjs";
import { explainFailure } from "./usage-limit.mjs";

/** The TTD event shapes the panel's `parseSSEStream` understands. */
export const ttdContent = (delta) => ({ type: "content", delta });

export const ttdToolCall = (delta) => ({ type: "tool_call", delta });

export const ttdDone = (finishReason = "stop") => ({
  type: "done",
  finishReason,
});

export const ttdError = (message, status) => ({
  type: "error",
  error: { message, ...(status === undefined ? {} : { status }) },
});

/** One SSE frame. The panel splits on blank lines and reads `data: ` lines. */
export const sse = (obj) => `data: ${JSON.stringify(obj)}\n\n`;

export const normalizeBaseURL = (url) => String(url ?? "").trim().replace(/\/+$/, "");

/**
 * The upstream request. `stream: true` is not optional — the panel renders
 * progressively and the bridge must not buffer the whole completion.
 *
 * `tools` reach a model ONLY from the converse route (see `tools.mjs`): the
 * generate route's client parses the reply as Mermaid, so a tool call there
 * would be a regression, and it is prevented by never offering one.
 */
export const buildUpstreamRequest = (
  { baseURL, model, apiKey },
  { messages, signal, tools } = {},
) => {
  const url = `${normalizeBaseURL(baseURL)}/chat/completions`;
  const headers = { "content-type": "application/json" };
  // A local server needs no key; sending none keeps llama.cpp happy.
  if (apiKey) {
    headers.Authorization = `Bearer ${apiKey}`;
    // opencode's Go inference refuses a request without a session id ("cannot be routed efficiently")
    const _sess = process.env.TTD_MODEL_SESSION || "whiteboard-bridge";
    headers["x-opencode-session"] = _sess;
  }
  const body = { model, messages, stream: true };
  if (Array.isArray(tools) && tools.length > 0) {
    body.tools = tools;
    body.tool_choice = "auto";
  }
  return {
    url,
    init: {
      method: "POST",
      headers,
      body: JSON.stringify(body),
      ...(signal ? { signal } : {}),
    },
  };
};

/**
 * Parses one upstream `data:` payload. Returns `null` for the terminal
 * `[DONE]` and for anything unparseable, so a malformed frame is skipped
 * rather than killing the stream.
 */
export const parseUpstreamChunk = (raw) => {
  const payload = String(raw).trim();
  if (payload === "" || payload === "[DONE]") {
    return null;
  }
  let obj;
  try {
    obj = JSON.parse(payload);
  } catch {
    return null;
  }
  const choice = obj?.choices?.[0];
  const content = choice?.delta?.content;
  const toolCalls = choice?.delta?.tool_calls;
  return {
    delta: typeof content === "string" ? content : "",
    toolCalls: Array.isArray(toolCalls) ? toolCalls : null,
    finishReason: choice?.finish_reason ?? null,
    usage: obj?.usage ?? null,
  };
};

/** Maps an OpenAI finish_reason onto the panel's vocabulary. */
export const mapFinishReason = (reason) => {
  switch (reason) {
    case "length":
    case "content_filter":
    case "tool_calls":
    case "stop":
      return reason;
    default:
      return "stop";
  }
};

/**
 * Turns an upstream SSE byte stream into TTD SSE frames.
 *
 * Yields strings ready to write to the response. On upstream error it yields a
 * `ttdError` frame — the panel renders that instead of hanging.
 */
export async function* translateUpstream(response, { onUsage, transform } = {}) {
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    // A metered rail's wall is not a fault: it is a sentence with a time in it,
    // and a person reading the panel deserves that sentence (plan 233 §16).
    const explained = explainFailure({
      status: response.status,
      detail: detail.slice(0, 1000),
      headers: response.headers,
      message: `Upstream returned ${response.status}${
        detail ? `: ${detail.slice(0, 300)}` : ""
      }`,
    });
    yield sse(ttdError(explained.message, response.status));
    return;
  }

  const reader = response.body?.getReader();
  if (!reader) {
    yield sse(ttdError("Upstream returned no body."));
    return;
  }

  const decoder = new TextDecoder();
  let buffer = "";
  let sawDone = false;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      buffer += decoder.decode(value, { stream: true });

      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed.startsWith("data:")) {
          continue;
        }
        const chunk = parseUpstreamChunk(trimmed.slice(5));
        if (!chunk) {
          continue;
        }
        if (chunk.delta) {
          // `transform` is how the fence filter gets in: it holds back a leading
          // fence until it can tell one from content.
          const text = transform ? transform.push(chunk.delta) : chunk.delta;
          if (text) {
            yield sse(ttdContent(text));
          }
        }
        if (chunk.toolCalls) {
          yield sse(ttdToolCall(chunk.toolCalls));
        }
        if (chunk.usage && typeof onUsage === "function") {
          onUsage(chunk.usage);
        }
        if (chunk.finishReason) {
          yield sse(ttdDone(mapFinishReason(chunk.finishReason)));
          sawDone = true;
        }
      }
    }
  } catch (error) {
    yield sse(ttdError(error?.message ?? String(error)));
    return;
  } finally {
    reader.releaseLock?.();
  }

  // Flush whatever the transform was holding back (a trailing fence, usually).
  if (transform) {
    const tail = transform.end();
    if (tail) {
      yield sse(ttdContent(tail));
    }
  }

  // Some servers close without a finish_reason; the panel needs a terminal
  // event or it stays in a generating state.
  if (!sawDone) {
    yield sse(ttdDone("stop"));
  }
}

/**
 * The instruction a VISION model is given, for the diagram-to-code route.
 *
 * The panel sends the frame's texts and a PNG data URL; the model answers with
 * code. Same reason as the Mermaid prompt: without it a general model wraps the
 * answer in prose and the panel cannot use it.
 */
export const DEFAULT_VISION_PROMPT = [
  "You are given a hand-drawn wireframe or diagram as an image, plus any text in it.",
  "Produce clean, semantic HTML with inline CSS that reproduces the layout.",
  "Reply with the code ONLY: no explanation, no markdown fences, no commentary.",
].join("\n");

/**
 * The upstream request for the vision route. The image travels as an OpenAI
 * `image_url` content part carrying the data URL the panel already produced — it
 * goes to the model the operator configured and nowhere else.
 */
export const buildVisionRequest = (
  { baseURL, model, apiKey },
  { prompt = DEFAULT_VISION_PROMPT, texts = [], image, signal } = {},
) => {
  const url = `${normalizeBaseURL(baseURL)}/chat/completions`;
  const headers = { "content-type": "application/json" };
  if (apiKey) {
    headers.Authorization = `Bearer ${apiKey}`;
  }

  const parts = [{ type: "text", text: prompt }];
  if (Array.isArray(texts) && texts.length) {
    parts.push({ type: "text", text: `Text in the drawing: ${texts.join(" | ")}` });
  }
  if (typeof image === "string" && image.startsWith("data:")) {
    parts.push({ type: "image_url", image_url: { url: image } });
  }

  return {
    url,
    hasImage: parts.some((part) => part.type === "image_url"),
    init: {
      method: "POST",
      headers,
      body: JSON.stringify({
        model,
        stream: true,
        messages: [{ role: "user", content: parts }],
      }),
      ...(signal ? { signal } : {}),
    },
  };
};

/**
 * The instruction the model is given, prepended to whatever the panel sent.
 *
 * The panel expects **bare Mermaid** — it parses the reply as Mermaid and shows
 * "Mermaid syntax error" for anything else. A general coding model will happily
 * wrap it in prose or a code fence, which is a transport problem, not a user
 * problem, so the bridge fixes it here.
 *
 * Override with `TTD_SYSTEM_PROMPT` when a model needs different words.
 */
export const DEFAULT_SYSTEM_PROMPT = [
  "You turn a description into a Mermaid diagram.",
  "",
  "Reply with the Mermaid source ONLY: no explanation, no commentary, no code",
  "fences, no markdown. The first character of your reply must begin the diagram",
  "(for example `flowchart TD`). Use valid Mermaid syntax and nothing else.",
].join("\n");

export const withSystemPrompt = (messages, systemPrompt = DEFAULT_SYSTEM_PROMPT) => {
  const list = Array.isArray(messages) ? messages : [];
  if (!systemPrompt) {
    return list;
  }
  // Do not double up if the caller already sent a system message.
  if (list.some((message) => message?.role === "system")) {
    return list;
  }
  return [{ role: "system", content: systemPrompt }, ...list];
};

/**
 * The instruction the model is given in CONVERSE mode — the same rail, a
 * different job.
 *
 * The rule the ticket is built on: talking is the first tool. A person brings a
 * half-formed problem, and the measured failure is the invented flow — "make a
 * diagram of our process" answered with Start → Request → Approve → End,
 * plausible and wrong. So when the request is ambiguous the model asks AT MOST
 * TWO questions and waits, rather than guessing and drawing. Two, because a wall
 * of questions is an interrogation, not a conversation.
 *
 * Override with `TTD_CONVERSE_PROMPT`.
 */
export const DEFAULT_CONVERSE_PROMPT = [
  "You are the assistant inside a whiteboard. You are talking with the person",
  "who owns the board, before anything is drawn.",
  "",
  "Talk in plain words. Do not reply with Mermaid, code, or a diagram unless they",
  "explicitly ask you to draw. No markdown fences.",
  "",
  "Ask before you draw. When what they want is ambiguous, ask AT MOST TWO short",
  "questions and then wait for the answer — do not guess and present a finished",
  "diagram. When it is clear, say in a couple of sentences what you would draw and",
  "offer the options worth choosing between, then let them say draw it.",
  "",
  "You may read the canvas before you speak, so that what you propose fits what is",
  "already there. Say plainly when you are reading it.",
  "",
  "Your tools are the whiteboard's own, and nothing else: you cannot search the web,",
  "open a file, read a record, send mail or reach any other system. If a request",
  "needs one of those, say so and stop.",
  "",
  "Be brief. Two short paragraphs at most unless they ask for more.",
].join("\n");

/**
 * Strips a code fence from the model's reply.
 *
 * Streaming makes this a state machine, not a regex: a fence arrives in pieces.
 * This holds back a small prefix until it knows whether it is a fence, and drops
 * a trailing fence at the end — without buffering the whole completion.
 */
export const createFenceFilter = () => {
  let buffered = "";
  let leadingResolved = false;
  let sawContent = false;

  const FENCE_OPEN = /^\s*```[a-zA-Z]*\s*\n?/;
  const FENCE_CLOSE = /\n?\s*```\s*$/;
  // A closing fence can arrive as "``" then "`" in separate deltas, so the last
  // few characters are held back until the stream ends. Holding back a handful
  // of characters costs nothing: a diagram is inserted when the stream is done.
  const HOLDBACK = 8;

  const emit = () => {
    if (buffered.length <= HOLDBACK) {
      return "";
    }
    const out = buffered.slice(0, buffered.length - HOLDBACK);
    buffered = buffered.slice(buffered.length - HOLDBACK);
    if (out.trim() !== "") {
      sawContent = true;
    }
    return out;
  };

  return {
    push(delta) {
      if (!delta) {
        return "";
      }
      buffered += delta;

      if (!leadingResolved) {
        // Decide whether the opening characters are a fence. Wait for a newline
        // (a fence line ends) or for enough characters to know it is not one —
        // but never eat the head of a reply that just starts with a backtick.
        const looksLikeFence = /^\s*`/.test(buffered);
        const decided =
          buffered.includes("\n") || buffered.length >= 32 || !looksLikeFence;
        if (!decided) {
          return "";
        }
        leadingResolved = true;
        buffered = buffered.replace(FENCE_OPEN, "");
      }

      return emit();
    },
    /** Flush the tail, dropping a closing fence. */
    end() {
      let out = buffered;
      buffered = "";
      if (!leadingResolved) {
        leadingResolved = true;
        out = out.replace(FENCE_OPEN, "");
      }
      out = out.replace(FENCE_CLOSE, "");
      if (out.trim() !== "") {
        sawContent = true;
      }
      return out;
    },
    get sawContent() {
      return sawContent;
    },
  };
};

/**
 * One upstream — a model host the bridge may call, with the model id and key
 * THAT host serves.
 *
 * Each upstream carries its own model rather than sharing one, because two
 * machines are not one catalogue: the fleet's rails hold different alias sets,
 * so a fallback named with the primary's alias would answer `400 model not
 * found` — a failover that fails over into a second failure.
 */
export const readUpstream = (env, prefix = "", name = "primary") => ({
  name,
  baseURL: normalizeBaseURL(env[`TTD_${prefix}MODEL_BASE_URL`]),
  model: env[`TTD_${prefix}MODEL`] ?? "",
  apiKey: env[`TTD_${prefix}MODEL_API_KEY`] ?? "",
});

/**
 * The model an upstream is asked for.
 *
 * The upstream's OWN model wins over one supplied with the request. Two machines
 * are not one catalogue: a name that exists on the primary may not exist on the
 * fallback, and asking the fallback for the primary's alias turns a failover into
 * a second failure — `400 model not found`. The request's model fills in only
 * when the upstream names none, which is the case today: the panel sends none.
 */
export const modelFor = (upstream, requested) => upstream.model || requested || "";

/**
 * Reads the bridge's configuration from the environment. Nothing is defaulted
 * to a hosted host: with no `TTD_MODEL_BASE_URL` the bridge refuses to start.
 *
 * `upstreams` is the ordered list the request path walks — primary first, then
 * the optional fallback. `modelBaseURL`/`model`/`modelApiKey` remain the
 * PRIMARY's values, so the startup refusal and `/healthz` keep meaning what they
 * meant before this list existed.
 */
export const readConfig = (env = process.env) => {
  const primary = readUpstream(env, "", "primary");
  const fallback = readUpstream(env, "FALLBACK_", "fallback");
  return {
  port: Number(env.TTD_BRIDGE_PORT ?? 7313),
  host: env.TTD_BRIDGE_HOST ?? "127.0.0.1",
  /** the doors the request path walks, in order; a base URL-less entry is not a door */
  upstreams: [primary, fallback].filter((upstream) => upstream.baseURL),
  modelBaseURL: primary.baseURL,
  model: primary.model,
  modelApiKey: primary.apiKey,
  /** the model that serves the VISION route; unset means the route is refused */
  visionModel: env.TTD_VISION_MODEL ?? "",
  /** the instruction prepended to the panel's messages */
  systemPrompt: env.TTD_SYSTEM_PROMPT ?? DEFAULT_SYSTEM_PROMPT,
  /** the instruction prepended in converse mode — plain words, ask before drawing */
  conversePrompt: env.TTD_CONVERSE_PROMPT ?? DEFAULT_CONVERSE_PROMPT,
  /** comma-separated origins allowed to call the bridge */
  allowedOrigins: (env.TTD_BRIDGE_ORIGINS ?? "http://localhost:7311,http://127.0.0.1:7311")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean),
  };
};

/**
 * Calls the upstreams in order and returns the first one that can serve the
 * request.
 *
 * THE BOUNDARY IS THE WHOLE DESIGN, and it is here rather than in the caller
 * because it is a property of the protocol, not of a route: failover is allowed
 * only while NOTHING has been written to the client. `fetch` rejecting, a
 * non-ok status, and a missing body are all decided before a single frame is
 * sent, so they are safe to retry. Once a content frame has gone out the client
 * has begun rendering one machine's answer, and a whole answer from another
 * machine cannot be quietly substituted for it — a half-diagram plus a stated
 * error is the honest outcome, and there is no failover after that point.
 *
 * A request the client abandoned stops the walk: trying a second host for a
 * reader who has gone is work nobody will see.
 */
export const fetchFirstUpstream = async (
  upstreams,
  buildRequest,
  { fetchImpl = fetch, signal } = {},
) => {
  const failed = [];
  let lastError = null;

  for (const upstream of upstreams) {
    if (signal?.aborted) {
      return { response: null, upstream: null, failed, lastError: "The client disconnected." };
    }
    const { url, init } = buildRequest(upstream);
    try {
      const response = await fetchImpl(url, init);
      if (response.ok && response.body) {
        // `lastError` is returned even on success — it is the reason the walk
        // MOVED, and a failover whose cause is discarded is a failover nobody can
        // diagnose. The caller reads it only when no upstream answered at all.
        return { response, upstream, failed, lastError };
      }
      // A refused upstream's reason is worth keeping: `400 model not found`
      // from a rail that lacks the alias is the failure this list exists for.
      const detail = await response.text().catch(() => "");
      lastError = `Upstream returned ${response.status}${
        detail ? `: ${detail.slice(0, 300)}` : ""
      }`;
      failed.push({
        upstream: upstream.name,
        status: response.status,
        headers: response.headers,
        ...(detail ? { detail: detail.slice(0, 300) } : {}),
      });
    } catch (error) {
      lastError = error?.message ?? String(error);
      failed.push({ upstream: upstream.name, error: lastError });
    }
  }

  return { response: null, upstream: null, failed, lastError };
};
