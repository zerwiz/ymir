# Soak an app for leaks

## What it is

`bin/gates/soak.sh <app>` raises one Ymir app from the pinned runtime, measures it while it works, and says
whether it leaks. It is the harness behind plan 286: a leak found by accident at midnight becomes a number in a
file.

It measures six things a running app can take and never give back: memory (whole process tree and the main
process alone), the renderer's JS heap after a forced garbage collection, file descriptors, inotify watches,
child processes, and GPU memory. It also records what a person actually feels: main-thread tasks longer than
200 ms, the compositor's "not responding" dialogs, and how hard the main process works during its first
fifteen seconds.

Every measurement is one JSON row on a ledger:

```
$YMIR_HOME/state/soak/<app>/<date>.jsonl
```

When a number grows past its budget, the soak takes a heap snapshot, a sampling heap profile and a 10-second CPU
profile, and names the largest allocating call sites and the hottest functions — the method that found
Sessrúmnir walking 198 worktree checkouts on its main thread.

## What you need

- The pinned runtime: `~/ymir-runtime` must point at a release. An app is **never** soaked from a working
  checkout (RULES/51).
- A desktop session. The soak drives the real window through DevTools; there is no headless mode.
- A free desk: while `bin/desk/in-call.sh holder` names a call, the soak refuses to raise anything.

## Do it

```bash
bin/gates/soak.sh --list                 # every app and server, with its fixed DevTools port
bin/gates/soak.sh sessrumnir             # the full soak: 20 passes, 30 min idle, a sample every 30 s
bin/gates/soak.sh hlidskjalf --cycles 20 --idle 1800
bin/gates/soak.sh smidja --quick         # the gates' short soak: 5 passes, 90 s idle
bin/gates/soak.sh sessrumnir --root ~/.local/share/ymir/releases/<sha>   # an older build, for before/after
bin/gates/soak.sh hlidskjalf-gate        # a server, measured where it runs
bin/gates/soak.sh --status               # the budgets, the desk, and which apps answer right now
```

The apps and their fixed loopback DevTools ports are one registry: `hlidskjalf` 9311, `smidja` 9312, `odrerir`
9313, `sessrumnir` 9314, `bilskirnir` 9315, `rodd` 9316. The servers are measured where they listen
(`hlidskjalf-gate` 3889, `hlidskjalf-spa` 3888, `smidja-server` 8437, `odrerir-server` 4322,
`bilskirnir-server` 8787).

Exit codes: `0` the soak stayed inside budget, `1` a leak, `2` usage, `3` the app could not be raised or
attached, `4` the desk was in a call.

## The budgets

They come from plan 286 section 5, and each one can be set in `$YMIR_HOME/config/soak.yaml`:

| Measure | Budget while idle | Budget after the passes |
|---|---|---|
| RSS the app never gives back | under 5 % | under 10 % |
| JS heap after a forced GC | under 2 MB | under 5 MB |
| File descriptors | flat (a step of 2 is churn; a count that keeps rising is a leak) | | 
| inotify watches | flat, and nothing held open inside `.yggdrasil/`, `node_modules/` or `.git/` | |
| Child processes | flat, and no zombie | back to the baseline |
| Main-thread task | none over 200 ms | none over 1 s |
| Not-responding dialogs | zero | |
| Main process at boot | not pegged at 90 %+ CPU for 6 s or more, and under 900 MB | |

A leak is what the app never gives back, so the cycle budgets are judged on the lowest reading the app returns
to after the passes — a renderer being torn down is not a leak. A descriptor or watch count that stops rising
is a bounded step, not a leak: the count must not fall across the last three passes.

## Limits

- It raises **its own** instance in a throwaway profile and closes exactly what it raised. An app already open
  whose runtime cannot give the soak a separate profile is a named **skip**, never a restart: the soak does not
  close a window the Allfather has open.
- It refuses to start while a call is held on the desk.
- It does not fix anything. A leak is reported with its numbers and its retaining path; the fix is its own
  change.
- Inotify watch **paths** are not readable from `/proc`. The soak counts watches and reports the directories an
  app holds open; a watcher that opens no directory is caught by the count.
- A heap snapshot is tens of megabytes. Snapshots live under `state/soak/<app>/artifacts/` (git-ignored) and the
  last three per app are kept.

## If it does not work

- `no DevTools on :93xx in 60 s` — the app did not open its door. Read `state/soak/<app>/raise.log`; the app's
  own launcher usually says why. An app that needs a window the session cannot give it (no display) cannot be
  soaked.
- `the door answers and lists no page` — the app opened Chromium's internal page only; wait for its window.
- `the desk is in a call` — nothing is raised while a call is held. Ask again after the call.
- The soak raised the app and the window was gone in seconds — that is the freeze the harness exists to find;
  the boot rows in the ledger hold the CPU and memory at the moment it happened.
- No row appeared on the ledger: check `$YMIR_HOME/state/soak/<app>/` is writable.

## CHANGE LOG

- **2026-11-14** — written with the harness (plan 286 P1, P2, P5): `bin/gates/soak.sh`, the DevTools driver, the
  budgets, and the short soak the delivery gate runs for an app a pull request touches.
