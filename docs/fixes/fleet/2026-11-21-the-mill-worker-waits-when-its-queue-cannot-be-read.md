# The mill worker waits when its queue cannot be read

**Component:** fleet (`tools/mill/worker.sh`, deployed as `~/.fleet/mill-worker.sh`) · **Date:** 2026-11-21

## What was wrong

The worker's loop read its queue like this:

```bash
job="$(command -v redis-cli >/dev/null && timeout 300 redis-cli --raw blpop "$Q" 300 … || true)"
[ -n "${job:-}" ] || continue
```

When `redis-cli` is missing, the first test fails at once, `job` is empty, and the loop runs `continue` with no wait.
The heart has no `redis-cli`, so the worker spun there for six days. Its unit reported 6 days 5 hours of CPU time
and the process held about 37 % of a core, on a machine whose load was already above 3.

A redis that refuses the connection spins the same way, because `redis-cli` exits at once.

## What changed

- With no `redis-cli`, the worker says so **once** in its journal, then sleeps `MILL_IDLE_SECONDS` (default 60)
  between tries.
- When `redis-cli` fails within five seconds, that is treated as an unreachable redis rather than an empty
  queue. It is said once, and the worker sleeps the same way.
- When the queue answers again, the worker says so once and carries on.
- An empty `blpop` that waited its full 300 seconds is still an empty queue and loops straight back, as before.
- The job classes and their work are unchanged.

## How it was proved

- `.agents/tests/mill-worker-idles.test.sh` runs the real worker with a stand-in PATH. It checks that both failure
  roads print one line and take a few loop turns in four seconds rather than thousands. It also checks that a job
  from a working queue is still dispatched by its class.
- On the heart the fixed file replaced `~/.fleet/mill-worker.sh` (the old copy kept as `mill-worker.sh.bak-<date>`).
  After `systemctl --user restart mill-worker`, the process measured 0.0 % CPU and logged
  `queue mill:jobs unreadable (no redis-cli on this machine) — waiting 60s between tries; said once`.

## What is still open

Nothing in this tree feeds `mill:jobs` today, so the worker idles by design until a queue is given to it. Whether the
heart should carry `redis-cli`, or the mill should use the house's own queue door, is a separate choice.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #869

## Addendum — the review's mends (PR 869, appended 2026-11-21)

The review returned three items. The text above stays as the record; this section corrects it.

**The error check read the job.** The first version judged a failed read by grepping the whole reply, and the
reply includes the job that `blpop` had already removed from the queue. A job whose text said "Connection
refused" was taken for a down redis and lost. The read is now judged by the exit code and by the reply's first
line only. That line is the queue's key when a job was popped, and empty when the 300-second wait ran out.
Any other first line is an error reply, so a `NOAUTH` from an older `redis-cli` that exits 0 now waits too.

**Stderr was merged into the reply.** The first version captured `2>&1`, so a warning on stderr could shift the
job off the line it is read from. Stderr now goes to its own file, and is used only for the journal line.

**"The job classes and their work are unchanged" was false** while the first two faults stood. With both
mended, it holds: the test proves a plain job, a job that says "Connection refused" and a job read past a
stderr warning are each dispatched by class.

The test now has nine checks. The three new cases fail on the first version and pass on this one.

> [!WARNING]
> **The deploy above is unverified.** The 0.0 % CPU and the log line under "How it was proved" are the first
> worker's own report, and no judge has measured them. A re-measure from the dev machine on 2026-11-21 failed:
> ssh to the heart timed out on both of its addresses. The heart's copy also predates these mends. Before this
> note can call it measured, redeploy `tools/mill/worker.sh` to the heart, restart `mill-worker`, and record
> the process CPU and the journal line here.
