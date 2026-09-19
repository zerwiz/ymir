import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
  DEFAULT_AGENT_ENGINE_LABEL,
  DEFAULT_AGENT_ENGINE_NAME,
  agentEngineLabel,
  agentEngineName,
} from './agent-engine-label'

/**
 * The status bar named "Pi" while OMP was the configured engine, because the
 * label came from a store default that only a running agent ever corrected.
 * Every surface that names the agent now reads this one map.
 *
 * Two names live here: the narrative name the Allfather reads (Brokk, for either
 * engine) and the technical CLI name (Pi / OMP) that Diagnostics and Settings
 * quote as fact.
 */

test('both engines read as the one narrative agent', () => {
  assert.equal(agentEngineLabel('pi'), 'Brokk')
  assert.equal(agentEngineLabel('omp'), 'Brokk')
})

test('the technical name keeps each CLI literal', () => {
  assert.equal(agentEngineName('pi'), 'Pi')
  assert.equal(agentEngineName('omp'), 'OMP')
})

test('an unknown engine has no name, so callers choose their own fallback', () => {
  // Session rows show nothing rather than guess; the status bar falls back to
  // the default. Returning a name here would tag rows with the wrong CLI.
  assert.equal(agentEngineLabel(null), null)
  assert.equal(agentEngineLabel(undefined), null)
  assert.equal(agentEngineName(null), null)
  assert.equal(agentEngineName(undefined), null)
})

test('the fallbacks are real names, not placeholders', () => {
  // The permission extension renders the narrative fallback when the GUI told it nothing.
  assert.equal(DEFAULT_AGENT_ENGINE_LABEL, 'Brokk')
  assert.equal(DEFAULT_AGENT_ENGINE_NAME, 'Pi')
  assert.equal(agentEngineLabel('pi'), DEFAULT_AGENT_ENGINE_LABEL)
  assert.equal(agentEngineName('pi'), DEFAULT_AGENT_ENGINE_NAME)
})
