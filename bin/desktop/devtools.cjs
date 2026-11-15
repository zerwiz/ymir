#!/usr/bin/env node
// devtools.cjs — look into a running Ymir window over the Chrome DevTools Protocol (plan 275 items 10, 19).
//
//   node bin/desktop/devtools.cjs targets <port>   every target the window exposes, one JSON array
//   node bin/desktop/devtools.cjs ask <port>       has the page answered? {ok,ready,painted,title,url,ms}
//   node bin/desktop/devtools.cjs perf <port>      what the renderer did before the first screen: nav timings,
//                                                  paint marks, every resource, the slowest of them
//
// Every Ymir app opens its DevTools on a fixed loopback port (bin/desktop/app-lib.sh · app_devtools_port),
// ALWAYS, so this door exists without a restart and without anyone exporting a variable first. The stopwatch
// uses `ask` for the "window → first answer" measurement: the renderer is asked, in the real window, whether
// its document has reached a ready state and painted something. Nothing here writes to the app.
//
// No dependency: node's own fetch and global WebSocket (node >= 22) do the work. Loopback only — the port
// is never dialled on any other interface, and nothing is sent to a model or the network.
'use strict'

const USAGE = 'usage: devtools.cjs targets|ask|perf <port>'
const [cmd, portArg] = process.argv.slice(2)
const port = Number(portArg || 0)

if (cmd === '--version' || cmd === '-v') { console.log('1.0.0'); process.exit(0) }
if (!cmd || !port || Number.isNaN(port)) { console.error(USAGE); process.exit(2) }

const base = `http://127.0.0.1:${port}`

async function targets() {
  const res = await fetch(`${base}/json/list`, { signal: AbortSignal.timeout(2000) })
  if (!res.ok) throw new Error(`HTTP ${res.status} from ${base}/json/list`)
  const list = await res.json()
  if (!Array.isArray(list)) throw new Error('the DevTools door did not answer with a target list')
  return list
}

// The app's own document: never the DevTools front-end, never an iframe-less blank target.
function pick(list) {
  return list.find(t => t.type === 'page' && t.url && !t.url.startsWith('devtools://') && !t.url.startsWith('about:'))
      || list.find(t => t.type === 'page' && t.url && !t.url.startsWith('devtools://'))
      || list.find(t => t.type === 'page')
      || null
}

// The question the stopwatch asks. A renderer that has parsed its HTML but not painted (a white window) is
// NOT an answer, which is exactly the freeze the Allfather saw: the window mapping is not the app answering.
const READY = `(() => {
  const b = document.body;
  const text = b ? (b.innerText || '').trim() : '';
  const media = !!document.querySelector('canvas,svg,img,video');
  return JSON.stringify({
    ready: document.readyState,
    painted: !!b && b.childElementCount > 0 && (text.length > 0 || media),
    root: b && b.firstElementChild ? (b.firstElementChild.id || b.firstElementChild.tagName.toLowerCase()) : '',
    nodes: b ? b.childElementCount : 0,
    chars: text.length,
    title: document.title || '',
    url: location.href
  });
})()`

// What the renderer spent its time on before the first screen. Read from the page itself: the navigation entry,
// the paint entries, every resource it fetched, and the module scripts it evaluated. This is how a white window
// becomes a number and a list — the Allfather's "measure what the renderer does before first paint".
const PERF = `(() => {
  const nav = performance.getEntriesByType('navigation')[0] || {};
  const paints = {};
  for (const p of performance.getEntriesByType('paint')) paints[p.name] = Math.round(p.startTime);
  const res = performance.getEntriesByType('resource').map(r => ({
    name: r.name.replace(location.origin, ''),
    type: r.initiatorType,
    start: Math.round(r.startTime),
    dur: Math.round(r.duration),
    bytes: r.decodedBodySize || r.transferSize || 0
  }));
  const slowest = res.slice().sort((a, b) => b.dur - a.dur).slice(0, 12);
  const modules = document.querySelectorAll('script[type="module"]').length;
  const links = document.querySelectorAll('link[rel="modulepreload"],link[rel="preload"]').length;
  return JSON.stringify({
    url: location.href,
    nav: {
      responseEnd: Math.round(nav.responseEnd || 0),
      domContentLoaded: Math.round(nav.domContentLoadedEventEnd || 0),
      load: Math.round(nav.loadEventEnd || 0),
      domInteractive: Math.round(nav.domInteractive || 0)
    },
    paints,
    resources: { count: res.length, bytes: res.reduce((n, r) => n + r.bytes, 0), scripts: res.filter(r => r.type === 'script').length },
    slowest,
    modules,
    preloads: links,
    body: { nodes: document.body ? document.body.childElementCount : 0, chars: document.body ? (document.body.innerText || '').trim().length : 0 }
  });
})()`

