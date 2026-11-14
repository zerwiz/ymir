#!/usr/bin/env node
// cdp.mjs — the DevTools driver behind bin/gates/soak.sh (plan 286 P1, P2, P5).
//
// It speaks Chrome DevTools Protocol to one app's window over its fixed loopback port,
// measures the app's whole process tree from /proc, drives every page of the app N times,
// idles, samples, and judges the numbers against plan 286 section 5. Every measurement is
// one JSON row appended to the ledger the caller names; when something grows past budget
// it names the cause: the allocating call sites from a sampling heap profile, the hottest
// functions from a 10 s CPU profile, and the artifacts (a .heapsnapshot, the profiles).
//
// Three modes, one measurement implementation:
//   --measure-pid <pid>   print one JSON row describing a process tree (used for servers)
//   --judge-only          judge a ledger's existing rows and print the verdict
//   (default)             soak an app: baseline → pages × N → idle → samples → judge
//
// Node's own WebSocket and fetch are used: no dependency is added to the house for this.
import * as fs from 'node:fs'
import net from 'node:net'
import crypto from 'node:crypto'
import { readFileSync, readdirSync, existsSync, mkdirSync, appendFileSync, statSync, openSync, writeSync, closeSync, readlinkSync, rmSync } from 'node:fs'
import { execFileSync } from 'node:child_process'

// ── args ────────────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2)
const arg = (name, dflt = null) => {
  const i = argv.indexOf(`--${name}`)
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : dflt
}
const flag = (name) => argv.includes(`--${name}`)
const num = (name, dflt) => {
  const v = arg(name)
  return v === null || v === '' ? dflt : Number(v)
}

const MODE = arg('kill-tree') ? 'kill' : arg('measure-pid') ? 'measure' : flag('judge-only') ? 'judge' : 'soak'
const APP = arg('app', 'app')
const PORT = num('port', 0)
const PID0 = MODE === 'measure' ? num('measure-pid', 0) : num('pid', 0)
const LEDGER = arg('ledger', '')
const ROUTES = String(arg('routes', '') || '').split(',').map((s) => s.trim()).filter(Boolean)
const CYCLES = num('cycles', 20)
const IDLE = num('idle', 1800)
const SAMPLE = num('sample', 30)
const SETTLE = num('settle', 900)
const ARTIFACTS = arg('artifacts-dir', '')
// One ledger per app per day holds every soak of that day; a run id keeps a judge to the
// rows of ITS OWN soak, so yesterday's 1.5 GB cannot make today's pass look flat — or the
// reverse. Set by the door; absent means "judge the whole file" (--judge-only by hand).
const RUN = arg('run', '')
const CPU_STATE = arg('cpu-state', '')
const SNAPSHOT = arg('snapshot', 'on-breach')
const NO_ARTIFACTS = num('no-artifacts', 0) === 1
const JSON_OUT = flag('json')
const VERBOSE = flag('verbose')

const B = {
  rssIdlePct: num('b-rss-idle', 5),
  rssCyclePct: num('b-rss-cycle', 10),
  heapIdleMb: num('b-heap-idle', 2),
  heapCycleMb: num('b-heap-cycle', 5),
  fdsDelta: num('b-fds', 2),
  watchesDelta: num('b-watches', 2),
  childrenDelta: num('b-children', 0),
  longtaskIdleMs: num('b-longtask-idle', 200),
  longtaskCycleMs: num('b-longtask-cycle', 1000),
  dialogs: num('b-dialogs', 0),
  // Not in plan 286 §5: the boot budgets that make P1's proof bite. Measured on this
  // machine (plan 275, 02:50): the unfixed Sessrúmnir ran its main thread at 100 % for
  // 43 s and reached 1.5 GB before answering; the fixed one idles at 8 % and 259 MB.
  bootCpuPct: num('b-boot-cpu', 90),
  bootRssMb: num('b-boot-rss', 900),
}

const nowIso = () => new Date().toISOString().replace(/\.\d+Z$/, 'Z')
const say = (...a) => { if (!JSON_OUT) console.log(...a) }
const verbose = (...a) => { if (VERBOSE && !JSON_OUT) console.log(...a) }

// ── /proc measurement: one implementation for apps and servers ─────────────────
const CLOCK_TICKS = 100 // Linux USER_HZ

function readStatus(pid) {
  try {
    const s = readFileSync(`/proc/${pid}/status`, 'utf8')
    const g = (k) => {
      const m = s.match(new RegExp(`^${k}:\\s+(\\d+)\\s+kB`, 'm'))
      return m ? Number(m[1]) : 0
    }
    const state = (s.match(/^State:\s+(\S)/m) || [])[1] || ''
    return { rssKb: g('VmRSS'), hwmKb: g('VmHWM'), threads: Number((s.match(/^Threads:\s+(\d+)/m) || [])[1] || 1), state }
  } catch { return { rssKb: 0, hwmKb: 0, threads: 0, state: '' } }
}

function childrenOf(pid) {
  const out = []
  try {
    for (const t of readdirSync(`/proc/${pid}/task`)) {
      try {
        const s = readFileSync(`/proc/${pid}/task/${t}/children`, 'utf8').trim()
        if (s) out.push(...s.split(/\s+/).map(Number))
      } catch { /* a thread that vanished */ }
    }
  } catch { /* a process that vanished */ }
  return out
}

function tree(root) {
  const seen = new Set()
  const queue = root ? [root] : []
  while (queue.length) {
    const p = queue.shift()
    if (!p || seen.has(p)) continue
    seen.add(p)
    for (const c of childrenOf(p)) if (!seen.has(c)) queue.push(c)
  }
  return [...seen]
}

function statOf(pid) {
  try {
    const s = readFileSync(`/proc/${pid}/stat`, 'utf8')
    // comm may carry spaces and parentheses: split after the last ')'
    const rest = s.slice(s.lastIndexOf(')') + 2).split(' ')
    return { state: rest[0], utime: Number(rest[11]), stime: Number(rest[12]), cutime: Number(rest[13]), cstime: Number(rest[14]) }
  } catch { return null }
}

