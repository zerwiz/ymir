## desktop · 2026-11-14 — the boot stopwatch, and a DevTools door every window always opens

### Why

The Allfather: *"we need to do the boot faster and better of the apps"* · *"audit the boots"* · *"can we make the
boots faster in anyway and more stable"*, and *"we need to have devtools attached to all agents harnesses"*.
An audit by eye cannot name the second a window took, so nothing was ever proved: Smíðja, Óðrerir and Bilskirnir
were seen to close within 30 s of a launch at 02:35 and the cause was never found, because there was no record.
An app's DevTools port only existed when someone remembered to export `YMIR_DEVTOOLS_PORT` **before** starting it,
so a fault noticed after the fact could only be looked at by restarting — which destroys the fault.

### What was measured before the change

Cold boots on this machine, each app stopped first, one at a time, with the desk free (2026-11-14 ~03:00–04:00 CET):

| App | click → window | window → answer | what the number was made of |
|---|---|---|---|
| Smíðja | 2.17 s | 0.27 s | one Electron start; already inside budget |
| Óðrerir | 2.02 s | 0.35 s | one Electron start; already inside budget |
| Bilskirnir | **20.39 s** | 0.26 s | `setup.sh` re-ran on every start (3.9 s) + Nanna's gateway raised (8.9 s) + the hall's server (4.5 s) + the window (2.4 s) |
| Rödd | **~69 s** | — | `voice-door.sh which-host` probing over ssh (10.4 s) + the voice host raised (~40 s) + a fixed `sleep 14` before reporting |

### What changed

