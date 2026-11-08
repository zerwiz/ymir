#!/usr/bin/env node
/**
 * probe-chat-widths — the width probe for the chat surface.
 *
 * It answers one question per width: which element's right edge crosses its
 * container, and which element's content is wider than its box. The answer is a
 * measurement taken by a real layout engine over the real `ChatPanel`, not a
 * screenshot somebody eyeballs.
 *
 * How it is put together:
 *
 *   1. the stylesheet is the shipping one — `src/renderer/src/index.css` compiled
 *      by Tailwind v4 exactly as the vite plugin compiles it (same compiler, same
 *      scanner, same source tree);
 *   2. the page is `scripts/probe/chat-surface.tsx` bundled by esbuild: the real
 *      component, the real store, seeded with `scripts/probe/fixtures.ts`;
 *   3. headless Chromium loads that page at a given `--window-size`, and
 *      `scripts/probe/measure.js` writes its findings as JSON into the DOM, which
 *      `--dump-dom` hands back.
 *
 * Usage:
 *   node scripts/probe-chat-widths.mjs                  # every case, human table
 *   node scripts/probe-chat-widths.mjs --json           # machine-readable
 *   node scripts/probe-chat-widths.mjs --width 800      # one window width
 *   node scripts/probe-chat-widths.mjs --pane 400       # a 400px pane in a 1400px window
 *
 * Exit codes: 0 when every case is clean (or the probe cannot run at all and says
 * why), 1 when any case reports an offender. A machine with no Chromium is a
 * clean skip, never a false green: the reason is printed and, in --json mode,
 * carried as `{ "status": "skip", "reason": "…" }`.
 */
import { spawnSync } from 'node:child_process'
import { existsSync } from 'node:fs'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const APP_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const DEFAULT_WINDOW_WIDTHS = [1280, 1024, 960, 800]
const PANE_WINDOW_WIDTH = 1400

function parseArgs(argv) {
  const args = { json: false, widths: [], panes: [], panels: [], keep: false }
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i]
    if (arg === '--json') args.json = true
    else if (arg === '--keep') args.keep = true
    else if (arg === '--width') args.widths.push(Number(argv[++i]))
    else if (arg === '--pane') args.panes.push(Number(argv[++i]))
    else if (arg === '--panel') args.panels.push(String(argv[++i]))
    else if (arg === '--help' || arg === '-h') args.help = true
    else throw new Error(`unknown argument: ${arg}`)
  }
  return args
}

const HELP = `probe-chat-widths — measure the chat layout at a given width

  --width <px>   a window width to measure (repeatable; default ${DEFAULT_WINDOW_WIDTHS.join(', ')})
  --pane <px>    a pane of that width inside a ${PANE_WINDOW_WIDTH}px window (repeatable)
  --panel <name> open a side panel: files | diff
  --json         print the findings as JSON
  --keep         keep the build directory for inspection
`

function findChromium() {
  const candidates = [
    process.env.CHROMIUM_BIN,
    'chromium',
    'chromium-browser',
    'google-chrome-stable',
    'google-chrome',
  ].filter(Boolean)
  for (const candidate of candidates) {
    const resolved = candidate.includes(path.sep)
      ? existsSync(candidate)
        ? candidate
        : null
      : spawnSync('sh', ['-c', `command -v ${candidate}`], { encoding: 'utf8' }).stdout.trim() || null
    if (resolved) return resolved
  }
  return null
}

function requireModule(name) {
  try {
    return spawnSync(
      process.execPath,
      ['-e', `require.resolve(${JSON.stringify(name)})`],
      { cwd: APP_DIR, encoding: 'utf8' }
    ).status === 0
  } catch {
    return false
  }
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: APP_DIR, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...options })
  if (result.error) throw result.error
  if (result.status !== 0) {
    const stderr = (result.stderr || '').trim()
    throw new Error(`${command} ${args.join(' ')} failed (${result.status}): ${stderr.slice(-2000)}`)
  }
  return result.stdout
}

