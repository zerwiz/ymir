/**
 * The chat's layout, asserted at four widths — the test that plan 222 asks for.
 *
 * It is not a unit test of a number: it drives `scripts/probe-chat-widths.mjs`,
 * which renders the shipping `ChatPanel` in headless Chromium over the shipping
 * stylesheet and reports which element's right edge crosses its container. Every
 * width here is a case somebody actually uses — a full window, two thirds, half,
 * and half of a half — plus a 400 px pane inside a 1400 px window, which is what
 * a chat beside a second app looks like.
 *
 * The probe needs a Chromium binary and the app's dev dependencies. Where either
 * is absent the cases SKIP with the reason rather than passing quietly: a green
 * that stands in for a capability that never ran is the false green this house
 * has paid for twice (RULES/25).
 */
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { test } from 'node:test'
import { MIN_CHAT_CENTER_WIDTH } from './chat-panel-widths'

const APP_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..')
const PROBE = path.join(APP_ROOT, 'scripts/probe-chat-widths.mjs')

interface ProbeBox {
  el: string
  width: number
  right: number
  scrollWidth: number
}

interface ProbeResult {
  case: string
  settled?: boolean
  error?: string
  pageErrors?: string[]
  viewportWidth: number
  rootWidth: number
  paneWidth: number | null
  pageOverflow: number
  boxes: ProbeBox[]
  crosses: Array<{ el: string; clip: string; over: number; width: number; clipWidth: number }>
  wider: Array<{ el: string; over: number; clientWidth: number }>
  prose: { width: number; lines: number | null; contentOverflow: number } | null
  code: { width: number; contentWidth: number; scrolls: boolean } | null
  panel: { drawn: boolean; fit: string | null; width: number; says: string | null }
  composer: {
    width: number
    height: number
    lines: number | null
    textOverflow: number | null
    parts: Array<{ el: string; width: number; height: number; contentOverflow: number }>
  } | null
}

interface ProbeRun {
  status: 'measured' | 'skip'
  reason?: string
  results?: ProbeResult[]
}

function runProbe(args: string[]): ProbeRun {
  // Exit code 1 is a finding, not a broken probe: the JSON is what this reads.
  const run = spawnSync(process.execPath, [PROBE, '--json', ...args], {
    cwd: APP_ROOT,
    encoding: 'utf8',
    timeout: 15 * 60 * 1000,
    maxBuffer: 64 * 1024 * 1024,
  })
  const stdout = run.stdout ?? ''
  const start = stdout.indexOf('{')
  assert.ok(start >= 0, `the probe printed no result:\n${stdout.slice(0, 2000)}\n${run.stderr ?? ''}`)
  const parsed = JSON.parse(stdout.slice(start)) as ProbeRun
  if (parsed.status === 'measured') {
    for (const result of parsed.results ?? []) {
      assert.notEqual(
        result.settled,
        false,
        `${result.case}: the page never settled, so the reading is not trustworthy`
      )
    }
  }
  return parsed
}

/** Every window width the plan names, in one browser session each. */
const WINDOWS = runProbe([])
/** A 400 px chat in a 1400 px window — a pane, not a window. */
const PANE = runProbe(['--pane', '400'])
/** The file tree open in a half-screen window, and in a 400 px pane. */
const PANEL = runProbe(['--width', '800', '--pane', '400', '--panel', 'files'])
/** A file tree BESIDE a preview: two panes, so the panel wants 600 px at 800. */
const SHRUNK = runProbe(['--width', '800', '--panel', 'image'])

function resultFor(run: ProbeRun, match: (result: ProbeResult) => boolean): ProbeResult {
  const found = run.results?.find(match)
  assert.ok(found, 'the probe did not measure the case this test names')
  return found
}

function assertNothingOverflows(result: ProbeResult): void {
  assert.equal(result.error, undefined, `${result.case}: ${result.error}`)
  assert.deepEqual(result.pageErrors ?? [], [], `${result.case}: the page threw while rendering`)
  assert.deepEqual(
    result.crosses.map((item) => `${item.el} over ${item.over}px`),
    [],
    `${result.case}: an element's right edge crosses its container`
  )
  assert.deepEqual(
    result.wider.map((item) => `${item.el} content ${item.over}px wider`),
    [],
    `${result.case}: content is wider than the box that should have wrapped it`
  )
  assert.equal(result.pageOverflow, 0, `${result.case}: the page scrolls sideways`)
}

