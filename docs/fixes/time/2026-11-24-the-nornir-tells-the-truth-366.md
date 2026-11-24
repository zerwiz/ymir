# The Nornir tells the truth: the brief, the run record, the panel counts, and the release build reads the remote

Date: 2026-11-24 · Component: time (Nornir) and engine (release) · Plan 366

## What changed

- **The brief.** The daily briefing writes a `nornir:` line from `bin/time/nornir-status.sh`, built by the machine that writes the brief. It reads its own jobs first, fetches the other seats' rows itself, and names the seat on each trouble row. Nothing waits on the heart.
- **Every run is recorded.** The scheduler now logs a `cron done` row for each run, with the exit code, the seconds and the seat, beside the existing `cron run` row. The resolver ignores it for status and `nornir-cron-start.sh --last` skips it.
- **The panel's counts mean one thing.** `Servers up n/m` counts only seats that are reachable with a running scheduler, and the line under it names each seat left out and why (scheduler stopped, unreachable).
- **A killed scheduler shows within two minutes.** The resolver caches a seat for 60 seconds and the panel refreshes every 60, so a stopped heart scheduler shows DOWN on the panel, `ymir nornir` and Eir within that window.
- **`release.sh build` reads the remote.** `--ref main` now means `origin/main` (tried before a local `main`, which on the runtime lagged a day and rebuilt `e5ebd388`), a failed fetch is said and no longer swallowed, and `--from` accepts a URL by keeping one bare mirror under the releases folder.

## Not changed

The six jobs said to have no run (`private-scan`, `running-inventory`, `registries-refresh`, `registry-check`, `tunnels-registry`, `brief-watch`) did run on the heart; the log the operator read was the abandoned default one. Their evening or second runs were the stamp bug fixed in plan 365.

Proof: `python3 tests/test_nornir_status.py` and `bash tests/test_release_ref.sh`.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #928
