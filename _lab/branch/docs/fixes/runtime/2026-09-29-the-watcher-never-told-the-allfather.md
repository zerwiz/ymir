# The watcher never told the Allfather anything

**Component:** runtime (supervision) · **Date:** 2026-09-29

## The symptom

Agents ran unarmed, and their state changes never reached the Allfather. He
learned about a wedged or blocked crew only by happening to look at the hall.

## The cause

`bin/ymir-say.sh` — the single owner of "Ymir speaks on the desktop" — had six
callers: `crash-sense.sh`, `wedge-notify.sh`, `saga-session-start.sh`,
`eindri-acclaim.sh`, `eindri-handoff.sh`, `snotra-detect.sh`.

**`.agents/backend/fm-watch.sh` was not one of them.**

The watcher classifies every event on every poll and decides precisely which ones
mean a human: `done`, `needs-decision`, `blocked`, `failed`. Every one of those
decisions ended in `wake "$reason"`, which is an **agent** delivery — the reason
is queued for firstmate. Whether firstmate then spoke to the Allfather was a
model decision, and a busy, context-starved or mid-turn session drops it with no
trace and no error.

So the watcher was never silent by accident. It was silent by design: the one
component that watches everything had no path to the one person who is watching
nothing.

This is also why arming felt brittle. The arm fed a *peer*, not a person, so a
missed wake cost a turn rather than a man standing in a room — and the failure
had no blast radius anyone could feel.

## The change

- **New** `.agents/backend/fm-notify-lib.sh` — reads the same actionable status
  span the watcher just classified and speaks the human-meaningful verbs through
  `ymir-say.sh`. Manner maps to urgency: `done` → `--mark-done`, `blocked` /
  `needs-decision` → `--mark-alarm`, `failed` → `--mark-fail` + `critical`.
- **Wired at the three surfaces that already decide an event is actionable:**
  the poll signal path, the heartbeat backstop, and the native push-transition
  handler (the one that literally means "this agent is waiting on a human").
- The agent wake is **untouched and still happens**. This is additional, never a
  replacement, so no supervision path loses its delivery.

## Dedup, and why it is durable

The marker is `$STATE/.notified-<task>-<sha256-prefix-of-line>`, beside the
existing `.seen-*` family. An event is spoken **once per distinct status line**,
not once per poll and not once per watcher:

- a task that blocks, is resolved, and blocks again speaks three times — each a
  genuinely distinct state;
- the four hundred polls in between stay silent;
- a restarted watcher stays quiet about what it already told the Allfather, and
  still speaks for anything new.

The marker is written **before** `ymir-say.sh` is invoked. The worst outcome is a
suppressed notification after a crash between the two; the alternative — speak
first — would re-announce on every poll forever. Repeated lines are noise; a
silent one is the exact failure this exists to remove.

## Deliberate boundaries

- **`resolved` is not news.** It is absent from
  `BROKK_CLASSIFY_ALLFATHER_RE_DEFAULT`, so a crew closing its own loop does not
  pull the Allfather back to a decision he already made. Asserted by test,
  because it is the boundary most likely to be "helpfully" widened later.
- **A bare turn-end / `working:` note is not news.** Only the four verbs speak.
- **No private path in the spoken line** — asserted by test.

## Proof

`.agents/tests/fm-notify-allfather.test.sh` — 18 assertions, all offline, exit 0.
It uses `BROKK_NOTIFY_SAY_BIN` to substitute a recording notifier, so the suite
never proves anything by the absence of a desktop.

Removing any of the three call sites, or the library, fails this suite.

## Not changed

No door renamed, no output grammar altered. The Pi extensions'
`signal:` / `stale:` / `check:` / `heartbeat:` ABI is untouched — this change
only adds a side effect that does not exist for them.