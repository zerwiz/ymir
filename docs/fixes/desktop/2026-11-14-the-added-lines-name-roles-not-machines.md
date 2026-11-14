## desktop · 2026-11-14 — an added line names a role, never one of our machines

### Why

The house law of 2026-11-14: the repository is agnostic, so **no added line names one of our machines** — not in
code, a comment, a fixture, or a fix note. The stopwatch work carried the machine it was measured on, which is a
name no other fleet and no stranger's install shares.

### What changed

The wording of the comments and fix notes added by this branch: a machine name became its role — *this machine*,
*a second machine*, *the local seat*, *two fleet seats*. Nothing else moved. Every measurement is quoted exactly as
it was taken (10.4 s → 0.25 s for the fleet question, 52.7 s → 33.9 s for the engine raise, 3178/5070/13559 ms →
2238/3262/3299 ms for the first paint), and no claim changes with the noun.

### The check

```
git diff origin/main...HEAD | grep -E "^\+" | grep -iE "heimdall|nidavellir|whynot|zerwizserver"
```

answers nothing. The house figure Heimdall — the guard at the gate — keeps his name, because that is lore, not a
machine.

## CHANGE LOG

- 2026-11-14 — written for the wording change, at the helm's word.
