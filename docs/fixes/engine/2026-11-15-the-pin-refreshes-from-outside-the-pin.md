# Fix — the pin could not refresh itself, and a missing row read like a broken one

**What was wrong, measured 2026-11-15 05:37 EET.** A cron alarm reached the Allfather's phone:
`bin/records/gimle-tunnels-check.sh --quiet` exited **127** with **no output**. The job was innocent — run by hand it
answered *"gimle-tunnels: 7 up · 0 failing"*, rc 0.

The tree the scheduler stands in was the fault. `nornir.service` runs
`~/ymir-runtime/bin/time/nornir-cron-start.sh` — the pinned runtime of plan 269 — and that pin stood **75 commits behind
`origin/main`**. Every row whose script was added or moved after the pin froze answered *"No such file or directory"*:

```
213 failing runs of 470 logged runs
16 distinct rows
28 distinct days, first 2026-10-12T21:00Z (git-sync), last 2026-11-15T03:30Z (the tunnel check)
```

The dead rows were the heart's own record work: the daily briefing, the observer, git-sync, memory housekeeping,
nsr-compliance, forgejo-git, well-vault-sync, hall-snapshot, the tunnel checks, the registry refreshes and the
eindri-handoff sweep.

**Why it could never mend itself.** The pin is refreshed by `bin/engine/runtime-seat.sh`, which Gróa's update step calls
— and on the heart the update runs **from the pin**, because the scheduler runs there. A pin that froze before that step
existed could therefore never be brought forward by anything the house had: the only code that could refresh the pin
was the frozen copy of itself. That is a deadlock, not slowness.

**What was done.**

1. **`bin/engine/pin-refresh.sh`** — the refresher, and it refuses to live inside what it refreshes. `--check` answers
   anywhere (a question about the pin is always fair) and exits 3 when the pin is behind, absent or unreadable. The
   apply path fetches and fast-forwards the pin to `origin/<branch>`, and **exits 4 with a named refusal when this
   script's own root IS the pin** — a refresher seated in the thing it refreshes proves nothing, because a stale copy
   is what runs. Local edits are reported and never pre-empted; when an incoming commit *would* overwrite one, git
   refuses the merge and the door says so (exit 5), so a schedule never overwrites a decision.
2. **`bin/time/saga-session-start.sh`** runs it in a new **PIN** section, before the scheduler section. A session starts
   from the working tree, which is a tree that can legitimately bring the pin home.
3. **`bin/time/cron-fail-lib.sh`** — the one sentence a failed row gets, read by both scheduler branches through **one**
   `run_row` body (they had been two copies of the notifier, and the copies could drift). rc **127** now reads
   *"not found: `<path the shell actually looked for>` — the row ran from `<home>`; that tree is stale"*, rc **126**
   reads *"not executable: `<path>`"*, and any other exit names its code instead of claiming "no output".
4. **`bin/agents/eir-doctor.sh`** — the `runtimepin` surface also asks `pin-refresh.sh --check`. The units pointing at
   the pin says nothing about the pin being current; that is exactly the green that hid this for 28 days. A stale pin
   is a red surface now, and its mend runs the refresher (which refuses honestly when Eir itself is seated in the pin).

**Proof.** `bin/gates/tests/test_pin_refresh.sh` — 21 assertions against a throwaway origin, pin and working tree: the
current pin is green; a pin behind main is red and says how far; the door **refuses from inside the pin and leaves the
pin where it was**; the working tree brings it home and logs the move; an untouched local edit does not block and
survives; a conflicting one stops the refresh at rc 5 and survives too; and the four sentences of `cron_fail_detail`
(127 found/not-found, 126, a real failure's tail, a silent failure's exit code).

**One thing this does not mend, named so it is not lost.** The heart's pin carries a modified `.opencode/agents/brokk.md`
and four untracked agent cards — the seat renderer writes into the tree every unit runs from. The pin should be
read-only; until it is, the door reports those edits on every run rather than pretending the pin is clean.
