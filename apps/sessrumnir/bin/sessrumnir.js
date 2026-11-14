#!/usr/bin/env node

/**
 * sessrumnir — CLI launcher for the Sessrúmnir desktop GUI
 *
 * Usage:
 *   sessrumnir                 # Launch the app
 *   sessrumnir --help          # Show help
 *   sessrumnir --version       # Show version
 *   sessrumnir /path/to/dir    # Launch with workspace
 */

const { spawn } = require('child_process')
const { existsSync } = require('fs')
const { join, resolve, dirname } = require('path')

const VERSION = require('../package.json').version

// ─── Parse args ──────────────────────────────────────────────────────────────

const args = process.argv.slice(2)

if (args.includes('--help') || args.includes('-h')) {
  console.log(`
  sessrumnir v${VERSION} — Desktop seat of Ymir (GUI for the Pi/OMP coding agents)

  Usage:
    sessrumnir                  Launch the app
    sessrumnir <path>           Launch with workspace directory
    sessrumnir --help           Show this help
    sessrumnir --version        Show version

  Examples:
    sessrumnir                  # Launch with default workspace
    sessrumnir ~/my-project     # Launch with specific project
    sessrumnir .                # Launch with current directory

  Install:
    See https://github.com/zerwiz/ymir for releases
    and build-from-source instructions.

  The app requires Pi to be installed:
    curl -fsSL https://pi.dev/install.sh | sh
    # or
    npm install -g @earendil-works/pi-coding-agent
`)
  process.exit(0)
}

if (args.includes('--version') || args.includes('-v')) {
  console.log(VERSION)
  process.exit(0)
}

// ─── Find Electron binary ────────────────────────────────────────────────────

function findElectron() {
  // a named binary wins (the launcher's own test seats a stand-in here; never set it in daily use)
  if (process.env.SESSRUMNIR_ELECTRON && existsSync(process.env.SESSRUMNIR_ELECTRON)) {
    return process.env.SESSRUMNIR_ELECTRON
  }
  // The app's own node_modules, then every ancestor's (plan 275 S10, 2026-11-12): every Ymir app shares ONE
  // Electron, which npm hoists to the workspace root — the app-local copy no longer exists, and looking only here
  // left Sessrúmnir with "Electron not found" while the release held a proved 43.8.9 two folders up.
  const candidates = []
  for (let d = join(__dirname, '..'); ; d = dirname(d)) {
    candidates.push(join(d, 'node_modules', 'electron', 'dist', 'electron'))
    if (dirname(d) === d) break
  }

  for (const candidate of candidates) {
    if (existsSync(candidate)) {
      return candidate
    }
  }

  // Try to find globally installed electron
  try {
    const { execSync } = require('child_process')
    const electronPath = execSync('which electron', { encoding: 'utf8', timeout: 5000 }).trim()
    if (existsSync(electronPath)) {
      return electronPath
    }
  } catch {
    // Not found
  }

  console.error('Error: Electron not found. Please install dependencies:')
  console.error('  cd ' + join(__dirname, '..') + ' && npm install')
  process.exit(1)
}

// ─── Find app resources ─────────────────────────────────────────────────────

function findAppResources() {
  // Packaged app: resources are in app.asar or app directory
  const packagedPaths = [
    join(__dirname, '..', 'app.asar'),
    join(__dirname, '..', 'app'),
    join(__dirname, '..', 'resources', 'app.asar'),
    join(__dirname, '..', 'resources', 'app'),
  ]

  for (const p of packagedPaths) {
    if (existsSync(p)) {
      return p
    }
  }

  // Development: use the project root (electron-vite builds to out/)
  const devPath = join(__dirname, '..')
  if (existsSync(join(devPath, 'out', 'main', 'index.js'))) {
    return devPath
  }

  // Build first
  console.error('Error: App not built. Run "npm run build" first.')
  process.exit(1)
}

// ─── Launch ──────────────────────────────────────────────────────────────────