function assertProseWraps(result: ProbeResult): void {
  assert.ok(result.prose, `${result.case}: no prose in the measured chat`)
  assert.equal(result.prose.contentOverflow, 0, `${result.case}: the prose is cut off, not wrapped`)
  assert.ok(
    (result.prose.lines ?? 0) > 1,
    `${result.case}: the paragraph did not wrap at all (${result.prose.lines} line)`
  )
  assert.ok(
    result.prose.width <= result.rootWidth,
    `${result.case}: the prose is wider than its pane`
  )
}

function skipUnlessMeasured(run: ProbeRun): string | false {
  if (run.status === 'measured') return false
  return run.reason ?? 'the width probe could not run here'
}

for (const width of [1280, 1024, 960, 800]) {
  test(`the chat fits a ${width}px window with no horizontal overflow`, {
    skip: skipUnlessMeasured(WINDOWS),
  }, () => {
    const result = resultFor(WINDOWS, (item) => item.viewportWidth === width)
    assertNothingOverflows(result)
    assertProseWraps(result)
  })
}

test('a code block scrolls inside itself while the prose beside it wraps', {
  skip: skipUnlessMeasured(WINDOWS),
}, () => {
  const result = resultFor(WINDOWS, (item) => item.viewportWidth === 800)
  assert.ok(result.code, 'no code block in the measured chat')
  // The block is allowed to be wider than its box — that is what scrolling is —
  // and the paragraph above it still wraps inside the same column.
  assert.ok(result.code.contentWidth > result.code.width, 'the code block did not overflow its box')
  assert.equal(result.code.scrolls, true, 'the code block does not scroll inside itself')
  assertProseWraps(result)
})

test('a 400px chat pane in a 1400px window keeps a one-line composer', {
  skip: skipUnlessMeasured(PANE),
}, () => {
  const result = resultFor(PANE, (item) => item.paneWidth === 400)
  assertNothingOverflows(result)
  assertProseWraps(result)
  assert.ok(result.composer, 'no composer in the measured chat')
  const { composer } = result
  // "One line" read off the parts: the composer is no taller than the rows it is
  // made of, so nothing wrapped and no row grew a second line.
  const partsHeight = composer.parts.reduce((sum, part) => sum + part.height, 0)
  assert.ok(
    composer.height <= partsHeight + 4,
    `the composer wrapped: ${composer.height}px for ${partsHeight}px of rows`
  )
  assert.ok(composer.parts.length >= 2, 'the composer lost its input or its actions')
  for (const part of composer.parts) {
    assert.equal(part.contentOverflow, 0, `${part.el} overflows the composer by ${part.contentOverflow}px`)
  }
  // The pane really was narrow: this test is worthless if the chat took the whole
  // 1400px window instead.
  assert.equal(result.rootWidth, 400)
})

test('the side panel gives way to the chat and says which way it went', {
  skip: skipUnlessMeasured(PANEL),
}, () => {
  const result = resultFor(PANEL, (item) => item.viewportWidth === 800)
  assertNothingOverflows(result)
  assert.equal(result.panel.drawn, true, 'the file tree panel is not drawn at 800px')
  assert.ok(
    result.panel.width + MIN_CHAT_CENTER_WIDTH <= result.viewportWidth,
    `panel ${result.panel.width}px plus the chat's ${MIN_CHAT_CENTER_WIDTH}px floor exceeds ${result.viewportWidth}px`
  )
})

test('a panel that cannot have the width it asked for shrinks and says so', {
  skip: skipUnlessMeasured(SHRUNK),
}, () => {
  const result = resultFor(SHRUNK, (item) => item.viewportWidth === 800)
  assertNothingOverflows(result)
  assertProseWraps(result)
  assert.equal(result.panel.drawn, true, 'a panel that could still fit was closed')
  assert.equal(result.panel.fit, 'shrunk', `the panel reported ${result.panel.fit}, not a shrink`)
  assert.ok(result.panel.says, 'the panel shrank without saying so')
  assert.ok(
    result.panel.width + MIN_CHAT_CENTER_WIDTH <= result.viewportWidth,
    `panel ${result.panel.width}px plus the chat's floor exceeds ${result.viewportWidth}px`
  )
})

test('a pane too narrow for both closes the panel and says so', {
  skip: skipUnlessMeasured(PANEL),
}, () => {
  const result = resultFor(PANEL, (item) => item.paneWidth === 400)
  assertNothingOverflows(result)
  assert.equal(result.panel.drawn, false, 'the panel was drawn with no room for the chat')
  assert.ok(result.panel.says, 'the panel closed without saying so')
  assertProseWraps(result)
})
