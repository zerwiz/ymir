# The Health view — every service and app, measured

## What it is

A panel on **Hlidskjalf's Runtime page** that answers one question per row: is this service or
app **holding**, does it **grow**, or does it **restart**?

It reads two records that already exist on your machine and draws them for a person:

- the **leak ledger**, which measures every house service every five minutes — memory, file
  descriptors, inotify watches, child processes, GPU memory and restarts;
- each app's **last soak**, from raising it, driving its pages and letting it idle.

Every verdict is judged by the budgets in **plan 286 §5**, and every row names the number that
broke its budget, so you can check it rather than trust a colour.

## What you need

- Ymir installed, with the leak ledger running on this machine (the `ymir-soak.timer` user
  timer). Without it the page says the ledger has not moved and why.
- Hlidskjalf raised (`scripts/start.sh`, or the desktop icon).

## Do it

Open **Hlidskjalf → Runtime**. The Health section sits below the releases and shows three panels.

**The ledger's state.** The newest pass, how long ago it landed, and how many passes there are.
If it has not moved for more than three sample intervals, a warning says the timer is likely
stopped. The budgets themselves are behind the **the budgets** button.

**Services.** One row per unit this machine measures:

| Column | What it says |
|---|---|
| the unit's name | the service, without `.service` |
| the reason | the budget that broke, or "inside every budget" |
| RSS | memory now, and its growth over the window |
| fds · watches · children | now, and the change over the window |
| GPU · restarts | memory on the card, and restarts now (and inside the window) |

**Apps — their last soak.** One row per app in the registry. An app with a soak shows the
harness's verdict and its numbers; an app with no soak yet says so and carries the sampler's last
reading of it.

**Stopped by the restart ward.** A unit the ward stopped for restarting too often, with its last
error and the count.

**The three verdicts.**

- **holds** — every budget is inside its bound.
- **grows** — something climbed past its bound: RSS, the JS heap, file descriptors, inotify
  watches, children, a main-thread task too long, or a not-responding dialog.
- **restarts** — the unit restarted past its bound, or the ward stopped it.
- **unknown** — not enough to judge. A row with no soak yet, a soak still being written, or one
  sample. The row says which.

## The budgets (plan 286 §5)

These are the plan's first numbers, to be adjusted once the ledger has measured real baselines.

| Measure | At idle over 30 min | After 20 open-and-close cycles |
|---|---|---|
| RSS growth | under 5 % | under 10 % |
| JS heap after a forced GC | under 2 MB | under 5 MB |
| File descriptors | flat | flat |
| inotify watches | flat | flat |
| Child processes | flat, no zombie | back to baseline |
| Main-thread task over 200 ms | none | none over 1 s |
| Not-responding dialogs | zero | zero |
| Restarts of a service | under 3 an hour | — |

## Where the numbers come from

- Services: `$YMIR_HOME/state/soak/services/<date>.jsonl`, written by
  `bin/ward/soak-sampler.sh`.
- Apps: `$YMIR_HOME/state/soak/<app>/<date>.jsonl`, written by `bin/gates/soak.sh`.

The page reads them through the gate's `/api/soak` route, which is memoised for 30 seconds.

## Limits

- The trend covers the ledger's **own last 30 minutes**, ending at its newest pass. If the timer
  has stopped, the trend is still true for when it ran — the page says so rather than showing an
  empty chart.
- A service's budget is the app table's, applied to services; the plan's table was written for an
  app. That is deliberate and named in the page's budgets fold.
- An app that has never been soaked has no verdict. The panel never invents one.

## If it does not work

| What you see | What to do |
|---|---|
| "no soak ledger at …" | The sampler has not run on this machine. Raise it: `bin/ward/soak-sampler.sh --install-timer`. |
| "The ledger has not moved for …" | The timer is stopped. `systemctl --user status ymir-soak.timer`, then `bin/ward/soak-sampler.sh --status`. |
| Every app says "no soak yet" | No soak has run. `bin/gates/soak.sh <app>` once that door is merged. |
| The panel does not appear | The gate is older than this page. Restart the gate, or rebuild the SPA. |
