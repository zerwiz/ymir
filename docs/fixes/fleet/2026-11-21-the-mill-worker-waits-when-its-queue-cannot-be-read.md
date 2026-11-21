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