function inotifyWatches(pid) {
  let n = 0
  try {
    for (const fd of readdirSync(`/proc/${pid}/fdinfo`)) {
      try {
        const info = readFileSync(`/proc/${pid}/fdinfo/${fd}`, 'utf8')
        if (!/^inotify /m.test(info)) continue
        n += (info.match(/^inotify /gm) || []).length
      } catch { /* fd closed */ }
    }
  } catch { /* gone */ }
  return n
}

function fdCount(pid) {
  try { return readdirSync(`/proc/${pid}/fd`).length } catch { return 0 }
}

// The paths an app's own open descriptors point at — the only way /proc exposes what a
// watcher is looking at (inotify watch paths are not readable), and enough to catch the
// forbidden shelves when a walk holds directories open.
function watchedPaths(pid) {
  const paths = []
  try {
    for (const fd of readdirSync(`/proc/${pid}/fd`)) {
      try {
        const p = readlinkSync(`/proc/${pid}/fd/${fd}`)
        if (p && p.startsWith('/')) paths.push(p)
      } catch { /* vanished fd */ }
    }
  } catch { /* gone */ }
  return paths
}

let gpuCache = { at: 0, map: new Map() }
function gpuMap() {
  if (Date.now() - gpuCache.at < 1500) return gpuCache.map
  const map = new Map()
  try {
    const out = execFileSync('nvidia-smi', ['--query-compute-apps=pid,used_memory', '--format=csv,noheader,nounits'], { encoding: 'utf8' })
    for (const line of out.split('\n')) {
      const [pid, mib] = line.split(',').map((s) => Number(String(s).trim()))
      if (pid) map.set(pid, mib || 0)
    }
  } catch { /* no card, or no nvidia-smi: null, never a zero that looks measured */ }
  gpuCache = { at: Date.now(), map }
  return map
}

function hyprNotResponding() {
  try {
    const out = execFileSync('hyprctl', ['clients', '-j'], { encoding: 'utf8', timeout: 1500 })
    const clients = JSON.parse(out)
    return clients.filter((w) => /not.?respond/i.test(`${w.title || ''} ${w.class || ''}`)).map((w) => w.title || w.class)
  } catch { return [] }
}

// A watch path is forbidden only when it is a DIRECTORY inside a shelf no file tree shows
// (`node_modules` inside the app's own runtime is where Electron lives, not a leak).
// Inotify watch PATHS are not readable from /proc; this catches what a walk holds open, and
// the watch COUNT budget catches the rest.
function forbiddenOf(paths) {
  const out = new Set()
  for (const p of paths) {
    if (!/\/\.yggdrasil(\/|$)|\/\.git(\/|$)|\/node_modules(\/|$)/.test(p)) continue
    if (/\/node_modules\/electron\//.test(p)) continue
    try { if (!statSync(p).isDirectory()) continue } catch { continue }
    out.add(p)
  }
  return [...out].slice(0, 20)
}

const cpuPrev = new Map()
if (CPU_STATE && existsSync(CPU_STATE)) {
  try {
    for (const [k, v] of Object.entries(JSON.parse(readFileSync(CPU_STATE, 'utf8')))) cpuPrev.set(Number(k), v)
  } catch { /* a torn state file is a cold start, never a guess */ }
}
function saveCpuState() {
  if (!CPU_STATE) return
  try {
    const o = {}
    for (const [k, v] of cpuPrev) o[k] = v
    fs.writeFileSync(CPU_STATE, JSON.stringify(o))
  } catch { /* a read-only shelf still measures */ }
}
function cpuPct(pid) {
  const s = statOf(pid)
  if (!s) return null
  const total = s.utime + s.stime
  const prev = cpuPrev.get(pid)
  cpuPrev.set(pid, { total, at: Date.now() })
  saveCpuState()
  if (!prev) return null
  const dt = (Date.now() - prev.at) / 1000
  if (dt <= 0) return null
  return Math.round((((total - prev.total) / CLOCK_TICKS) / dt) * 1000) / 10
}

function measure(rootPid, { paths = false } = {}) {
  const pids = tree(rootPid)
  let rssKb = 0, threads = 0, fds = 0, watches = 0, cpuTicks = 0, zombies = 0
  const gpu = gpuMap()
  let gpuMb = 0, gpuHit = false
  for (const p of pids) {
    const st = readStatus(p)
    rssKb += st.rssKb
    threads += st.threads
    if (st.state === 'Z') zombies++
    fds += fdCount(p)
    watches += inotifyWatches(p)
    const s = statOf(p)
    if (s) cpuTicks += s.utime + s.stime
    if (gpu.has(p)) { gpuMb += gpu.get(p); gpuHit = true }
  }
  // No `kind` here: the caller owns what the row IS. A measurement that names itself
  // would overwrite a caller's kind by spread order — the sort of silent lie this
  // house has paid for.
  const mainStatus = readStatus(rootPid)
  const row = {
    ts: nowIso(),
    pid: rootPid,
    procs: pids.length,
    // The whole tree, and the MAIN process alone: plan 275 measured a main-process budget
    // (1.5 GB → 259 MB), so a judge that only saw the tree would compare two different things.
    rss_mb: Math.round((rssKb / 1024) * 10) / 10,
    main_rss_mb: Math.round((mainStatus.rssKb / 1024) * 10) / 10,
    fds,
    watches,
    children: Math.max(0, pids.length - 1),
    threads,
    zombies,
    gpu_mb: gpu.size ? (gpuHit ? gpuMb : 0) : null,
    main_cpu_pct: cpuPct(rootPid),
    tree_cpu_ticks: cpuTicks,
  }
  if (paths) {
    const all = []
    for (const p of pids) all.push(...watchedPaths(p))
    row.forbidden_paths = forbiddenOf(all)
  }
  return row
}

// ── CDP ────────────────────────────────────────────────────────────────────────
// A minimal RFC 6455 client. It exists because Chromium REFUSES a DevTools websocket that
// carries an Origin header unless the app was started with --remote-allow-origins — and a
// native client that sends none is accepted by every Electron this house runs, including the
// ones released before that flag was seated. No dependency, no Origin, no handshake surprise.
class WS {
  constructor(url) {
    this.url = new URL(url)
    this.buffer = Buffer.alloc(0)
    this.fragments = []
    this.fragOpcode = 0
    this.onmessage = () => {}
    this.onclose = () => {}
    this.ready = new Promise((resolve, reject) => {
      const key = crypto.randomBytes(16).toString('base64')
      this.sock = net.connect(Number(this.url.port || 80), this.url.hostname, () => {
        const path = this.url.pathname + (this.url.search || '')
        this.sock.write(
          `GET ${path} HTTP/1.1\r\n` +
          `Host: ${this.url.hostname}:${this.url.port}\r\n` +
          'Upgrade: websocket\r\nConnection: Upgrade\r\n' +
          `Sec-WebSocket-Key: ${key}\r\nSec-WebSocket-Version: 13\r\n\r\n`)
      })
      this.sock.setNoDelay(true)
      this.sock.on('error', (e) => reject(e))
      this.sock.on('close', () => this.onclose())
      let handshaken = false
      this.sock.on('data', (chunk) => {
        this.buffer = Buffer.concat([this.buffer, chunk])
        if (!handshaken) {
          const end = this.buffer.indexOf('\r\n\r\n')
          if (end < 0) return
          const head = this.buffer.slice(0, end).toString('latin1')
          this.buffer = this.buffer.slice(end + 4)
          if (!/^HTTP\/1\.1 101/i.test(head)) return reject(new Error(`the DevTools socket refused the upgrade: ${head.split('\r\n')[0]}`))
          handshaken = true
          resolve()
        }
        this.parse()
      })
    })
  }
  parse() {
    for (;;) {
      if (this.buffer.length < 2) return
      const b0 = this.buffer[0], b1 = this.buffer[1]
      const fin = (b0 & 0x80) !== 0, opcode = b0 & 0x0f, masked = (b1 & 0x80) !== 0
      let len = b1 & 0x7f, off = 2
      if (len === 126) { if (this.buffer.length < 4) return; len = this.buffer.readUInt16BE(2); off = 4 }
      else if (len === 127) { if (this.buffer.length < 10) return; len = Number(this.buffer.readBigUInt64BE(2)); off = 10 }
      let mask = null
      if (masked) { if (this.buffer.length < off + 4) return; mask = this.buffer.slice(off, off + 4); off += 4 }
      if (this.buffer.length < off + len) return
      let payload = Buffer.from(this.buffer.slice(off, off + len))
      if (mask) for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i % 4]
      this.buffer = this.buffer.slice(off + len)
      if (opcode === 0x9) { this.write(0xa, payload); continue }        // ping → pong
      if (opcode === 0x8) { try { this.sock.end() } catch {} ; this.onclose(); return }
      if (opcode === 0x0) { this.fragments.push(payload) } else { this.fragments = [payload]; this.fragOpcode = opcode }
      if (!fin) continue
      const whole = Buffer.concat(this.fragments)
      this.fragments = []
      if (this.fragOpcode === 0x1) this.onmessage(whole.toString('utf8'))
    }
  }
  write(opcode, payloadBuf) {
    const mask = crypto.randomBytes(4)
    const len = payloadBuf.length
    let head
    if (len < 126) head = Buffer.from([0x80 | opcode, 0x80 | len])
    else if (len < 65536) { head = Buffer.alloc(4); head[0] = 0x80 | opcode; head[1] = 0x80 | 126; head.writeUInt16BE(len, 2) }
    else { head = Buffer.alloc(10); head[0] = 0x80 | opcode; head[1] = 0x80 | 127; head.writeBigUInt64BE(BigInt(len), 2) }
    const body = Buffer.alloc(len)
    for (let i = 0; i < len; i++) body[i] = payloadBuf[i] ^ mask[i % 4]
    try { this.sock.write(Buffer.concat([head, mask, body])) } catch { /* the app closed: the caller's timeout reports it */ }
  }
  send(text) { this.write(0x1, Buffer.from(text, 'utf8')) }
  close() { try { this.sock.end() } catch { /* gone */ } }
}

