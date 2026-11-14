# gates · 2026-11-14 · The soak raises one app and names its leak

## What

`bin/gates/soak.sh <app>` — plan 286 P1, P2 and P5. It raises one app from the pinned runtime on that app's
fixed loopback DevTools port (9311–9316, plan 275 item 19), takes a baseline, drives every page of the app N
times, lets it idle, samples every 30 s, and judges every number against the budgets in plan 286 section 5.

`bin/gates/soak/cdp.mjs` is the driver: one Chrome DevTools client written on node's own `net` and `crypto`
(no dependency added to the house), one `/proc` measurement used for both apps and servers, one judge.

`bin/gates/soak-pr.sh` is P5: a pull request that touches an app runs that app's short soak. It is wired into
`bin/gates/ci-verify.sh` (gate `soak-apps`), and `bin/gates/tests/test_soak.sh` is wired as gate `soak-judge`.

Every measurement is one JSON row on `$YMIR_HOME/state/soak/<app>/<date>.jsonl`; a leak also writes a heap
snapshot, a sampling heap profile, a 10 s CPU profile and the largest allocating call sites.

## Why

Tonight the house paid for leaks it never measured, and each was found by accident (plan 286's opening). A leak
must be a number in a file with a retaining path beside it, and the person who finds one must not have to
re-invent the method each time.

## The fix, and the two things measuring found about measuring

1. **A ledger per app per day holds every run of that day**, so a judge read its neighbours' rows: the first
   `--judge-only` over Sessrúmnir's ledger judged 10 boot rows from two different runs and reported a freeze
   from a run that had passed. Every row now carries a `run` id and a judge reads only its own run.

2. **Closing a browser from below crashes it.** The first version of the close path killed the process tree
   deepest-first. Eleven app closes produced eleven `SIGTRAP` cores: Chromium relaunched its GPU process, the
   relaunch failed three times (`GPU process launch failed: error_code=1002`), and the browser aborted with
   `FATAL:content/browser/gpu/gpu_data_manager_impl_private.cc:416] GPU process isn't usable. Goodbye.` — for a
   window that was only being closed, and with an Omarchy crash notification each time. The close path now sends
   SIGTERM to the **main process first** and lets the browser shut its own children down; the next full soak
   closed the app and dumped no core. (25 such cores existed on this machine in the two days before this fix, so
   the pattern predates the harness — any script that kills an Electron app's children before its browser
   produces one.)

3. **A leak is what the app never gives back.** The cycle budgets first fired on the peak five seconds after the
   last reload — a teardown still in flight (Sessrúmnir measured 17.89 %, then 9.47 % on the same build). They
   are judged on the lowest reading the app returns to after the passes. Likewise a descriptor or watch count
   that appears once and stops is a bounded step (a stream armed on first use, a watcher re-armed after a
   reload); the count must not fall across the last three passes to count as a leak.

4. **A baseline taken while the app is still arming measures the arming.** Sessrúmnir starts its first file walk
   2.5 s after the window answers. The baseline waits for two equal readings of fds, watches and children.

5. **The boot window is measured before DevTools is asked for anything.** A frozen main thread cannot answer a
   DevTools handshake; the first fifteen seconds are sampled from `/proc` first, then the driver attaches (with
   a retry, because a frozen window answers `/json/version` and stalls `/json/list`).

## Proof

The errand's report, `$YMIR_HOME/state/eindri-reports/leak-soak.md`, has the tables. The two halves of P1, on
the same machine, same launcher, same cycles:

- the pre-fix release (`babae37aa7b8`): **358,853** inotify watches, main process 933 MB during boot (tree
  1.35 GB), 4 of the first 5 three-second boot samples at 90 %+ CPU, DevTools itself stalled past its timeout.
- the pin (`4f5f6b13ac8a`): **5,947** watches, every budget inside its limit, verdict PASS.

The judge itself is proved without a window: `bin/gates/tests/test_soak.sh`, sixteen checks — a growing soak
fails, a flat soak passes, a bounded step is not a leak, a pegged boot is, and a judge reads only its own run.

## Still owed

Plan 286 P3 (the fixes a soak names) and P6 (the Health view). The pin does not yet carry
`YMIR_APP_USER_DATA_DIR` (see the desktop note of the same date), so an app that is already open — Hlidskjalf
on this machine — is a named skip rather than a second instance.
