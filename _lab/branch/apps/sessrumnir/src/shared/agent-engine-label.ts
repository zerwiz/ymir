import type { AgentEngineKind } from './ipc-contracts'

/**
 * Display names for the two agent CLIs.
 *
 * Two names exist for each engine:
 *  - the NARRATIVE name the Allfather reads on conversational surfaces (status
 *    bar, empty chat, permission prompt, "is working" indicators, notifications).
 *    The agent is one figure — Brokk — whichever CLI carries the turn; the
 *    choice of executable is an implementation detail, not a character.
 *  - the TECHNICAL name for Diagnostics and Settings, where the literal
 *    executable (Pi / OMP) is a machine fact and must be quoted exactly.
 *
 * Shared by both processes because several surfaces name the running agent —
 * the status bar, the empty chat state, the session row tags, and the
 * permission prompt the agent itself raises — and they must agree.
 */
const AGENT_ENGINE_LABELS: Record<AgentEngineKind, string> = {
  pi: 'Brokk',
  omp: 'Brokk',
}

const AGENT_ENGINE_NAMES: Record<AgentEngineKind, string> = {
  pi: 'Pi',
  omp: 'OMP',
}

/**
 * Fallback for a caller that must render something. Used where the engine is
 * not yet known but a name is unavoidable, such as a permission prompt raised
 * before the GUI told the extension which engine it belongs to.
 */
export const DEFAULT_AGENT_ENGINE_LABEL = AGENT_ENGINE_LABELS.pi

/** Fallback technical name for Diagnostics/Settings when the engine is unknown. */
export const DEFAULT_AGENT_ENGINE_NAME = AGENT_ENGINE_NAMES.pi

/**
 * The narrative display name for an engine, or null when the engine is unknown.
 * Callers that must render something choose their own fallback; callers that tag
 * rows show nothing rather than guess.
 */
export function agentEngineLabel(engine: AgentEngineKind | null | undefined): string | null {
  return engine ? AGENT_ENGINE_LABELS[engine] : null
}

/**
 * The literal CLI name (Pi / OMP) for Diagnostics and Settings, or null when the
 * engine is unknown. These surfaces quote the executable as a fact.
 */
export function agentEngineName(engine: AgentEngineKind | null | undefined): string | null {
  return engine ? AGENT_ENGINE_NAMES[engine] : null
}