class CDP {
  constructor(url) {
    this.id = 0
    this.pending = new Map()
    this.handlers = new Map()
    this.ws = new WS(url)
    this.ready = this.ws.ready
    this.ws.onmessage = (text) => {
      let m
      try { m = JSON.parse(text) } catch { return }
      if (m.id && this.pending.has(m.id)) {
        const { res, rej } = this.pending.get(m.id)
        this.pending.delete(m.id)
        m.error ? rej(new Error(`${m.error.message}${m.error.data ? `: ${m.error.data}` : ''}`)) : res(m.result)
      } else if (m.method) {
        for (const h of this.handlers.get(m.method) || []) h(m.params)
      }
    }
    this.ws.onclose = () => {
      for (const { rej } of this.pending.values()) rej(new Error('the DevTools socket closed'))
      this.pending.clear()
    }
  }
  send(method, params = {}, timeoutMs = 60000) {
    const id = ++this.id
    return new Promise((res, rej) => {
      const t = setTimeout(() => { this.pending.delete(id); rej(new Error(`${method} timed out after ${timeoutMs} ms`)) }, timeoutMs)
      this.pending.set(id, { res: (v) => { clearTimeout(t); res(v) }, rej: (e) => { clearTimeout(t); rej(e) } })
      this.ws.send(JSON.stringify({ id, method, params }))
    })
  }
  on(method, h) {
    const a = this.handlers.get(method) || []
    a.push(h)
    this.handlers.set(method, a)
  }
  close() { this.ws.close() }
}

async function pickTarget(port) {
  const res = await fetch(`http://127.0.0.1:${port}/json/list`, { signal: AbortSignal.timeout(4000) })
  const list = await res.json()
  const pages = list.filter((t) => t.type === 'page' && !String(t.url).startsWith('devtools://'))
  if (!pages.length) throw new Error('the DevTools door answers but lists no page')
  // The app's own window is the one carrying its title; the blank/blank-ish target that
  // Chromium keeps for internal pages is not the app.
  return pages.find((p) => !/^(about:blank|chrome:)/.test(p.url)) || pages[0]
}

