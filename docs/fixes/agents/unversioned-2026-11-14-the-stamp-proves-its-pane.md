## agents · unversioned · 2026-11-14 — the stamp proves its pane, and a child does not inherit one

Plan 275, the stamp fault found at 04:50: a worker's report arrived stamped *"agent Hœnir (the
helm, claude) · herdr pane w39:pT"* when the worker was neither.

### Why

`bin/agents/msg-origin.sh` trusted `HERDR_PANE_ID` unconditionally. A worker started from the
helm's shell **inherits** it, so `msg_origin()` named the helm's pane, looked it up in
`herdr agent list`, and wrote "the helm" — the Allfather read a worker's report as the helm's own
word. Any procedure that spawns from a pane has the same fault, so the fix cannot be "be careful
with the variable".

### What changed

1. **The stamp proves the pane** (`msg-origin.sh`). `_ancestors` walks `/proc/<pid>/stat` upward
   from `$$`; `_pane_pids <pane>` reads `herdr pane process-info` (its `shell_pid` and
   `foreground_processes[].pid`); `_pane_verifies` is true only when one of those pids is an
   ancestor of this process. `_pane_of_self` tries `HERDR_PANE_ID` first, and when it does **not**
   verify it scans the open panes for the one that really hosts us before giving up. No
   verification, no pane in the stamp — it falls through to the terminal or the script, which is
   the truth.
2. **A child does not inherit its parent's pane** (`eindri-start.sh`). The pane IDENTITY
   (`HERDR_PANE_ID`, `HERDR_TAB_ID`) is erased before seating, so no child can wear its parent's
   name; herdr sets the real one in the pane it seats. Deliberately **not** erased:
   `HERDR_ENV` (the "inside herdr" flag `herdr-run.sh` needs to seat at all), the transport
   (`HERDR_SOCKET_PATH`, `HERDR_SESSION`) and `HERDR_WORKSPACE_ID` (where children belong) — a
   fix that breaks the seat is worse than the fault it mends.
3. `bin/agents/eindri-send.sh` no longer records the **sender's** pane as the message's
   destination when the target is an agent name; the `pane` column is the destination or empty.

### Proof

From this worker's own shell, with the helm's pane id forced in:

```
$ HERDR_PANE_ID=w39:pT bin/agents/msg-origin.sh --origin
agent fleet-truth-2 (pi) · herdr pane w39:p0 · heimdall
```

It resolved the pane that actually holds the process (`w39:p0`) and named its agent, not the helm.
The same command with the honest `HERDR_PANE_ID=w39:p0` gives the same line.

### Files

`bin/agents/msg-origin.sh` · `bin/agents/eindri-start.sh` · `bin/agents/eindri-send.sh`.

### Appended 2026-11-14 (same day)

A caller that hands in a FULL origin was stamped twice (`… · heimdall · herdr pane w39:p0 ·
heimdall`); see `unversioned-2026-11-14-a-full-origin-is-not-stamped-twice.md` in this directory.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #759