/** The shipping stylesheet: the same compile the @tailwindcss/vite plugin runs. */
async function buildStylesheet(outFile) {
  const { compile } = await import('@tailwindcss/node')
  const { Scanner } = await import('@tailwindcss/oxide')
  const cssPath = path.join(APP_DIR, 'src/renderer/src/index.css')
  const source = await fs.readFile(cssPath, 'utf8')
  const compiler = await compile(source, {
    base: path.dirname(cssPath),
    shouldRewriteUrls: true,
    onDependency() {},
  })
  const scanner = new Scanner({
    sources: [{ base: path.join(APP_DIR, 'src'), pattern: '**/*', negated: false }],
  })
  const candidates = [...scanner.scan()]
  await fs.writeFile(outFile, compiler.build(candidates), 'utf8')
}

async function buildPage(outDir) {
  // esbuild ships with vite, so the probe needs no dependency the app does not
  // already have.
  const esbuildBin = path.join(APP_DIR, '..', '..', 'node_modules', '.bin', 'esbuild')
  const entry = path.join(APP_DIR, 'scripts/probe/chat-surface.tsx')
  const bundle = path.join(outDir, 'chat-surface.js')
  const bundler = existsSync(esbuildBin) ? esbuildBin : 'esbuild'
  run(bundler, [
    entry,
    '--bundle',
    '--format=iife',
    '--platform=browser',
    '--target=chrome120',
    '--define:process.env.NODE_ENV="production"',
    '--loader:.svg=text',
    '--loader:.woff2=file',
    '--loader:.woff=file',
    '--outfile=' + bundle,
    '--log-level=warning',
  ])
  const bundleCss = bundle.replace(/\.js$/, '.css')
  return { bundle, bundleCss: existsSync(bundleCss) ? bundleCss : null }
}

function readResult(dom) {
  const match = dom.match(/<pre id="probe-result"[^>]*>([\s\S]*?)<\/pre>/)
  if (!match) return { error: 'no result block in the rendered page' }
  const text = match[1]
    .trim()
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#39;/g, "'")
  if (!text) return { error: 'the page never wrote a result (it did not finish measuring)' }
  try {
    return JSON.parse(text)
  } catch (error) {
    return { error: `unreadable result: ${String(error)}` }
  }
}

function measureCase({ chromium, pageUrl, width, height, label }) {
  // A headless dump can beat the page's own measurement to the DOM under load, so
  // an empty result is retried rather than reported as a layout finding.
  let result = { error: 'not measured' }
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const stdout = run(chromium, [
      '--headless=new',
      '--no-sandbox',
      '--disable-gpu',
      '--force-device-scale-factor=1',
      '--window-size=' + width + ',' + height,
      '--virtual-time-budget=' + (4000 + attempt * 2000),
      '--dump-dom',
      pageUrl,
    ])
    result = readResult(stdout)
    if (!result.error) break
  }
  return { case: label, ...result }
}

function offendersOf(result) {
  if (!result || result.error) return 0
  return (result.crosses?.length ?? 0) + (result.wider?.length ?? 0) + (result.pageOverflow > 0 ? 1 : 0)
}