const OBSERVER = `(() => {
  if (window.__ymirSoak) return;
  window.__ymirSoak = { longtasks: [], errors: 0, maxTask: 0 };
  try {
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) {
        const d = Math.round(e.duration);
        window.__ymirSoak.longtasks.push({ start: Math.round(e.startTime), duration: d });
        if (d > window.__ymirSoak.maxTask) window.__ymirSoak.maxTask = d;
      }
      if (window.__ymirSoak.longtasks.length > 500) window.__ymirSoak.longtasks.splice(0, 250);
    }).observe({ entryTypes: ['longtask'] });
  } catch (_) {}
  window.addEventListener('error', () => { window.__ymirSoak.errors++ });
})();`

async function initPage(cdp) {
  await cdp.send('Runtime.enable')
  await cdp.send('Page.enable')
  await cdp.send('HeapProfiler.enable')
  await cdp.send('Profiler.enable')
  await cdp.send('Log.enable').catch(() => {})
  await cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: OBSERVER }).catch(() => {})
  await evalJS(cdp, OBSERVER)
}

async function evalJS(cdp, expression, timeoutMs = 15000) {
  const r = await cdp.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }, timeoutMs)
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.text || 'evaluate threw')
  return r.result?.value
}

async function heapMb(cdp) {
  // A forced collection first: a number taken without one is wood, not measurement.
  await cdp.send('HeapProfiler.collectGarbage', {}, 60000).catch(() => {})
  const u = await cdp.send('Runtime.getHeapUsage')
  return Math.round((u.usedSize / 1048576) * 100) / 100
}

async function pageState(cdp) {
  try {
    const raw = await evalJS(cdp, 'JSON.stringify(window.__ymirSoak || {longtasks:[],maxTask:0,errors:0})')
    return JSON.parse(raw || '{}')
  } catch { return { longtasks: [], maxTask: 0, errors: 0 } }
}

async function navigate(cdp, route, baseUrl, settleMs) {
  if (route) {
    const expr = `(() => { const h = ${JSON.stringify(route)}; if (location.hash !== h) { location.hash = h; return location.href } return location.href })()`
    await evalJS(cdp, expr)
  } else {
    // No hash router: reloading IS the page boundary, and it replays the app's boot path.
    const done = new Promise((res) => { const h = () => res(); cdp.on('Page.loadEventFired', h); setTimeout(res, 15000) })
    await cdp.send('Page.reload', { ignoreCache: false })
    await done
  }
  await new Promise((r) => setTimeout(r, settleMs))
}

// Sampling heap profile → the allocating call sites that hold the memory.
function flattenHeapProfile(tree, out = [], path = []) {
  if (!tree) return out
  const cf = tree.callFrame || {}
  const site = `${cf.functionName || '(anonymous)'} @ ${String(cf.url || '').replace(/^file:\/\//, '')}:${(cf.lineNumber ?? -1) + 1}`
  const where = [...path, site]
  if ((tree.selfSize || 0) > 0) out.push({ site, where: where.slice(-6), self_mb: Math.round((tree.selfSize / 1048576) * 100) / 100 })
  for (const c of tree.children || []) flattenHeapProfile(c, out, where)
  return out
}
function topAllocators(profile, n = 12) {
  const agg = new Map()
  for (const a of flattenHeapProfile(profile?.head)) {
    const k = a.site
    const cur = agg.get(k) || { site: k, self_mb: 0, where: a.where }
    cur.self_mb = Math.round((cur.self_mb + a.self_mb) * 100) / 100
    agg.set(k, cur)
  }
  return [...agg.values()].sort((a, b) => b.self_mb - a.self_mb).slice(0, n)
}

// CPU profile → the hottest functions, and the tree that called them.
function topFunctions(profile, n = 12) {
  if (!profile?.nodes) return []
  const byId = new Map(profile.nodes.map((x) => [x.id, x]))
  const agg = new Map()
  for (const node of profile.nodes) {
    const hits = node.hitCount || 0
    if (!hits) continue
    const cf = node.callFrame || {}
    const site = `${cf.functionName || '(anonymous)'} @ ${String(cf.url || '').replace(/^file:\/\//, '')}:${(cf.lineNumber ?? -1) + 1}`
    const parent = node.parent ? byId.get(node.parent) : null
    const caller = parent?.callFrame ? `${parent.callFrame.functionName || '(anonymous)'} @ ${String(parent.callFrame.url || '').replace(/^file:\/\//, '')}:${(parent.callFrame.lineNumber ?? -1) + 1}` : ''
    const cur = agg.get(site) || { site, samples: 0, caller }
    cur.samples += hits
    agg.set(site, cur)
  }
  return [...agg.values()].sort((a, b) => b.samples - a.samples).slice(0, n)
}

async function takeSnapshot(cdp, label) {
  if (NO_ARTIFACTS || !ARTIFACTS) return null
  try { mkdirSync(ARTIFACTS, { recursive: true }) } catch { return null }
  const file = `${ARTIFACTS}/${APP}-${nowIso().replace(/[:.]/g, '-')}-${label}.heapsnapshot`
  let fd
  try { fd = openSync(file, 'w') } catch { return null }
  const chunks = []
  const onChunk = (p) => chunks.push(p.chunk)
  cdp.on('HeapProfiler.addHeapSnapshotChunk', onChunk)
  try {
    await cdp.send('HeapProfiler.takeHeapSnapshot', { reportProgress: false, captureNumericValue: false }, 300000)
  } catch {
    closeSync(fd)
    try { rmSync(file, { force: true }) } catch { /* nothing written */ }
    return null
  }
  for (const c of chunks) writeSync(fd, c)
  closeSync(fd)
  const mb = Math.round((statSync(file).size / 1048576) * 10) / 10
  return { file, mb }
}

async function cpuProfile10s(cdp) {
  try {
    await cdp.send('Profiler.setSamplingInterval', { interval: 1000 })
    await cdp.send('Profiler.start')
    await new Promise((r) => setTimeout(r, 10000))
    const { profile } = await cdp.send('Profiler.stop')
    return profile
  } catch { return null }
}

// ── the ledger ────────────────────────────────────────────────────────────────
function writeRow(row) {
  if (RUN && !row.run) row.run = RUN
  const line = JSON.stringify(row)
  if (LEDGER) {
    try { appendFileSync(LEDGER, JSON.stringify(row) + '\n') } catch { /* a read-only ledger is reported, not fatal */ }
  }
  if (JSON_OUT) process.stdout.write(line + '\n')
  else if (row.kind === 'judge' || row.kind === 'finding') process.stdout.write(line + '\n')
}

