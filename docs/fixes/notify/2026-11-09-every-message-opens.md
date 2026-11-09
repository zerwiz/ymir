# every message opens, or says it cannot

**2026-11-09 · component: notify**

Plan 230, his word: *"i wanna be eble to click all ymirs messegnes and see whats they are about."* The fault
that opened it: a toast that looked clickable and did nothing (`notify-send` with no action) — worse than one
plainly not clickable, because it teaches him to stop trying. Four subsystems drew their own toasts, with
three different behaviours and nothing to open.

## What was built

**`bin/notify/open-target.sh`** — the ONE resolver, and the act of opening:

- `file:<path>` — a file under the home or the tree; a missing path is `target missing` and files a finding.
- `plan:<n>` — the ledger file for plan NNN, from the canonical shelves.
- `pr:<url>` — a GitHub pull request, validated, opened in his own browser.
- `yl://<route>` — a Hlidskjalf route; when the gate is down it says `gate-down` and opens nothing.
- `--check` verifies without opening; `--resolve` prints the resolved path. The opener is
  `YMIR_OPEN_CMD` (default `xdg-open`), so a test proves the click without a desktop.

**`bin/notify/desktop.sh`** — the ONE desktop toast. With a target it fires `notify-send --action=default=Open
--wait` and a detached companion calls `open-target.sh` on the click; without one the title says `(no link)`,
so a dead end is visible instead of disappointing. `--exec` keeps the approval gesture (a click that RUNS
`approve.sh`) working as before.

**`send.sh --target <spec>`** verifies the target once, reports `target{state,resolved}`, hands it to the
desktop leg, writes the resolved path into the arm wake and the Telegram line, and marks a vanished target in
the message instead of offering it.

**The four bare-string senders are repointed**, each through the hotline and each with the target it can
honestly offer:

```
senders[4]{sender,before,after}:
  "bin/gates/wedge-notify.sh","omarchy-notification-send / notify-send with no action","send.sh --source ward --target file:<wedge-alarm.log>"
  "bin/host/crash-sense.sh","its own notify-send fallbacks","send.sh --source engine (no target: no fix note exists yet, so the title says (no link))"
  "systems/snotra/services/tts-lease/ymir-say.sh","its own omarchy/notify-send block","bin/notify/desktop.sh, carrying --target and --exec through"
  "systems/snotra/services/cron/snotra-cron.sh","notify-send with no action (the original fault)","send.sh --source snotra --target file:<the digest>"
```

## Proved

`bash .agents/tests/open-target.test.sh` proves all four kinds resolve, that a missing file, an absent plan, a
non-PR url and a route on a dead gate are each refused, that `(no link)` and `(target missing)` appear in the
title where they should, that `send.sh` reports what it resolved, and — the acceptance that matters — that
`grep -rn notify-send` in the runtime returns **only files under `bin/notify/`**.

## What this does not claim

The click itself is not proved on a live desktop from inside a test: the opener is stubbed (`YMIR_OPEN_CMD`)
and the wait-and-open companion is exercised on a real click by hand. What is proved is that the target
resolves before anything offers it, which is the half that was broken.

## CHANGE LOG

- **2026-11-09** — Opened with the fix.
