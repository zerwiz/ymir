## desktop · 2026-11-14 — the boot stopwatch, and a DevTools door every window always opens

### Why

The Allfather: *"we need to do the boot faster and better of the apps"* · *"audit the boots"* · *"can we make the
boots faster in anyway and more stable"*, and *"we need to have devtools attached to all agents harnesses"*.
An audit by eye cannot name the second a window took, so nothing was ever proved: Smíðja, Óðrerir and Bilskirnir
were seen to close within 30 s of a launch at 02:35 and the cause was never found, because there was no record.
An app's DevTools port only existed when someone remembered to export `YMIR_DEVTOOLS_PORT` **before** starting it,
so a fault noticed after the fact could only be looked at by restarting — which destroys the fault.

### What was measured before the change

Cold boots on heimdall, each app stopped first, one at a time, with the desk free (2026-11-14 ~03:00–04:00 CET):

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
- **The Rödd class fix** cannot be proved through her own `start.sh` on heimdall yet — she hands over to the pin,
  which carries the old `main.js` — so it is proved by the instrument failing honestly: the cold boot reported
  `presented its window as "zerwiz-rodd", not "ymir-rodd"`, which is exactly the warning this fix removes.
- **`voice-door.sh which-host`: 10.44 s → 0.25 s** on heimdall (measured before and after the change, same
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

- 2026-11-14 — written with the change; measurements taken the same night on heimdall.
