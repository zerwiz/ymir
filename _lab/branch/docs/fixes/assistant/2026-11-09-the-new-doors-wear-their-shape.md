# The new doors wear their shape

**Date:** 2026-11-09 · **Component:** assistant · **Status:** corrected

## Why

Three test files were added to a **door shelf** — `systems/skirnir/services/test_mind.py`,
`test_brief.py`, `test_telegram.py` — and `rules-compliance-guard` judges every new file there by the shape
the shelf enforces (RULES/12 · RULES/23): a shebang, and the executable bit.

```
"systems/skirnir/services/test_mind.py","1","RULES/12 · RULES/23","a new door has no shebang"
"systems/skirnir/services/test_mind.py","-","RULES/12 · RULES/23","a new door is not executable (chmod +x)"
```

The guard is right, and not only formally: each of these runs by hand — `./test_mind.py` — as well as under
`python3 -m unittest discover`, which is how a person debugging Skírnir will reach for it.

## The correction

`#!/usr/bin/env python3` and `chmod +x` on all three, committed with `git update-index --chmod=+x` so the
mode travels in the index rather than resting on this machine's filesystem. The guard also wanted a
CHANGE LOG on the two new fix notes; both carry one now, appended (Rule 06), and the second records this
same push.

```
$ bash bin/gates/guards/rules-compliance-guard.sh
rules-compliance[2]{state,added,range}:
  "clean",9,"origin/main..HEAD"

$ python3 -m unittest discover -s systems/skirnir/services -p 'test_*.py'
Ran 45 tests … OK
```

## CHANGE LOG

- **2026-11-09** — Written with the correction: shebangs and executable bits on the three new test files,
  and a CHANGE LOG on each new fix note.
