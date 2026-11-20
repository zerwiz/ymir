import { test } from "node:test";
import assert from "node:assert/strict";

import {
  A2A_PROTOCOL,
  AgentCardContractError,
  assertAgentCard,
  buildAgentCard,
  isAgentCard,
} from "../src/index.ts";
import { heartCard } from "../../a2a/ratatoskr/card.ts";

const seed = {
  name: "test-agent",
  description: "a test card",
  url: "http://127.0.0.1:8301/",
  skills: [{ id: "recall", name: "recall", description: "recall" }],
};

test("buildAgentCard fills the contract defaults", () => {
  const card = buildAgentCard(seed);
  assert.equal(card.version, "1.0.0");
  assert.deepEqual(card.protocols, [A2A_PROTOCOL]);
  assert.deepEqual(card.defaultInputModes, ["text"]);
  assert.deepEqual(card.defaultOutputModes, ["text"]);
  assert.equal(isAgentCard(card), true);
});

test("assertAgentCard accepts a sound card", () => {
  assert.doesNotThrow(() => assertAgentCard(buildAgentCard(seed)));
});

test("the served heart card passes the contract", () => {
  const card = heartCard("http://127.0.0.1:8301/");
  assert.doesNotThrow(() => assertAgentCard(card));
  assert.ok(card.skills.some((skill) => skill.id === "well-recall"));
});

// A deliberately mismatched card must be REFUSED, and the refusal must name the
// offending field — the contract's whole reason for a runtime half.
function refusal(mutate: (card: Record<string, unknown>) => void): string {
  const card = buildAgentCard({
    ...seed,
    skills: seed.skills.map((skill) => ({ ...skill })),
  }) as unknown as Record<string, unknown>;
  mutate(card);
  assert.equal(isAgentCard(card), false, "a mismatched card must not validate");
  try {
    assertAgentCard(card);
  } catch (error) {
    assert.ok(error instanceof AgentCardContractError, "the refusal must be the contract's error");
    return (error as AgentCardContractError).message;
  }
  return assert.fail("a mismatched card must be refused");
}

test("a deliberately mismatched card fails loudly, naming the field", () => {
  assert.match(refusal((card) => void delete card.name), /name must be a non-empty string/);
  assert.match(
    refusal((card) => void ((card.skills as Record<string, unknown>[])[0].id = "")),
    /skills\[0\]\.id must be a non-empty string/,
  );
  assert.match(
    refusal((card) => void ((card.capabilities as Record<string, unknown>).streaming = "yes")),
    /capabilities\.streaming must be a boolean/,
  );
  assert.match(
    refusal((card) => void (card.defaultInputModes = "text")),
    /defaultInputModes must be an array of strings/,
  );
  assert.match(refusal((card) => void (card.skills = "none")), /skills must be an array of skills/);
});
