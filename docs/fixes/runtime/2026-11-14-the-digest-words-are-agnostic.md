# The digest's words are agnostic — roles, never a machine of ours

**Plan:** 275, items 28 and 36b (repair before review). **Date:** 2026-11-14.

## What was wrong

Under the law appended to `AGENTS.md` on 2026-11-14 — the repository is agnostic, so **no
machine of ours is named in any added line**, whether code, comment, fixture or fix note — two
lines this branch added named machines:

- the fixed core's testing law named the two machines it asks a hand to test on;
- the fix note reported the measurement "on" one of them by name, and the owed proof as the
  other being offline.

The measurement is the value; the machine name is the leak.

## The fix

Both read as **roles**, and every number is kept exactly as measured:

| Was | Now |
|---|---|
| test on two named machines (one here, one over ssh) | test on **this machine** and, from a release, on **a second machine** (its own ssh entry) |
| "On *the machine's name*, through the real hook: 33 lines / 3,569 bytes" | "On this machine, through the real hook: 33 lines / 3,569 bytes" |
| "*The other machine's name* was offline" | "A second machine was offline (its tailnet seat: last seen 1 h ago)" |

The house figure **Heimdall** in the lore is untouched — a figure is not a machine.

## How it was proved

```bash
the same check the helm gave — every added line of the branch read for a machine name
of ours (`git diff origin/main...HEAD | grep '^+'`, then the machine-name pattern)
```

prints nothing, and the head still measures 34 lines / 3,646 bytes against its 60-line,
8 KiB budget (`--check` PASS).

## CHANGE LOG

- **2026-11-14** — written with the repair it describes.
