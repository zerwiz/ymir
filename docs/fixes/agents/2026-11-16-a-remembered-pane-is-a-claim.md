# Fix — a remembered pane is a claim, and the wake queue is the floor

**What was wrong.** Seven errands finished on 2026-11-16 and **every one of them** ended with the same line:

> *pane delivery FAILED — herdr refused the turn for pane w2:p3 (owner 2286)*

`w2:p3` was the helm's pane before the box rebooted at 04:00. The arm's own state still named it, so the notify door
aimed a turn at a ghost, herdr answered `agent_not_found`, and the door exited non-zero. The reports themselves were
safe — the wake was already in `state/.wake-queue` by then — but the house read seven "FAILED" lines for news that had
arrived, which is exactly the kind of noise that teaches a reader to ignore the word failed.

**What was done, in the door that speaks.**

1. **A recalled pane is proved before it is spoken to.** Any pane that comes from a remembered source — the `--pane`
   argument, `state/.arm.pane`, the lease's session — is checked against `herdr agent list`; if no agent stands there the
   id is **discarded**, the door says so by id, and resolution runs again from live state. A ghost is never spoken to.
2. **The wake queue is the floor, so reaching it is a success.** A chat injection that cannot happen is a lost
   convenience, not a lost message: the door now exits **0** with a line that says the line is queued and the injection
   did not happen. Seven errands no longer report a delivery failure for a delivery that landed.

**Proof.** `bin/gates/tests/test_notify_stale_pane.sh` — a stub `herdr` that answers one live pane and nothing else:
a run with no pane exits 0 and names the queue; a run carrying the `w2:p3` ghost discards it, names it by id, and still
exits 0. Six assertions, no herdr server, no tmux, no network.

**Not mended here, named:** the arm still records the helm's pane when it starts. That is correct — it is how a live
turn is aimed — and the door now treats the record as a claim rather than an order, which is the property that matters
across a reboot.
