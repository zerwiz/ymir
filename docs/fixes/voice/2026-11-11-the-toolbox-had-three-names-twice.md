# The toolbox had three names twice, and the voice would not open

**Date:** 2026-11-11 · **Component:** voice (`bin/voice/voice_tools.py`, `.agents/tests/rodd-hands.test.sh`)

## What was wrong

Rödd opened a window that could never speak. The realtime client refused the session outright:

```
Duplicate Realtime tool names found: 'arm_who' (2 function tools), 'eindri_list' (2 function tools) …
```

It refuses **before any audio**, so the failure looked like a dead microphone or a dead engine rather than a
malformed toolbox.

`bin/voice/voice_tools.py` declared `arm_who`, `eindri_list` and `eindri_send` **twice** each in one `TOOLS`
list. Measured on `origin/main` at `2c70c764`: **48 declared names, 45 distinct, three duplicates**. The third
(`eindri_send`) was never named by the client because it stops at the first pair it reports.

**How it happened.** `dd4e3b12` ("Rödd gets his four hands") added the three tools; `880973fe` ("give Rödd six
hands — arm, herdr, seats, calendar") added them again alongside `arm_tell` and `seat_wire`, and the merge kept
both copies. The two copies carried *different* descriptions, which is why nothing looked wrong at a glance: a
duplicate spec is invisible to every test the file had.

**Why nothing caught it.** `rodd-hands.test.sh` proved each hand was **declared** and **wired**, never that the
declaration was unique. Nothing else reads `TOOLS` before the client does — only a person opening the window
could see the fault, and only as an error they had no reason to attribute to a duplicate.

## The fix

- **One spec per name.** The older, richer trio is kept (`arm_who`, `eindri_list`, `eindri_send`); the later
  duplicates are removed. The clause worth keeping from the newer copy — *"and then read what its pane shows"* —
  is folded into the surviving `eindri_send` description, so no behaviour guidance is lost. `arm_tell` and
  `seat_wire` stay: they are unique and were never part of the collision. 48 names → **45, all unique**.
- **A guard at import.** `_duplicate_tool_names(TOOLS)` runs at module load and raises `RuntimeError` naming
  every repeated name. A toolbox that cannot start now says so in one line, where the fault is, instead of
  failing as a client-side refusal in a window that appears to work.
- **A claim in the gate.** `rodd-hands.test.sh` reads the names out of the AST and fails when any repeats —
  the same measurement this note quotes, run on every push rather than by hand.

## Proven

- `python3 -c "import voice_tools"` on the branch: **45 tools, 45 unique, no duplicates**.
- The guard, fired on purpose: a copy of the module with one planted `arm_who` raises
  `voice tool names must be unique — a realtime session refuses duplicates: arm_who`.
- `bash .agents/tests/rodd-hands.test.sh` → all ten claims pass, including
  `ok - every voice tool name is unique`, exit 0.
- The same name-scan run against unmodified `origin/main` reports
  `48 names, dupes: ['arm_who', 'eindri_list', 'eindri_send']` — the measurement that proves the finding.

**Not proven here:** a live Rödd session against the engine (the realtime host answers only while
`bin/voice/voice-door.sh` has a seat), and the Allfather's own ear. What is proven is that the refusal which
stopped him cannot be raised by this toolbox again.
