/**
 * The chat the width probe measures.
 *
 * These are ordinary messages of the shape the engine delivers, not a picture of
 * one: prose that must wrap, a single unbroken token that cannot wrap on its own,
 * a table, and a fenced code block whose lines are wider than any pane. Each is
 * here because it is one of the ways content sets a floor a pane cannot shrink
 * under — which is the whole thing the probe exists to catch.
 */
import type { DisplayMessage } from '../../src/renderer/src/message-parsing'

/** An identifier no browser will break: the classic reason a pane stops shrinking. */
export const UNBREAKABLE_TOKEN =
  'resolveSidePanelMetricsWithTheContainerWidthSoTheBoundsAreInputsAndNotConstants'

const NOW = 1_760_000_000_000

const PROSE = [
  'The chat column is half a screen wide here, and a sentence that leaves the right edge is a sentence he cannot read.',
  'So this paragraph is deliberately ordinary: it says one thing, then another, and asks nothing of the reader.',
  `Then comes the word that has no spaces in it at all — ${UNBREAKABLE_TOKEN} — which a pane must be allowed to break rather than grow for.`,
  'After it the prose returns to its senses and keeps going for a line or two so the wrap has somewhere to happen.',
].join(' ')

const TABLE = [
  '| pane | floor | grows with |',
  '| --- | --- | --- |',
  '| chat center | the column | the window |',
  '| file tree | MIN_FILE_PANE_WIDTH | the side panel |',
  '| editor | MIN_EDITOR_PANE_WIDTH | the side panel |',
].join('\n')

const CODE = [
  '```ts',
  'export function resolveSidePanelMetrics(panes: SidePanelPanes, sidePanelWidth: number, filePaneWidth: number, availableWidth?: number): SidePanelMetrics {',
  '  const maxSidePanelWidth = availableWidth !== undefined && availableWidth > 0 ? Math.min(MAX_SIDE_PANEL_WIDTH, availableWidth) : MAX_SIDE_PANEL_WIDTH',
  '  return { fileTreeOnly: false, minSidePanelWidth, contentWidth: sidePanelWidth, filePaneWidth, maxFilePaneWidth }',
  '}',
  '```',
].join('\n')

export const PROBE_MESSAGES: DisplayMessage[] = [
  {
    id: 'probe-user-1',
    role: 'user',
    content: 'Why is the text running off the right edge of this window?',
    timestamp: NOW - 60_000,
  },
  {
    id: 'probe-assistant-1',
    role: 'assistant',
    content: [PROSE, '', TABLE, '', CODE].join('\n'),
    timestamp: NOW - 30_000,
    provider: 'llama-swap',
    model: 'qwen3.6-35b-a3b',
  },
]

