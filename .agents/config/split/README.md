# config/split — the decisions the split ledger reads

`bin/apps/split-ledger.py verify <app> --after-removal` fails while any code line outside the app still
names its old folder (`apps/<dir>`). Every such line gets a decision: it is **cut**, **resolved** through
`bin/apps/app-path.sh`, or **kept** on purpose. A kept line is written down here, in `<app>.kept.tsv`
(`path` and `why`), so the decision is public and the ledger can check it, never assumed.

## CHANGE LOG

- **2026-11-19** — written with the app split.
