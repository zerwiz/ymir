// index.ts — the package's public surface. One import path for both consumers:
// the A2A server (packages/a2a/ratatoskr) and Hlidskjalf (apps/hlidskjalf).
export {
  A2A_CARD_PATH,
  A2A_PROTOCOL,
  AgentCardContractError,
  assertAgentCard,
  buildAgentCard,
  isAgentCard,
} from "./agent-card.ts";
export type {
  AgentCapabilities,
  AgentCard,
  AgentCardSeed,
  AgentInterface,
  AgentSkill,
} from "./agent-card.ts";