function launch() {
  const electronPath = findElectron()
  const appPath = findAppResources()

  // Resolve workspace path if provided
  let workspacePath = null
  if (args.length > 0 && !args[0].startsWith('-')) {
    workspacePath = resolve(args[0])
    if (!existsSync(workspacePath)) {
      console.error(`Error: Path does not exist: ${workspacePath}`)
      process.exit(1)
    }
  }

  // Build electron args.
  // --no-sandbox is required so Pi subprocesses can spawn.
  // GPU safety (P7, 2026-09-24): bin/desktop/sessrumnir.sh resolves the ONE machine-wide
  // graphics policy (bin/host/graphics-lib.sh) and exports the effective override in
  // YMIR_DESKTOP_DISABLE_GPU (1 = software rendering). On a fragile hybrid the
  // Electron GPU process dies for want of a fence and the browser makes SIGTRAP
  // suicide once the process is judged unusable — the same fix scripts/electron.sh
  // applies to hlidskjalf/smidja/odrerir. The DECISION lives in the launcher,
  // never hardcoded here.
  const electronArgs = [appPath, '--no-sandbox']
  // plan 275 S16: the DevTools port, so the app can be tested as a person uses it (unset = none)
  if (process.env.YMIR_DEVTOOLS_PORT) {
    electronArgs.push(`--remote-debugging-port=${process.env.YMIR_DEVTOOLS_PORT}`)
    // Chromium refuses a DevTools websocket that carries an Origin header unless the origins
    // are named, and every scripted client (node's built-in WebSocket, any harness) sends one.
    // Without this the door answers /json and then fails the handshake — measured 2026-11-13.
    // Only while the door is open, and the port binds loopback by default.
    electronArgs.push('--remote-allow-origins=*')
  }
  if (['1', 'true', 'yes'].includes(String(process.env.YMIR_DESKTOP_DISABLE_GPU ?? '').toLowerCase())) {
    electronArgs.push('--disable-gpu', '--disable-gpu-compositing')
    // MEASURED 2026-11-14 on this machine: with `--disable-gpu` and NO ozone flag, the
    // window is created and never maps on Wayland — the compositor lists no client, the
    // operator sees nothing and clicks the icon again ("it starts over and over"). The
    // same app with `--disable-gpu --ozone-platform=x11` maps at once (XWayland draws the
    // software-composited window). The graphics policy resolves to `software` on this
    // hybrid box, so this is the path every launch takes here; other platforms and X11
    // sessions are untouched.
    if (process.platform === 'linux' && process.env.WAYLAND_DISPLAY) {
      electronArgs.push('--ozone-platform=x11')
    }
  }

  // Pass workspace path via environment variable
  const env = { ...process.env }
  // Chromium's own error lines go to the log: an empty log was the whole of the 2026-11-12 mystery.
  if (!env.ELECTRON_ENABLE_LOGGING) env.ELECTRON_ENABLE_LOGGING = '1'
  // The repo root, so the renderer can reach hodd/, svartalfaheim/, workspace/.
  env.YMIR_ROOT = resolve(__dirname, '..', '..', '..')
  if (workspacePath) {
    env.PI_DESKTOP_WORKSPACE = workspacePath
  }

  // Launch Electron
  const child = spawn(electronPath, electronArgs, {
    stdio: 'inherit',
    env,
    detached: false,
  })

  const startedAt = Date.now()
  console.log(`[sessrumnir] electron started pid=${child.pid} app=${appPath}`)

  child.on('error', (err) => {
    console.error(`[sessrumnir] electron failed to start: ${err.message}`)
    process.exit(1)
  })

  // Say how the window ended. A signal death (SIGTRAP, SIGSEGV, SIGKILL) used to leave NOTHING:
  // `code` is null then, and the old handler exited 0 in silence (plan 271 piece 4).
  child.on('exit', (code, signal) => {
    const secs = ((Date.now() - startedAt) / 1000).toFixed(1)
    console.error(`[sessrumnir] electron exited code=${code} signal=${signal || 'none'} after ${secs}s`)
    const sigNum = signal ? (require('os').constants.signals[signal] || 1) : 0
    process.exit(signal ? 128 + sigNum : (code ?? 0))
  })

  // Forward signals
  process.on('SIGINT', () => child.kill('SIGINT'))
  process.on('SIGTERM', () => child.kill('SIGTERM'))
}

launch()
