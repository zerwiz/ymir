/**
 * constellation-contract.ts — the ONE agent-card contract, reached from a deployed
 * Pi extension.
 *
 * The types are imported from the shared contract
 * (`packages/contracts/src/agent-card.ts`) and never copied: a second definition
 * of an agent card is a second truth, and a card validated against a private
 * imitation is not validated at all. `import type` / `export type` are erased by
 * the runtime, so the type half costs nothing at load.
 *
 * The VALUES cannot be a relative import. The loader (`bin/valknut-load.sh`) copies
 * `.pi/shared/extensions/*.ts` and `.pi/extensions/lib/*` into ONE global pi
 * extension home (`${HOME}/.pi/agent/extensions/`), which has no `packages/` under
 * it: a deployed `../../../packages/...` would resolve to nothing and the extension
 * would fail to load at all. So the contract is located at RUNTIME through the root
 * the loader recorded in `.ymir-root` (`lib/ymir-home.ts`), with the in-tree path
 * tried first for a session that runs from the worktree. One contract either way.
 */
import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { resolveYmirRoot } from "../lib/ymir-home.ts";

import type {
  AgentCapabilities,
  AgentCard,
  AgentInterface,
  AgentSkill,
} from "../../../../packages/contracts/src/agent-card.ts";

export type { AgentCapabilities, AgentCard, AgentInterface, AgentSkill };

const here = dirname(fileURLToPath(import.meta.url));
// The recorded root sits beside the DEPLOYED extensions (their own dir), not in
// their lib/ — so resolve from `lib/..` exactly as the top-level extensions do.
const root = resolveYmirRoot(resolve(here, ".."));

const CONTRACT_CANDIDATES = [
  resolve(here, "../../../../packages/contracts/src/agent-card.ts"),
  resolve(root, "packages/contracts/src/agent-card.ts"),
];

const contractPath = CONTRACT_CANDIDATES.find((candidate) => existsSync(candidate));

if (!contractPath) {
  throw new Error(
    `constellation: the shared agent-card contract was not found. Looked in: ${CONTRACT_CANDIDATES.join(", ")}. ` +
      `The loader records the distro root beside the deployed extensions (bin/valknut-load.sh --pi); ` +
      `re-run it so the deployed copy knows where its tree is.`,
  );
}

const contract = await import(pathToFileURL(contractPath).href);

/** The wire protocol the fleet speaks (from the shared contract, never restated). */
export const A2A_PROTOCOL: string = contract.A2A_PROTOCOL;

/** Where an A2A card is served (from the shared contract, never restated). */
export const A2A_CARD_PATH: string = contract.A2A_CARD_PATH;

/** The contract's loud failure — it names the offending field. */
export const AgentCardContractError = contract.AgentCardContractError;

/** Validate an unknown value against the contract; throws naming the field. */
export const assertAgentCard = contract.assertAgentCard as (value: unknown) => void;

/** Non-throwing form of the contract's assertion. */
export const isAgentCard = contract.isAgentCard as (value: unknown) => boolean;
