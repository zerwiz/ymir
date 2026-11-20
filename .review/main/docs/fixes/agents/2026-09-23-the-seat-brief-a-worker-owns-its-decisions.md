## agents · unversioned · 2026-09-23 — the seat brief: a worker owns its decisions and has no human

### Why
- **A worker asked the Allfather a question its own craft should have decided.**
  The `galdr` Eindri, tasked with the Chrome DevTools MCP, blocked on a
  four-option questionnaire addressed to the human:

  > *"Chrome DevTools MCP needs Chrome running with --remote-debugging-port=9222.
  > Your Chromium is running without debug flags. How should we handle this?"*

  The question was wrong on two counts. It was **not the Allfather's to answer** —
  the seat had no route back to Brokk, so it asked the only desk it could reach.
  And it was **within the worker's craft**: the MCP launches its *own* Chrome by
  default (`--userDataDir` default
  `$HOME/.cache/chrome-devtools-mcp/chrome-profile`); `--autoConnect` and
  `--browserUrl` are only for attaching to an already-running debuggable Chrome.
  A seat told to decide would have found that in one `--help`.
- **The mechanism was already named and unused.** `.pi/settings.json` loads
  `npm:@juicesharp/rpiv-ask-user-question` for every pi session; that extension
  opens a TUI questionnaire for whoever is at the terminal and has no coordinator
  mode (its only settings are `collapseKey` and `guidance.*`). A worker pane is
  interactive, so the dialog always finds a human.
- **The loop case is the same failure at speed.** A worker that repeats a
  command that returns nothing is not working; it is gnawing. The seat never said
  so.

### Fix
- **`bin/herdr-run.sh`** — the injected prompt now carries a short **seat brief**
  ahead of the task:
  - You are a worker figure, not the primary.
  - There is **NO human at this terminal**; do **not** use `ask_user_question` —
    no questionnaire from this pane reaches the Allfather.
  - Decide everything inside your craft yourself; that is why you were seated.
  - A genuine fork goes to `state/eindri-reports/<name>.md`; Brokk answers it or
    carries it to the Allfather.
  - **If the same action fails twice, do not run it a third time** — change the
    approach or write down what blocked you. Repeating a command that returns
    nothing is a loop, not work.
- **`bin/mcp-gate.sh`** — restored the executable bit. The gate merged in #127
  without it, so `bin/mcp-gate.sh status` failed with `Permission denied` for
  every caller that ran it as a command rather than through `bash`.

### Verification
- `bash -n bin/herdr-run.sh` clean.
- The brief is injected ahead of the task, so the worker reads the law before the
  errand.
- `bin/mcp-gate.sh` now runs as a command: `status` reports the boot table.

### Files
- `bin/herdr-run.sh`
- `bin/mcp-gate.sh`