async function ask() {
  const started = Date.now()
  const list = await targets()
  const target = pick(list)
  if (!target || !target.webSocketDebuggerUrl) throw new Error('no page target — the window has no document yet')

  const answer = await new Promise((resolve, reject) => {
    let ws
    const timer = setTimeout(() => { try { ws && ws.close() } catch {} ; reject(new Error('CDP timeout')) }, 4000)
    try { ws = new WebSocket(target.webSocketDebuggerUrl) } catch (e) { clearTimeout(timer); return reject(e) }
    ws.addEventListener('open', () => {
      ws.send(JSON.stringify({ id: 1, method: 'Runtime.evaluate', params: { expression: READY, returnByValue: true } }))
    })
    ws.addEventListener('message', ev => {
      let m
      try { m = JSON.parse(typeof ev.data === 'string' ? ev.data : String(ev.data)) } catch { return }
      if (m.id !== 1) return
      clearTimeout(timer)
      try { ws.close() } catch {}
      if (m.error) return reject(new Error(m.error.message || 'CDP error'))
      const value = m.result && m.result.result && m.result.result.value
      if (typeof value !== 'string') return reject(new Error('the renderer answered without a value'))
      try { resolve(JSON.parse(value)) } catch { reject(new Error('the renderer answered with an unreadable value')) }
    })
    ws.addEventListener('error', () => { clearTimeout(timer); reject(new Error(`websocket refused on ${base}`)) })
  })

  return { ok: true, port, target: target.url, ms: Date.now() - started, ...answer }
}

async function evaluate(expression) {
  const list = await targets()
  const target = pick(list)
  if (!target || !target.webSocketDebuggerUrl) throw new Error('no page target — the window has no document yet')
  return await new Promise((resolve, reject) => {
    let ws
    const timer = setTimeout(() => { try { ws && ws.close() } catch {} ; reject(new Error('CDP timeout')) }, 5000)
    try { ws = new WebSocket(target.webSocketDebuggerUrl) } catch (e) { clearTimeout(timer); return reject(e) }
    ws.addEventListener('open', () => {
      ws.send(JSON.stringify({ id: 1, method: 'Runtime.evaluate', params: { expression, returnByValue: true } }))
    })
    ws.addEventListener('message', ev => {
      let m
      try { m = JSON.parse(typeof ev.data === 'string' ? ev.data : String(ev.data)) } catch { return }
      if (m.id !== 1) return
      clearTimeout(timer)
      try { ws.close() } catch {}
      if (m.error) return reject(new Error(m.error.message || 'CDP error'))
      const value = m.result && m.result.result && m.result.result.value
      if (typeof value !== 'string') return reject(new Error('the renderer answered without a value'))
      try { resolve(JSON.parse(value)) } catch { reject(new Error('the renderer answered with an unreadable value')) }
    })
    ws.addEventListener('error', () => { clearTimeout(timer); reject(new Error(`websocket refused on ${base}`)) })
  })
}

async function main() {
  if (cmd === 'perf') {
    const out = await evaluate(PERF)
    console.log(JSON.stringify({ ok: true, port, ...out }))
  } else if (cmd === 'targets') {
    const list = await targets()
    console.log(JSON.stringify(list.map(t => ({ type: t.type, title: t.title, url: t.url }))))
  } else if (cmd === 'ask') {
    console.log(JSON.stringify(await ask()))
  } else {
    console.error(USAGE)
    process.exit(2)
  }
}

main().catch(e => {
  console.log(JSON.stringify({ ok: false, port, error: (e && e.message) || String(e) }))
  process.exit(1)
})
