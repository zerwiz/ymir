// agent-card.ts — the A2A 1.0 agent-card contract: ONE typed surface, two
// consumers. The A2A server (packages/a2a/ratatoskr) builds the card it serves
// at /.well-known/agent-card.json through this module; Hlidskjalf
// (apps/hlidskjalf) names the same A2A binding on its fleet cards. The wire is
// A2A 1.0 (JSON-RPC 2.0 task lifecycle).
//
// This module is plain TypeScript with no dependencies: it type-checks into both
// consumers and runs under node, bun, and the browser bundle alike. The runtime
// half is a validator that fails LOUDLY and names the offending field — a card
// that leaves the shape must never be served in silence.
//
// References: plan 27 (Hermóðr MCP/A2A composition), plan 25/26 (Ratatoskr).

/** The protocol name the fleet speaks (A2A 1.0). */
export const A2A_PROTOCOL = "a2a/1.0";

/** The well-known path an A2A agent card is served at. */
export const A2A_CARD_PATH = "/.well-known/agent-card.json";

export interface AgentCapabilities {
  streaming?: boolean;
  pushNotifications?: boolean;
  stateTransitionHistory?: boolean;
}

/** An A2A skill: a named capability the agent advertises on its card. */
export interface AgentSkill {
  id: string;
  name: string;
  description?: string;
  tags?: string[];
  examples?: string[];
  inputModes?: string[];
  outputModes?: string[];
}

/**
 * The portal's descriptor of an agent's A2A binding — the `interface` field of a
 * Hlidskjalf fleet card. It is deliberately the *addressing* half of the card:
 * the protocol name, the endpoint to reach, and whether the binding is signed.
 */
export interface AgentInterface {
  protocol: string;
  endpoint: string;
  signed: boolean;
}

/** The A2A 1.0 agent card served at {@link A2A_CARD_PATH}. */
export interface AgentCard {
  name: string;
  description: string;
  url: string;
  version: string;
  /** The wire protocol version; optional so an older seat's card still validates. */
  protocolVersion?: string;
  /** The protocol names the card advertises (the fleet's is {@link A2A_PROTOCOL}). */
  protocols?: string[];
  capabilities: AgentCapabilities;
  skills: AgentSkill[];
  defaultInputModes: string[];
  defaultOutputModes: string[];
  securitySchemes?: unknown;
  security?: unknown;
}

/** What a server must supply to build a card; the rest is contract default. */
export interface AgentCardSeed {
  name: string;
  description: string;
  url: string;
  version?: string;
  protocolVersion?: string;
  protocols?: string[];
  capabilities?: AgentCapabilities;
  skills: AgentSkill[];
  defaultInputModes?: string[];
  defaultOutputModes?: string[];
  securitySchemes?: unknown;
  security?: unknown;
}

/** A card that left the contract. The message names the field, always. */
export class AgentCardContractError extends Error {
  /** The dotted path of the offending field, e.g. `skills[0].id`. */
  readonly path: string;

  constructor(path: string, why: string) {
    super(`agent-card contract: ${path} ${why}`);
    this.name = "AgentCardContractError";
    this.path = path;
  }
}

function requireString(value: unknown, path: string): void {
  if (typeof value !== "string" || value.trim() === "") {
    throw new AgentCardContractError(path, "must be a non-empty string");
  }
}

function requireStringArray(value: unknown, path: string): void {
  if (!Array.isArray(value) || value.some((v) => typeof v !== "string")) {
    throw new AgentCardContractError(path, "must be an array of strings");
  }
}

function checkCapabilities(value: unknown, path: string): void {
  if (value === undefined) return;
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new AgentCardContractError(path, "must be an object of booleans");
  }
  const flags: readonly string[] = ["streaming", "pushNotifications", "stateTransitionHistory"];
  for (const flag of flags) {
    const v = (value as Record<string, unknown>)[flag];
    if (v !== undefined && typeof v !== "boolean") {
      throw new AgentCardContractError(`${path}.${flag}`, "must be a boolean");
    }
  }
}

function checkSkill(value: unknown, path: string): void {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new AgentCardContractError(path, "must be an object with id and name");
  }
  const skill = value as Record<string, unknown>;
  requireString(skill.id, `${path}.id`);
  requireString(skill.name, `${path}.name`);
  if (skill.description !== undefined) requireString(skill.description, `${path}.description`);
  for (const field of ["tags", "examples", "inputModes", "outputModes"] as const) {
    if (skill[field] !== undefined) requireStringArray(skill[field], `${path}.${field}`);
  }
}

/**
 * Validate an unknown value against the contract. Throws
 * {@link AgentCardContractError} naming the first offending field; returns
 * normally (asserting the type) when the card is sound.
 */
export function assertAgentCard(value: unknown): asserts value is AgentCard {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new AgentCardContractError("<card>", "must be an object");
  }
  const card = value as Record<string, unknown>;
  requireString(card.name, "name");
  requireString(card.description, "description");
  requireString(card.url, "url");
  requireString(card.version, "version");
  if (card.protocolVersion !== undefined) requireString(card.protocolVersion, "protocolVersion");
  if (card.protocols !== undefined) requireStringArray(card.protocols, "protocols");
  checkCapabilities(card.capabilities, "capabilities");
  if (!Array.isArray(card.skills)) {
    throw new AgentCardContractError("skills", "must be an array of skills");
  }
  card.skills.forEach((skill, i) => checkSkill(skill, `skills[${i}]`));
  requireStringArray(card.defaultInputModes, "defaultInputModes");
  requireStringArray(card.defaultOutputModes, "defaultOutputModes");
}

/** Non-throwing form of {@link assertAgentCard}. */
export function isAgentCard(value: unknown): value is AgentCard {
  try {
    assertAgentCard(value);
    return true;
  } catch {
    return false;
  }
}

/**
 * Build a card from a seed, applying the contract's defaults, then validate it
 * before returning. A seed that leaves the contract throws here — at the
 * server's door, loudly, never on the wire.
 */
export function buildAgentCard(seed: AgentCardSeed): AgentCard {
  const card: AgentCard = {
    name: seed.name,
    description: seed.description,
    url: seed.url,
    version: seed.version ?? "1.0.0",
    protocolVersion: seed.protocolVersion,
    protocols: seed.protocols ?? [A2A_PROTOCOL],
    capabilities: seed.capabilities ?? {
      streaming: true,
      pushNotifications: false,
      stateTransitionHistory: false,
    },
    skills: seed.skills.map((skill) => ({ ...skill })),
    defaultInputModes: seed.defaultInputModes ?? ["text"],
    defaultOutputModes: seed.defaultOutputModes ?? ["text"],
    securitySchemes: seed.securitySchemes ?? {},
    security: seed.security ?? [],
  };
  assertAgentCard(card);
  return card;
}