function readLedger() {
  if (!LEDGER || !existsSync(LEDGER)) return []
  const rows = []
  for (const line of readFileSync(LEDGER, 'utf8').split('\n')) {
    if (!line.trim()) continue
    try { rows.push(JSON.parse(line)) } catch { /* a torn line is skipped, never guessed */ }
  }
  return rows
}

function pick(rows, kind) { return rows.filter((r) => r.kind === kind) }

// ── the judge: plan 286 §5, and the boot budgets that make P1 bite ─────────────
function judge(allRows) {
  const rows = RUN ? allRows.filter((r) => r.run === RUN) : allRows
  const base = pick(rows, 'baseline').at(-1)
  const after = pick(rows, 'after_cycles').at(-1)
  const samples = pick(rows, 'sample')
  const last = samples.at(-1)
  const boot = pick(rows, 'boot')
  const findings = []
  const growth = {}
  const pct = (a, b) => (b && b !== 0 ? Math.round(((a - b) / b) * 10000) / 100 : null)

  // A leak is what the app never GIVES BACK (plan 286 §1). So the cycle budgets are judged on
  // the lowest reading the app comes back to after the passes — not on the peak five seconds
  // after the last reload, which is a teardown in flight. A real leak keeps its memory.
  const afterCycleRss = [after?.rss_mb, ...samples.map((s) => s.rss_mb)].filter((v) => typeof v === 'number')
  const retainedRss = afterCycleRss.length ? Math.min(...afterCycleRss) : null
  const afterCycleHeap = [after?.heap_mb, last?.heap_mb].filter((v) => typeof v === 'number')
  const retainedHeap = afterCycleHeap.length ? Math.min(...afterCycleHeap) : null

  // A descriptor or a watch that appears ONCE is a bounded step (a stream armed on first use,
  // a watcher re-attached after a reload); a leak grows WITH the work. So the count budgets
  // fire when the last pass still added something — the drip — and the total step is reported
  // beside it so nothing is hidden.
  const cyclesRows = pick(rows, 'cycle')
  // Descriptors and sockets churn as a page opens and closes them, so ONE pair of readings is
  // noise. A drip is a count that does not fall across the last three passes and is higher at
  // the end than at the start.
  const drip = (key) => {
    const tail = cyclesRows.slice(-3).map((r) => r[key]).filter((v) => typeof v === 'number')
    if (tail.length < 3) return { rising: false, last_pass: null, tail }
    const rising = tail[0] <= tail[1] && tail[1] <= tail[2] && tail[2] > tail[0]
    return { rising, last_pass: tail[2] - tail[1], tail }
  }
  const fdsT = drip('fds'), watchesT = drip('watches'), childrenT = drip('children')
  growth.fds_last_pass = fdsT.last_pass
  growth.watches_last_pass = watchesT.last_pass
  growth.children_last_pass = childrenT.last_pass
  growth.fds_tail = fdsT.tail
  growth.watches_tail = watchesT.tail

  if (base && after) {
    growth.rss_cycle_peak_pct = pct(after.rss_mb, base.rss_mb)
    growth.rss_cycle_retained_pct = retainedRss != null ? pct(retainedRss, base.rss_mb) : null
    growth.rss_cycle_pct = growth.rss_cycle_retained_pct
    growth.fds_cycle = after.fds - base.fds
    growth.watches_cycle = after.watches - base.watches
    growth.children_cycle = after.children - base.children
    if (base.heap_mb != null && retainedHeap != null) growth.heap_cycle_mb = Math.round((retainedHeap - base.heap_mb) * 100) / 100
    if (growth.rss_cycle_pct != null && growth.rss_cycle_pct > B.rssCyclePct)
      findings.push({ leak: 'rss_cycle_growth', detail: `RSS kept ${growth.rss_cycle_pct} % more than the baseline over ${CYCLES} passes of every page and never gave it back (budget ${B.rssCyclePct} %; peak ${growth.rss_cycle_peak_pct} %)`, from_mb: base.rss_mb, to_mb: retainedRss })
    if (growth.heap_cycle_mb != null && growth.heap_cycle_mb > B.heapCycleMb)
      findings.push({ leak: 'js_heap_cycle_growth', detail: `JS heap after a forced GC kept ${growth.heap_cycle_mb} MB over ${CYCLES} passes (budget ${B.heapCycleMb} MB)`, from_mb: base.heap_mb, to_mb: retainedHeap })
    if (growth.fds_cycle > B.fdsDelta && fdsT.rising)
      findings.push({ leak: 'fd_growth', detail: `${growth.fds_cycle} descriptors were opened and never closed over ${CYCLES} passes, and the count did not fall across the last three (${fdsT.tail.join(' → ')}) — budget ${B.fdsDelta}`, from: base.fds, to: after.fds, tail: fdsT.tail })
    if (growth.watches_cycle > B.watchesDelta && watchesT.rising)
      findings.push({ leak: 'watch_growth', detail: `${growth.watches_cycle} inotify watches were added over ${CYCLES} passes and the count did not fall across the last three (${watchesT.tail.join(' → ')}) — budget ${B.watchesDelta}`, from: base.watches, to: after.watches, tail: watchesT.tail })
    if (growth.children_cycle > B.childrenDelta && childrenT.rising)
      findings.push({ leak: 'child_growth', detail: `${growth.children_cycle} child processes outlived their request, and the count did not fall across the last three (${childrenT.tail.join(' → ')}) — budget ${B.childrenDelta}`, from: base.children, to: after.children, tail: childrenT.tail })
    if ((after.zombies || 0) > 0 || (base.zombies || 0) > 0)
      findings.push({ leak: 'zombie_children', detail: `${after.zombies || 0} zombies under the app`, count: after.zombies || 0 })
  }

  if (after && last) {
    growth.rss_idle_pct = pct(last.rss_mb, after.rss_mb)
    growth.fds_idle = last.fds - after.fds
    growth.watches_idle = last.watches - after.watches
    if (after.heap_mb != null && last.heap_mb != null) growth.heap_idle_mb = Math.round((last.heap_mb - after.heap_mb) * 100) / 100
    if (growth.rss_idle_pct != null && growth.rss_idle_pct > B.rssIdlePct)
      findings.push({ leak: 'rss_idle_growth', detail: `RSS grew ${growth.rss_idle_pct} % while idle over ${IDLE}s (budget ${B.rssIdlePct} %)`, from_mb: after.rss_mb, to_mb: last.rss_mb })
    if (growth.heap_idle_mb != null && growth.heap_idle_mb > B.heapIdleMb)
      findings.push({ leak: 'js_heap_idle_growth', detail: `JS heap after a forced GC grew ${growth.heap_idle_mb} MB while idle (budget ${B.heapIdleMb} MB)`, from_mb: after.heap_mb, to_mb: last.heap_mb })
    if (growth.fds_idle > B.fdsDelta)
      findings.push({ leak: 'fd_growth_idle', detail: `${growth.fds_idle} descriptors were opened while idle and never closed`, from: after.fds, to: last.fds })
    if (growth.watches_idle > B.watchesDelta)
      findings.push({ leak: 'watch_growth_idle', detail: `${growth.watches_idle} inotify watches appeared while idle`, from: after.watches, to: last.watches })
  }

  // The main thread, which is what the operator actually feels.
  const idleTasks = samples.flatMap((s) => s.long_tasks || []).filter((t) => (t.duration || 0) > B.longtaskIdleMs)
  if (idleTasks.length)
    findings.push({ leak: 'main_thread_idle_task', detail: `${idleTasks.length} main-thread task(s) over ${B.longtaskIdleMs} ms while idle (worst ${Math.max(...idleTasks.map((t) => t.duration))} ms)`, worst_ms: Math.max(...idleTasks.map((t) => t.duration)) })
  const worstCycle = Math.max(0, ...(after?.long_tasks || []).map((t) => t.duration || 0), ...samples.map((s) => s.max_task || 0))
  if (worstCycle > B.longtaskCycleMs)
    findings.push({ leak: 'main_thread_cycle_task', detail: `a main-thread task ran ${worstCycle} ms (budget ${B.longtaskCycleMs} ms)`, worst_ms: worstCycle })
  const dialogs = [...new Set([...(after?.dialogs || []), ...samples.flatMap((s) => s.dialogs || [])])]
  if (dialogs.length > B.dialogs)
    findings.push({ leak: 'not_responding', detail: `the compositor raised ${dialogs.length} not-responding dialog(s): ${dialogs.slice(0, 3).join(' · ')}`, dialogs })

  // The boot: a window that answers its compositor, then does its work.
  if (boot.length >= 2) {
    const windowS = boot.length ? boot.length * 3 : 0
    const pegged = boot.filter((s) => (s.main_cpu_pct || 0) >= B.bootCpuPct).length
    const worstMain = Math.max(...boot.map((s) => s.main_rss_mb ?? 0))
    const worstTree = Math.max(...boot.map((s) => s.rss_mb || 0))
    growth.boot_cpu_pegged_samples = pegged
    growth.boot_max_main_rss_mb = worstMain
    growth.boot_max_tree_rss_mb = worstTree
    if (pegged >= 2)
      findings.push({ leak: 'startup_freeze', detail: `the main process held ${B.bootCpuPct} %+ CPU in ${pegged} of the first ${boot.length} three-second boot samples (${pegged * 3}s of ${windowS}s) — the window cannot answer while it does (plan 275 02:50 measured 43 s)`, samples: boot.map((s) => s.main_cpu_pct) })
    if (worstMain > B.bootRssMb)
      findings.push({ leak: 'startup_rss', detail: `the MAIN process reached ${worstMain} MB during boot (budget ${B.bootRssMb} MB; the whole tree ${worstTree} MB) — plan 275 measured 1.5 GB before the fix and 259 MB after`, max_main_mb: worstMain, max_tree_mb: worstTree })
  }

  const forbidden = [...new Set([...(after?.forbidden_paths || []), ...samples.flatMap((s) => s.forbidden_paths || [])])]
  if (forbidden.length)
    findings.push({ leak: 'forbidden_watch_path', detail: `open descriptors inside a shelf no watcher may cross: ${forbidden.slice(0, 3).join(' · ')}`, paths: forbidden })

  return { findings, growth, base, after, last, samples }
}