| Place | Before | Now |
|---|---|---|
| `bin/desktop/boot-stopwatch.sh` | did not exist | the stopwatch: click → window, window → answer, still up, no dialog, a budget per app, a ledger line per run, and two refusals (a live call, an open window without `--yes`) |
| `bin/desktop/devtools.cjs` | did not exist | the instrument: `targets` and `ask` over the Chrome DevTools Protocol, loopback only, no dependency (node's own `fetch` + `WebSocket`) |
| `bin/desktop/app-lib.sh` | no DevTools knowledge | `app_devtools_port` — one table, one fixed loopback port per app (9311–9316), with `app_devtools_url` and `app_devtools_surfaces` |
| `scripts/electron.sh` | opened DevTools only when `YMIR_DEVTOOLS_PORT` was set | always opens the app's own port; `YMIR_DEVTOOLS_PORT` still wins for a one-off probe |
| `apps/bilskirnir/start.sh` | same, via `BILSKIRNIR_DEBUG_PORT` | always opens port 9314 |
| `apps/rodd/start.sh` | default `9222` | always opens port 9315 |
| `bin/voice/voice-door.sh` · `resolve_host` | walked `fleet.json`'s ear seats over ssh, 5 s per silent seat | the first ear seat IS this seat → answered with no network; never ssh to self |
| `apps/rodd/start.sh` | a fixed `sleep 14` after raising the window | polls for the window, and it is the click that waited |
| `apps/rodd/src/main.js` | no `app.setName` — the window presented `zerwiz-rodd` (its package name) | `app.setName('ymir-rodd')`, so the window, the routing table, the `.desktop` and `ymir-app`'s "open where you click" all agree |

The stopwatch exports `YMIR_DEVTOOLS_PORT` for the app it launches, which is the SAME value
`app_devtools_port` resolves — so it measures correctly on a tree that has not yet taken the always-on change, and
reads a wired app as a redundant confirmation rather than a second opinion.

**Rödd's window class was a real fault, not a curiosity.** `bin/desktop/app-lib.sh` is the one source of truth for
routing (window rules, `.desktop` `StartupWMClass`, `ymir-app`'s desktop-follow), and all of it said `ymir-rodd`
while the window itself said `zerwiz-rodd`. So no rule for Rödd could ever match, and the "open where you click"
watcher waited thirty seconds for a window it had already missed. The stopwatch finds a window whose class merely
ends in the app's name anyway, and prints the disagreement, so a rename can never again make an app invisible.

### Proof

- **The instrument, on a real window.** Smíðja raised from this worktree with **no** `YMIR_DEVTOOLS_PORT` in the
  environment listened on `127.0.0.1:9312` (loopback, `ss -ltnp`), and
  `node bin/desktop/devtools.cjs ask 9312` answered
  `{"ok":true,"ready":"complete","painted":true,"nodes":1,"chars":1404,"title":"Smíðja — Trace","url":"http://127.0.0.1:8437/"}`
  — the page's own title, from the page itself.
- **The stopwatch on every app but Sessrúmnir** (its own worker holds it): the table above, then
  Smíðja cold `2.17 s / 0.27 s` and Óðrerir cold `2.02 s / 0.35 s` as passes, plus Hlidskjalf run with a
  five-minute watch. A cold boot with the window already open is refused (exit 4) and prints the helm line; a cold
  boot while a call is held is refused (exit 3) naming the holder.
- **The Rödd class fix** cannot be proved through her own `start.sh` on this machine yet — she hands over to the pin,
  which carries the old `main.js` — so it is proved by the instrument failing honestly: the cold boot reported
  `presented its window as "zerwiz-rodd", not "ymir-rodd"`, which is exactly the warning this fix removes.
- **`voice-door.sh which-host`: 10.44 s → 0.25 s** on this machine (measured before and after the change, same
  machine, same fleet file).
- **Bilskirnir's stale setup check** is its own note: `docs/fixes/bilskirnir/2026-11-14-a-current-install-starts-without-setup.md`.

### What is owed, and was not cut

- Rödd's voice host still takes ~40 s to raise before her window appears. Reordering the window ahead of the engine
  changes what she shows while she is silent, and that is a behaviour change, not a boot fix — it needs the
  Allfather's word.
- Bilskirnir's gateway remains ahead of her window because her server asks the gateway for state at boot; the ~9 s
  is Hermes starting, not this app's script.
- Sessrúmnir's freeze is measured by its own worker; the stopwatch covers it as soon as its registry row is used
  (`--list` names 9316).

## CHANGE LOG

- 2026-11-14 — written with the change; measurements taken the same night on this machine.

## Appended 2026-11-14 — the three slow boots cut, and the instrument that now says what a renderer does

The Allfather's word: *do all needed fixes.* The stopwatch's three failures are cut below, each measured before and
after on this machine, each cold boot taken with the desk free (`bin/desk/in-call.sh holder` empty) and announced to
the helm first.

| App | Was | Now | What was cut |
|---|---|---|---|
| Hlidskjalf | 9.46 s window→answer (white window) | first paint in 972–1492 ms; launch→painted median 5070 → **3262 ms**, worst 13559 → **3299 ms** | the `return null` that waited on `/api/session`, and 21 eagerly imported gate pages turned into on-demand chunks — see `docs/fixes/hlidskjalf/2026-11-14-the-window-answers-while-the-gate-is-asked.md` |
| Bilskirnir | server answered in 3.7 s (tsx) | **1.5–2.7 s** (built) | `npx tsx src/index.ts` on every start → `tsc` once into `server/dist` and `node dist/index.js` after; refreshed only when a source file is newer than the built entry. Measured: tsx 3708 / 3649 ms, built 4937 (cold cache) / 2652 / 1535 ms; the one-off build is 22.8 s and never repeats until the sources move |
| Rödd | engine raised in **39.6–52.7 s** | **33.9 s cold cache, 28.3 s warm** | `CUDA_MODULE_LOADING=LAZY` on the voice host: the engine's import initialised every CUDA module before it could answer. Same command, same card, two pairs in opposite order: 52.7 → 33.9 s and 31.6 → 28.3 s. `YMIR_VOICE_CUDA_MODULE_LOADING=eager` restores the old path, named |

`bin/desktop/devtools.cjs` gained **`perf <port>`** for this work: the renderer's navigation timings, its paint
marks, every resource it fetched and the slowest twelve, all read from the page itself. That is how "the window is
white for nine seconds" became a number and a list of what happened in the meantime.

### Closed after testing

Everything this work started was closed and checked: the two Hlidskjalf measurement windows (each with its own
`--user-data-dir` under `/tmp`), the `vite preview` on `:3898`, the Bilskirnir timing servers on `:8799` and the
voice-engine A/B runs on `:8898`. `ss` shows none of those ports listening and `ps` shows none of those processes
alive. What was open before the work is open after it: Hlidskjalf and Óðrerir (re-raised after a release flip by
another hand closed them), and the voice host, which the A/B measurement stopped and which was raised again through
`bin/voice/voice-door.sh host --now` and answers on `:8890`. Sessrúmnir was open when the errand began and was not
touched: its own worker holds it.
