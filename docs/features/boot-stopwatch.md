# The boot stopwatch

## What it is

A stopwatch for the Ymir desktop apps. It measures the three things you actually feel when you click an icon:

1. **click → window mapped** — how long until the app's window appears on screen.
2. **window → first answer** — how long until the app has actually answered. A white window is not an answer.
3. **still up, no dialog** — whether the window is still there afterwards, and whether Hyprland raised its
   "Application Not Responding" dialog.

It measures the real window, not a guess: it asks the app's own Chrome DevTools door (over loopback) whether the
page is ready and has painted anything.

Every run is written to a ledger, so a slow boot has a number instead of a feeling.

## What you need

- A graphical Linux seat with Hyprland (the stopwatch asks the compositor for the window).
- The apps themselves — `bin/desktop/shortcuts.sh` puts `ymir-app` on your PATH, which is what the stopwatch clicks.
- Nothing else. No model, no network, no secret.

## The commands

```bash
boot-stopwatch.sh --list                      # every app, its window class, its DevTools port, its budgets
boot-stopwatch.sh smidja                      # time one app (cold: it restarts the app first)
boot-stopwatch.sh --smoke                     # every app in turn, each against its own budget
boot-stopwatch.sh hlidskjalf --watch 300      # the five-minute proof: watch for a not-responding dialog
boot-stopwatch.sh --list --json               # the same table for a script
```

Each app has a **budget** — the point past which a click feels ignored. A run fails when the window is late, the
answer is late, a not-responding dialog was raised, or the app died inside the watch.

The also-useful flags: `--warm` measures raising an app that is already running. `--timeout` bounds the wait for a
window or an answer.

## The two laws it obeys

**The desk belongs to the operator.** A cold boot is a restart, so it only happens while no call is being held
(`bin/desk/in-call.sh holder` prints nothing). While a call is live the stopwatch refuses, and names who holds the
microphone.

**A window he has open is not restarted on a worker's word.** Asking for a cold boot of an open app is refused, and
the refusal prints the one line to send the helm. Say `--yes` after the helm has answered.

## The DevTools doors

Every Ymir app answers on its own fixed loopback port, always, whether or not anyone is watching:

| App | Window class | DevTools port |
|---|---|---|
| Hlidskjalf | `ymir-hlidskjalf` | 9311 |
| Smíðja | `ymir-smidja` | 9312 |
| Óðrerir | `ymir-odrerir` | 9313 |
| Bilskirnir | `ymir-bilskirnir` | 9314 |
| Rödd | `ymir-rodd` | 9315 |
| Sessrúmnir | `ymir-sessrumnir` | 9316 |

The table lives in one place, `bin/desktop/app-lib.sh`. You can look into any window without restarting it:

```bash
node bin/desktop/devtools.cjs targets 9312     # what the window is showing
node bin/desktop/devtools.cjs ask 9312         # is it ready, and has it painted?
```

Any DevTools client can attach to `http://127.0.0.1:9311` and so on. The doors are loopback only.

## Limits

- Linux and Hyprland only, for now. The window timing is the compositor's answer.
- The dialog check reads the house's own signal tracer (`browserkill-trace`); with that unit stopped, a dialog is
  only caught while it is still on screen.
- The watch is wall-clock time: `--watch 300` spends five minutes per app, so `--smoke --watch 300` is a long run.
- A window that presents the wrong class is found anyway, and the mismatch is printed as a warning — but the app
  should present the class the table names.

## If it does not work

| What you see | What it means |
|---|---|
| `refused: <name> holds the microphone` | You are in a call. Wait, or run it after. |
| `refused: <class> is open — tell the helm first` | The app is open. Send the printed line to the helm, then add `--yes`. |
| `no <class> window in Ns` | The app never mapped. Read the log the row names (`~/.local/state/ymir/boot-<app>.log`). |
| `no answer in Ns` | The window is up but its page never answered — the app's own server is probably down. |
| `presented its window as "<other>"` | The window class disagrees with the table; the app's name needs fixing, not the stopwatch. |

## CHANGE LOG

- 2026-11-14 — written with the stopwatch itself (plan 275 item 10): the three measurements, the two refusals, the
  DevTools table, and the limits.