// ── mode: kill exactly one process tree ───────────────────────────────────────
// The soak closes only what it raised, and only its own tree: a broad `pkill -f <app>`
// would kill another hand's smoke test of the same app (this house runs several at once).
if (MODE === 'kill') {
  // THE MAIN PROCESS FIRST, then its children. Measured on 2026-11-14: killing a browser's
  // children first (deepest first) makes Chromium relaunch the GPU process, fail three times,
  // and abort with FATAL "GPU process isn't usable. Goodbye." — a SIGTRAP core dump for every
  // soak, and an Omarchy crash notification for a window that was only being closed. The
  // browser knows how to shut its own children down; it is not ours to dismantle from below.
  const root = num('kill-tree', 0)
  const alive = (p) => { try { process.kill(p, 0); return true } catch { return false } }
  const wait = async (pids, ms) => {
    const until = Date.now() + ms
    while (Date.now() < until && pids.some(alive)) await new Promise((r) => setTimeout(r, 250))
  }
  const pids = tree(root)
  try { process.kill(root, 'SIGTERM') } catch { /* already gone */ }
  await wait([root], 8000)
  const rest = pids.filter((p) => p !== root && alive(p)).sort((a, b) => b - a)
  for (const p of rest) { try { process.kill(p, 'SIGTERM') } catch { /* gone */ } }
  await wait(rest, 3000)
  for (const p of [root, ...rest]) { try { if (alive(p)) process.kill(p, 'SIGKILL') } catch { /* gone */ } }
  process.stdout.write(JSON.stringify({ killed: pids.length, root_first: true, killed_pids: pids }) + '\n')
  process.exit(0)
}

// ── mode: measure one pid ─────────────────────────────────────────────────────
if (MODE === 'measure') {
  const row = measure(PID0, { paths: true })
  row.ts = nowIso()
  process.stdout.write(JSON.stringify(row) + '\n')
  process.exit(0)
}

