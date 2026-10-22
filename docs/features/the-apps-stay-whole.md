# The apps stay whole

One command answers the question an update must never leave unanswered: **can every app still be
read, routed and answered?** This page is about that check, why it exists, and what to do when it
fails.

## What it is

`bin/gates/guards/app-functional-guard.sh` — a ward in the pre-push gate. It does three things in
about nine seconds, with no window open and no server needed:

| Check | What it proves |
|---|---|
| **parses** | every app's server entry (`apps/*/server/index.ts`) can be read at all — a syntax error is a dead app |
| **routes** | every `/api/…` the interface calls is answered by the server — a door the UI knocks on that does not exist |
| **live** | with `--live`, a raised gate answers without a 5xx |

It exists because of one missing brace. On 2026-10-21 a commit ate the `return {` in Hlidskjalf's
watchtower function; the gate API died at load, every `/api/*` answered **500 with zero bytes**, and
for a day the panels said *"Unexpected end of JSON input"*, *"no worktrees"*, *"Bridge DOWN"* — while
the bridge stood healthy — and empty stats. Nothing noticed, because nothing asked an app whether it
could be read.

## What you need

- Bun, for the parse check. Without it the ward prints a clean **SKIP** and exits 0 — never a false
  pass.
- Python 3 and curl, which the other wards already require.

## The commands

```sh
bin/gates/guards/app-functional-guard.sh check          # parse + route parity
bin/gates/guards/app-functional-guard.sh check --live   # also probe the raised gate for a 5xx
bin/gates/guards.sh                                     # the whole council of wards, this one included
```

You do not usually run it: it is in the pre-push list (`bin/gates/guards.sh --list`), so a push that
would ship an unreadable app is refused, with the file and the parse error named.

## Limits

- **It proves the app can be reached, not that it is right.** A panel showing wrong numbers passes;
  the contents are yours to judge.
- **It reads the tree it is run in.** A gate running from a different checkout is not what it checks.
- **`--live` needs a raised gate.** No gate listening is a clean SKIP, not a failure — a laptop off
  the network should not fail a push.
- **The route check is textual** (`/api/...` literals in the UI against `p === '/api/...'` and
  `startsWith` on the server). A route built from a template string is not seen.

## If it does not work

1. **`"parses","FAIL"`** — the message carries the file and the parser's own words. Fix the syntax;
   the app has been dead since that line changed.
2. **`"routes","FAIL"`** — the message names the route the UI calls and the server does not answer.
   Either implement it, or make the panel say in words that the capability is not present — never an
   HTTP error string where a truth belongs.
3. **`"live","FAIL" … answered 5xx`** — the gate is up but a route is throwing. Check the gate's log
   (`~/ymir/.run/hlidskjalf-api.log`) and the route's handler.
4. If a push is refused by this ward and you believe it is wrong, run the ward directly against the
   file it names; the remedy is in its own last line.