function printHuman(results) {
  for (const result of results) {
    if (result.error) {
      console.log(`${result.case}: ERROR ${result.error}`)
      continue
    }
    const verdict = offendersOf(result) === 0 ? 'clean' : 'OFFENDERS'
    const pane = result.rootWidth !== result.viewportWidth ? ` pane=${result.rootWidth}` : ''
    console.log(
      `${result.case}: viewport=${result.viewportWidth}${pane} pageOverflow=${result.pageOverflow} crosses=${result.crosses.length} wider=${result.wider.length} ${verdict}`
    )
    for (const item of result.crosses) {
      console.log(`  crosses  ${item.el}  (over ${item.over}px of ${item.clipWidth}px in ${item.clip})`)
    }
    for (const item of result.wider) {
      console.log(`  is-wider ${item.el}  (content ${item.over}px wider than ${item.clientWidth}px)`)
    }
    if (result.composer) {
      console.log(
        `  composer ${result.composer.width}px wide, ${result.composer.height}px tall, lines=${result.composer.lines}, textOverflow=${result.composer.textOverflow}`
      )
    }
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2))
  if (args.help) {
    process.stdout.write(HELP)
    return 0
  }

  const chromium = findChromium()
  if (!chromium) {
    const reason = 'no Chromium binary found (set CHROMIUM_BIN to one)'
    if (args.json) console.log(JSON.stringify({ status: 'skip', reason }))
    else console.log(`SKIP: ${reason}`)
    return 0
  }
  for (const required of ['@tailwindcss/node', '@tailwindcss/oxide', 'esbuild']) {
    if (!requireModule(required)) {
      const reason = `${required} is not installed — run npm install in apps/sessrumnir`
      if (args.json) console.log(JSON.stringify({ status: 'skip', reason }))
      else console.log(`SKIP: ${reason}`)
      return 0
    }
  }

  const outDir = await fs.mkdtemp(path.join(os.tmpdir(), 'sessrumnir-probe-'))
  let results
  try {
    const stylesheet = path.join(outDir, 'probe.css')
    await buildStylesheet(stylesheet)
    const { bundle, bundleCss } = await buildPage(outDir)
    const stubSource = await fs.readFile(path.join(APP_DIR, 'scripts/probe/window-stub.js'), 'utf8')
    const measureSource = await fs.readFile(path.join(APP_DIR, 'scripts/probe/measure.js'), 'utf8')
    const pagePath = path.join(outDir, 'probe.html')

    const page = `<!DOCTYPE html>
<html lang="en" class="dark">
  <head>
    <meta charset="UTF-8" />
    <title>Sessrúmnir — width probe</title>
    <link rel="stylesheet" href="${pathToFileURL(stylesheet).href}" />
    ${bundleCss ? `<link rel="stylesheet" href="${pathToFileURL(bundleCss).href}" />` : ''}
  </head>
  <body class="bg-app text-primary antialiased" style="margin:0">
    <div id="probe-root" style="display:flex; height:100vh; overflow:hidden"></div>
    <pre id="probe-result" style="display:none"></pre>
    <script>${stubSource}</script>
    <script src="${pathToFileURL(bundle).href}"></script>
    <script>${measureSource}</script>
  </body>
</html>
`
    await fs.writeFile(pagePath, page, 'utf8')

    const panels = args.panels.length ? args.panels : [null]
    const cases = []
    for (const panel of panels) {
      for (const width of args.widths.length ? args.widths : DEFAULT_WINDOW_WIDTHS) {
        cases.push({ label: `window ${width}${panel ? ` panel=${panel}` : ''}`, width, pane: null, panel })
      }
      for (const pane of args.panes) {
        cases.push({ label: `pane ${pane} in ${PANE_WINDOW_WIDTH}${panel ? ` panel=${panel}` : ''}`, width: PANE_WINDOW_WIDTH, pane, panel })
      }
    }

    results = cases.map((testCase) => {
      const query = []
      if (testCase.pane) query.push(`pane=${testCase.pane}`)
      if (testCase.panel) query.push(`panel=${testCase.panel}`)
      const url = pathToFileURL(pagePath).href + (query.length ? `?${query.join('&')}` : '')
      return measureCase({
        chromium,
        pageUrl: url,
        width: testCase.width,
        height: 900,
        label: testCase.label,
      })
    })
  } finally {
    if (!args.keep) await fs.rm(outDir, { recursive: true, force: true })
    else console.log(`build kept at ${outDir}`)
  }

  if (args.json) {
    console.log(JSON.stringify({ status: 'measured', results }, null, 2))
  } else {
    printHuman(results)
  }

  const failed = results.filter((result) => result.error || offendersOf(result) > 0)
  return failed.length === 0 ? 0 : 1
}

main().then(
  (code) => {
    process.exitCode = code
  },
  (error) => {
    console.error(error && error.stack ? error.stack : String(error))
    process.exitCode = 2
  }
)