// ── mode: judge an existing ledger ───────────────────────────────────────────
if (MODE === 'judge') {
  const rows = readLedger()
  const { findings, growth } = judge(rows)
  const fn = findings.map((f) => ({ leak: f.leak, detail: f.detail }))
  writeRow({ ts: nowIso(), app: APP, kind: 'judge', verdict: findings.length ? 'leak' : 'pass', leaks: fn.map((f) => f.leak), growth, budgets: B })
  if (!JSON_OUT) {
    for (const f of findings) console.log(`  LEAK ${f.leak}: ${f.detail}`)
    console.log(findings.length ? `verdict: LEAK (${findings.length})` : 'verdict: PASS')
  }
  process.exit(findings.length ? 1 : 0)
}

// ── mode: soak one app ────────────────────────────────────────────────────────
async function attach(timeoutMs = 45000) {
  let target
  // The door is answered off the IO thread, but the MAIN thread serialises the target list:
  // a window frozen in its first seconds answers /json/version and then stalls /json/list.
  // So ask again, until the ceiling — the freeze is what the soak is here to measure.
  const deadline = Date.now() + timeoutMs
  let lastErr = null
  for (;;) {
    try {
      target = await pickTarget(PORT)
      break
    } catch (e) {
      lastErr = e
      if (Date.now() > deadline) {
        writeRow({ ts: nowIso(), app: APP, kind: 'attach_failed', port: PORT, error: String(e.message || e) })
        const { findings, growth } = judge(readLedger())
        writeRow({ ts: nowIso(), app: APP, kind: 'judge', verdict: findings.length ? 'leak' : 'inconclusive', leaks: findings.map((f) => f.leak), growth, budgets: B })
        if (!JSON_OUT) {
          for (const f of findings) console.log(`LEAK ${f.leak}: ${f.detail}`)
          console.log(`verdict: ${findings.length ? `LEAK (${findings.length})` : 'INCONCLUSIVE — the app never answered DevTools'}`)
        }
        process.exit(findings.length ? 1 : 3)
      }
      await new Promise((r) => setTimeout(r, 3000))
    }
  }
  verbose(`target: ${target.url}`)
  const cdp = new CDP(target.webSocketDebuggerUrl)
  const slow = new Promise((_, rej) => setTimeout(() => rej(new Error(`the app did not answer DevTools within ${Math.round(timeoutMs / 1000)} s — a frozen main thread is the cause this soak is looking for`)), timeoutMs))
  try {
    await Promise.race([cdp.ready, slow])
    await Promise.race([initPage(cdp), slow])
  } catch (e) {
    console.error(`could not attach to the app on :${PORT} — ${e.message}`)
    // A window that cannot answer is a finding, not a tool error: record it and judge.
    writeRow({ ts: nowIso(), app: APP, kind: 'attach_failed', port: PORT, error: String(e.message || e) })
    const { findings, growth } = judge(readLedger())
    writeRow({ ts: nowIso(), app: APP, kind: 'judge', verdict: findings.length ? 'leak' : 'inconclusive', leaks: findings.map((f) => f.leak), growth, budgets: B })
    if (!JSON_OUT) {
      for (const f of findings) console.log(`LEAK ${f.leak}: ${f.detail}`)
      const what = findings.length ? `LEAK (${findings.length})` : 'INCONCLUSIVE — the app never answered DevTools'
      console.log(`verdict: ${what}`)
    }
    process.exit(findings.length ? 1 : 3)
  }
  return { cdp, target }
}

// Wait for the counts a leak is judged on to stop moving (up to 30 s), and measure again.
async function settleMeasure(rootPid) {
  let prev = measure(rootPid, { paths: true })
  const t0 = Date.now()
  for (let i = 0; i < 10; i++) {
    await new Promise((r) => setTimeout(r, 3000))
    const next = measure(rootPid, { paths: true })
    if (next.watches === prev.watches && next.fds === prev.fds && next.children === prev.children) {
      next.settled_after_s = Math.round((Date.now() - t0) / 1000)
      return next
    }
    prev = next
  }
  prev.settled_after_s = Math.round((Date.now() - t0) / 1000)
  return prev
}

function bootRow(rootPid, i) {
  const m = measure(rootPid)
  return { ...m, ts: nowIso(), app: APP, kind: 'boot', at_s: i * 3 }
}

