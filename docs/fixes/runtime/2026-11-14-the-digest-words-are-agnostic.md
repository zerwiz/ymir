# The digest's words are agnostic — roles, never a machine of ours

**Plan:** 275, items 28 and 36b (repair before review). **Date:** 2026-11-14.

## What was wrong

Under the law appended to `AGENTS.md` on 2026-11-14 — the repository is agnostic, so **no
machine of ours is named in any added line**, whether code, comment, fixture or fix note — two
lines this branch added named machines:

- the fixed core's testing law said *"test … on heimdall and, from a release, on nidavellir"*;
- the fix note reported the measurement *"on heimdall"* and the owed proof as *"nidavellir was
  offline"*.

The measurement is the value; the machine name is the leak.

## The fix

Both read as **roles**, and the measurement is untouched:

| Was | Now |
|---|---|
| test on `heimdall` and, from a release, on `nidavellir` | test on **this machine** and, from a release, on **a second machine** (its own ssh entry) |
| "On `heimdall`, through the real hook: 33 lines / 3,569 bytes" | "On this machine, through the real hook: 33 lines / 3,569 bytes" |
| "`nidavellir` was offline" | "A second machine was offline (its tailnet seat: last seen 1 h ago)" |

The house figure **Heimdall** in the lore is untouched — a figure is not a machine.

## How it was proved

```bash
git diff origin/main...HEAD | grep -E "^\+" | grep -iE "heimdall|nidavellir|whynot|zerwizserver|craig|reygan"
```

prints nothing, and the head still measures 34 lines / 3,646 bytes against its 60-line,
8 KiB budget (`--check` PASS).

## CHANGE LOG

- **2026-11-14** — written with the repair it describes.
