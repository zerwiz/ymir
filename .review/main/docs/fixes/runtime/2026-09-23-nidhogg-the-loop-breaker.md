## runtime · unversioned · 2026-09-23 — Níðhöggr: catch a worker that is spinning, not merely alive

### Why
- **Every guard asked "is it alive?"; none asked "is it going anywhere?"** A
  worker in a hallucination loop is still `working` forever, so the liveness
  checks read true while the machine burns. Sýn (`gna-pi-watch.ts`) watches for
  silence, `syn-turnend-guard.ts` fires at a turn end a loop never reaches, and
  `eindri-seen.sh` reads *true* for a looping agent (it has not left `working`).
- **Live proof (2026-09-23).** The `galdr` Eindri, tasked with the Chrome
  DevTools MCP, repeated one command:

  ```
  $ # Let's check if pi has a way to list MCP servers or reload config
    timeout 5 pi mcp 2>&1 | head -20
  ```

  `bin/nidhogg.sh scan` counted **15 identical executions** of it. The pane's
  own meter told the same story: `↑53k ↓18k R10M CH99.9%` — ten million
  cache-read tokens at 99.9% cache hit, the signature of a prompt replayed with
  no progress. The worker was not stuck on a hard problem; it was stuck on a
  *belief* (that `pi mcp` was a door) and nothing existed to tell it otherwise.
- **The belief-loop hides from a command-repeat check.** A second worker,
  `sindri`, spent turns re-deriving the fixes-guard's component matching, which
  the guard answers in one line (`bin/fixes-guard.sh:105-112` — it exits 0
  either way, warning and never blocking). Reasoning in circles repeats no
  command, so a stall signal is needed beside the repeat signal.

### Fix
- **`bin/nidhogg.sh`** — Níðhöggr, the gnawer at the root. The serpent gnaws
  Yggdrasil forever and accomplishes nothing; this names the endless loop and
  breaks it. Three verbs:
  - `scan [--threshold N] [<agent>...]` — for every seated agent (or the named
    ones) read the pane with a generous `--lines` window (the default read shows
    only the recent tail, and a loop's repeats scroll out of it), extract the
    command lines, count repeats, and fingerprint the pane's tail. A repeat at or
    over the threshold, or an unchanged fingerprint while the worker is
    `working`, trips the verdict. **Exit 3 is the trip signal** — the same
    convention `eindri-seen.sh` uses for its condition half.
  - `break <agent> [--message "…"]` — rung 1 of the ladder: interrupt (`esc`)
    then steer with a message that names the loop and asks for the one action
    that changes state. Never destructive, never silent.
  - `watch [--interval N] [--break]` — scan on a cycle, optionally auto-steering.
- **Thresholds resolve from config with one documented default (Rule 07):**
  `LOOP_REPEAT_N` (3), `LOOP_STALL_TURNS` (2), `LOOP_POLL_SECONDS` (20),
  `LOOP_READ_LINES` (500). No literal in the logic.
- **State lives outside the tree (Rule 04):** fingerprints under the operator's
  hoard state dir (`$YMIR_STATE_DIR/.nidhogg/`), resolved through
  `bin/hoard-lib.sh`, never beside the script.
- **Named in the platform map** (`.agents/assets/agents/naming.md`):
  `"Hallucination loop breaker","Níðhöggr"`.

### Verification
- `bash -n` clean.
- Live: `bin/nidhogg.sh scan` against the seated fleet reported
  `"galdr","done",15,3,"LOOP — the same command ran 15 times", …` and exited 3.
- No false positive: a scan of an actively-working agent (its pane moving)
  stayed `clean`, so the stall signal does not fire on healthy progress.

### Files
- `bin/nidhogg.sh`
- `.agents/assets/agents/naming.md`