async function run() {
  const rootPid = PID0 || Number(process.env.SOAK_APP_PID || 0)
  if (!rootPid) { console.error('no pid to measure: name the app process with --pid'); process.exit(3) }

  // 1 · BOOT, BEFORE DEVTOOLS. The first seconds are where a freeze lives (plan 275 02:50),
  // and a frozen main thread cannot answer a DevTools handshake — so the boot window is
  // measured from /proc first, without asking the app for anything. A leak the port itself
  // could not report is exactly the fault this plan exists for.
  for (let i = 0; i < 5; i++) {
    writeRow(bootRow(rootPid, i))
    await new Promise((r) => setTimeout(r, 3000))
  }

  // 2 · ATTACH. Three minutes is the ceiling: an app still frozen after that cannot be
  // driven, and the boot rows above are the record of why.
  const { cdp, target } = await attach(180000)
  const baseUrl = target.url
  const routes = ROUTES.length ? ROUTES : ['']

  // 2 · BASELINE, with a forced GC so the heap number means something.
  if (SNAPSHOT === 'always') {
    const snap = await takeSnapshot(cdp, 'baseline')
    if (snap) say(`baseline heap snapshot: ${snap.mb} MB`)
  }
  await cdp.send('HeapProfiler.startSampling', { samplingInterval: 32768, includeObjectsCollectedByMajorGC: false }).catch(() => {})
  // A baseline taken while the app is still ARMING its watchers measures the arming, not a
  // leak: Sessrúmnir's file service starts its first walk 2.5 s after the window answers, and
  // the watch count settles a few seconds later. Wait for two equal readings before counting.
  const steady = await settleMeasure(rootPid)
  const base = { ...steady, ts: nowIso(), app: APP, kind: 'baseline' }
  delete base.settled_after_s
  base.heap_mb = await heapMb(cdp)
  writeRow(base)
  say(`baseline: rss ${base.rss_mb} MB · heap ${base.heap_mb} MB · fds ${base.fds} · watches ${base.watches} · children ${base.children} · gpu ${base.gpu_mb ?? 'n/a'}`)

  // 3 · DRIVE every page, CYCLES times.
  for (let pass = 1; pass <= CYCLES; pass++) {
    for (const route of routes) {
      try {
        await navigate(cdp, route, baseUrl, SETTLE)
      } catch (e) {
        writeRow({ ts: nowIso(), app: APP, kind: 'drive_error', pass, route, error: String(e.message || e) })
      }
    }
    const st = await pageState(cdp)
    const row = {
      ...measure(rootPid, { paths: true }), ts: nowIso(), app: APP, kind: 'cycle', pass,
      route: routes.length > 1 ? `${routes.length} pages` : (routes[0] || 'reload'),
      long_tasks: (st.longtasks || []).slice(-20), max_task: st.maxTask || 0, page_errors: st.errors || 0,
      dialogs: hyprNotResponding(),
    }
    writeRow(row)
    verbose(`pass ${pass}/${CYCLES}: rss ${row.rss_mb} MB · heap n/a · fds ${row.fds} · watches ${row.watches}`)
  }

  // 4 · AFTER THE CYCLES: the measurement the cycle budget is judged from. Five seconds of
  // quiet first — a renderer the last reload replaced is torn down asynchronously, and judging
  // a teardown in flight is how a transient becomes a false leak.
  await new Promise((r) => setTimeout(r, 5000))
  const stAfter = await pageState(cdp)
  const after = {
    ...measure(rootPid, { paths: true }), ts: nowIso(), app: APP, kind: 'after_cycles',
    long_tasks: stAfter.longtasks || [], max_task: stAfter.maxTask || 0,
    page_errors: stAfter.errors || 0, dialogs: hyprNotResponding(),
  }
  after.heap_mb = await heapMb(cdp)
  writeRow(after)
  say(`after ${CYCLES} passes: rss ${after.rss_mb} MB · heap ${after.heap_mb} MB · fds ${after.fds} · watches ${after.watches}`)

  // 5 · IDLE, sampled. This is where a leak that is not tied to an action shows.
  const end = Date.now() + IDLE * 1000
  let n = 0
  while (Date.now() < end) {
    await new Promise((r) => setTimeout(r, Math.min(SAMPLE, Math.max(1, Math.round((end - Date.now()) / 1000))) * 1000))
    const st = await pageState(cdp)
    const s = {
      ...measure(rootPid, { paths: true }), ts: nowIso(), app: APP, kind: 'sample', at: (++n) * SAMPLE,
      long_tasks: (st.longtasks || []).slice(-20), max_task: st.maxTask || 0,
      page_errors: st.errors || 0, dialogs: hyprNotResponding(),
    }
    writeRow(s)
    verbose(`idle ${s.at}s: rss ${s.rss_mb} MB · fds ${s.fds} · watches ${s.watches}`)
  }
  // The last word of the idle window is a heap after a forced GC, with the process numbers
  // beside it — one row a judge can compare with the baseline without joining two.
  const finalRow = { ...measure(rootPid, { paths: true }), ts: nowIso(), app: APP, kind: 'sample', final: true, at: (n + 1) * SAMPLE }
  finalRow.heap_mb = await heapMb(cdp)
  writeRow(finalRow)

  // 6 · JUDGE. A breach buys the artifacts that name the cause.
  const { findings, growth } = judge(readLedger())
  let artifacts = []
  let allocators = []
  let cpuTop = []
  if (findings.length) {
    try {
      const prof = await cdp.send('HeapProfiler.stopSampling')
      allocators = topAllocators(prof.profile)
      if (allocators.length) writeRow({ ts: nowIso(), app: APP, kind: 'allocators', allocators })
    } catch { /* no profile to stop */ }
    const cpu = await cpuProfile10s(cdp)
    if (cpu) {
      cpuTop = topFunctions(cpu)
      writeRow({ ts: nowIso(), app: APP, kind: 'cpu_profile', duration_s: 10, top: cpuTop })
    }
    if (SNAPSHOT !== 'never') {
      const snap = await takeSnapshot(cdp, 'leak')
      if (snap) artifacts.push(snap)
    }
  } else {
    // A pass keeps the allocator picture too: "flat, and here is what holds what" is what
    // the next soak diffs against.
    try {
      const prof = await cdp.send('HeapProfiler.stopSampling')
      allocators = topAllocators(prof.profile, 8)
      if (allocators.length) writeRow({ ts: nowIso(), app: APP, kind: 'allocators', allocators })
    } catch { /* nothing sampled */ }
  }

  const verdict = {
    ts: nowIso(), app: APP, kind: 'judge',
    verdict: findings.length ? 'leak' : 'pass',
    leaks: findings.map((f) => f.leak),
    growth, budgets: B,
    window_seconds: IDLE, sample_seconds: SAMPLE, cycles: CYCLES, pages: routes.length,
    target_url: target.url, root_pid: rootPid,
    allocators: allocators.slice(0, 10),
    cpu_top: cpuTop.slice(0, 10),
    artifacts: artifacts.map((a) => a.file),
  }
  writeRow(verdict)
  for (const f of findings) writeRow({ ts: nowIso(), app: APP, kind: 'finding', ...f })

  if (!JSON_OUT) {
    for (const f of findings) {
      console.log(`LEAK ${f.leak}: ${f.detail}`)
      if (f.from_mb != null && f.to_mb != null) console.log(`     ${f.from_mb} MB → ${f.to_mb} MB`)
    }
    if (allocators.length) {
      console.log('largest allocating call sites (sampling heap profile, self size):')
      for (const a of allocators.slice(0, 8)) console.log(`  ${String(a.self_mb).padStart(8)} MB  ${a.site}`)
    }
    if (cpuTop.length) {
      console.log('hottest functions (10 s CPU profile of the window):')
      for (const c of cpuTop.slice(0, 8)) console.log(`  ${String(c.samples).padStart(6)} samples  ${c.site}`)
    }
    for (const a of artifacts) console.log(`artifact: ${a.file} (${a.mb} MB)`)
    console.log(findings.length ? `verdict: LEAK (${findings.length})` : 'verdict: PASS')
  }
  cdp.close()
  process.exit(findings.length ? 1 : 0)
}

run().catch((e) => {
  console.error(`soak driver failed: ${e && e.message ? e.message : e}`)
  process.exit(3)
})
