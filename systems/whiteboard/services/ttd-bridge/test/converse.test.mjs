import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  DEFAULT_CONVERSE_PROMPT,
  DEFAULT_SYSTEM_PROMPT,
  buildUpstreamRequest,
  readConfig,
  withSystemPrompt,
} from "../bridge.mjs";
import { ALLOWED_TOOL_NAMES, BOARD_TOOLS, narrowToAllowed, toolsFor } from "../tools.mjs";
import {
  clockOf,
  explainFailure,
  humanDuration,
  isUsageLimit,
  parseDuration,
  resetAt,
  usageLimitSentence,
} from "../usage-limit.mjs";

describe("the two modes are two prompts", () => {
  it("generate keeps the bare-Mermaid contract, word for word", () => {
    assert.match(DEFAULT_SYSTEM_PROMPT, /Reply with the Mermaid source ONLY/);
    assert.match(DEFAULT_SYSTEM_PROMPT, /no code/);
  });

  it("converse asks before it draws, and never asks more than two questions", () => {
    assert.match(DEFAULT_CONVERSE_PROMPT, /AT MOST TWO/);
    assert.match(DEFAULT_CONVERSE_PROMPT, /ask before you draw/i);
    assert.doesNotMatch(DEFAULT_CONVERSE_PROMPT, /Reply with the Mermaid source ONLY/);
  });

  it("the two prompts say opposite things about Mermaid", () => {
    assert.match(DEFAULT_SYSTEM_PROMPT, /Mermaid/);
    assert.match(DEFAULT_CONVERSE_PROMPT, /Do not reply with Mermaid/);
  });

  it("a caller's system message is never doubled", () => {
    const messages = [{ role: "system", content: "mine" }, { role: "user", content: "hi" }];
    assert.deepEqual(withSystemPrompt(messages, DEFAULT_CONVERSE_PROMPT), messages);
  });
});

describe("tools — the whiteboard's own, and nothing else", () => {
  it("holds exactly the permitted surface", () => {
    assert.deepEqual([...ALLOWED_TOOL_NAMES].sort(), [
      "add_elements",
      "focus",
      "read_canvas",
      "save_room",
      "share_room",
      "update_elements",
      "validate_diagram",
    ]);
  });

  it("gives no tool to generate, ever", () => {
    assert.deepEqual(toolsFor("generate"), []);
  });

  it("gives the board tools to converse", () => {
    assert.equal(toolsFor("converse").length, BOARD_TOOLS.length);
  });

  it("refuses a house tool a client tries to add", () => {
    const narrowed = narrowToAllowed(["read_canvas", "lookup_record", "web_search"]);
    assert.deepEqual(narrowed.map((tool) => tool.function.name), ["read_canvas"]);
    assert.equal(narrowToAllowed(["web_search"]), null);
  });

  it("never carries a reach for the hall, the ledger, mail or the web", () => {
    const text = JSON.stringify(BOARD_TOOLS).toLowerCase();
    for (const forbidden of ["web_search", "lookup_record", "invite_person", "http://", "https://"]) {
      assert.equal(text.includes(forbidden), false, forbidden);
    }
  });

  it("says, in the tool text, that the person's own strokes are immutable", () => {
    const update = BOARD_TOOLS.find((tool) => tool.function.name === "update_elements");
    assert.match(update.function.description, /same turn/i);
    assert.match(update.function.description, /Never an element the person drew/);
  });
});

describe("the wall is shown, with a time", () => {
  it("reads the durations rails write", () => {
    assert.equal(parseDuration("30"), 30_000);
    assert.equal(parseDuration("1m30s"), 90_000);
    assert.equal(parseDuration("6m0s"), 360_000);
    assert.equal(parseDuration("2h"), 7_200_000);
    assert.equal(parseDuration("250ms"), 250);
    assert.equal(parseDuration("later"), null);
  });

  it("speaks a duration as a person would", () => {
    assert.equal(humanDuration(0), "under a minute");
    assert.equal(humanDuration(90_000), "2 minutes");
    assert.equal(humanDuration(3_600_000), "1 hour");
    assert.equal(humanDuration(8_100_000), "2 hours 15 minutes");
  });

  it("recognises a usage limit wearing a 429, and one wearing another status", () => {
    assert.equal(isUsageLimit({ status: 429 }), true);
    assert.equal(isUsageLimit({ status: 403, detail: "current quota exceeded" }), true);
    assert.equal(isUsageLimit({ status: 400, detail: 'model "x" not found' }), false);
  });

  it("takes the reset time from a header, in seconds or in a spelled duration", () => {
    const now = 1_700_000_000_000;
    assert.equal(resetAt({ headers: { "retry-after": "120" } }, now), now + 120_000);
    assert.equal(
      resetAt({ headers: { "x-ratelimit-reset-requests": "1h2m" } }, now),
      now + 3_720_000,
    );
  });

  it("takes the reset time from the rail's own words when there is no header", () => {
    const now = 1_700_000_000_000;
    assert.equal(
      resetAt({ detail: "Rate limit reached. Please try again in 6m0s." }, now),
      now + 360_000,
    );
  });

  it("says the wall and the time, never a bare status code", () => {
    const now = 1_700_000_000_000;
    const sentence = usageLimitSentence(
      { status: 429, headers: { "retry-after": "8100" } },
      now,
    );
    assert.match(sentence, /usage limit is reached/);
    assert.match(sentence, /2 hours 15 minutes/);
    assert.match(sentence, /ask again after that/);
    assert.doesNotMatch(sentence, /429/);
  });

  it("admits when the rail did not say when it resets", () => {
    const sentence = usageLimitSentence({ status: 429 }, 1_700_000_000_000);
    assert.match(sentence, /did not say when it resets/);
  });

  it("keeps a plain fault plain", () => {
    const explained = explainFailure({ status: 500, message: "Upstream returned 500: boom" });
    assert.equal(explained.kind, "error");
    assert.match(explained.message, /500/);
  });

  it("formats a clock time for the reader", () => {
    const at = new Date();
    at.setHours(2, 25, 0, 0);
    assert.equal(clockOf(at.getTime()), "02:25");
  });
});

describe("the upstream request", () => {
  const base = { baseURL: "http://127.0.0.1:9/v1", model: "m", apiKey: "" };

  it("carries no tools when none are offered — the generate contract", () => {
    const { init } = buildUpstreamRequest(base, { messages: [{ role: "user", content: "x" }] });
    const body = JSON.parse(init.body);
    assert.equal(body.tools, undefined);
    assert.equal(body.tool_choice, undefined);
    assert.equal(body.stream, true);
  });

  it("carries the board's tools when converse offers them", () => {
    const { init } = buildUpstreamRequest(base, {
      messages: [{ role: "user", content: "x" }],
      tools: toolsFor("converse"),
    });
    const body = JSON.parse(init.body);
    assert.equal(body.tool_choice, "auto");
    assert.equal(body.tools.length, BOARD_TOOLS.length);
  });
});

describe("configuration", () => {
  it("defaults converse to the plain-words prompt and lets an operator override it", () => {
    assert.equal(readConfig({}).conversePrompt, DEFAULT_CONVERSE_PROMPT);
    assert.equal(
      readConfig({ TTD_CONVERSE_PROMPT: "be terse" }).conversePrompt,
      "be terse",
    );
  });
});
