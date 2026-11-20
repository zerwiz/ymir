## runtime · unversioned · 2026-09-17 — smoke test all UI: two checks that lied about their own subjects

### Why
- **The truth gate failed on my own change.** It demanded the connector's total equal
  the herdr pane count; the connector is roster-first now, so it legitimately reports
  agents AND seats (33 vs 13 panes). Panes are a subset of what the board must show.
  Corrected: a FAIL now means FEWER entries than panes — a standing seat hidden from
  the board — which is the fault worth catching. **Verdict: PASS.**
- **The smoke test reported a present database absent.** It looked for the smithy's db
  at the repo path; the runtime keeps it under `$YMIR_HOME/smidja/`, which is where
  the bootstrap and the gate both resolve it. Same wound as Skrymir and the well: the
  check and the owner disagreeing about where the record lives. **Now: OK, 8 tables.**
- **Smoke test all UI: 5/5 OK** — spa, api, well, smidja-db, loaders. Truth gate: PASS.

Also mended in the same pass: `StatusChip` read `STATUS_META[status].tone`, and the
fleet now reports a status it was never taught (`seated`), so an unknown status threw
and killed the gate. An unknown status can no longer take a panel down.

### Files
- *(carried from the frozen CHANGELOG.md)*
