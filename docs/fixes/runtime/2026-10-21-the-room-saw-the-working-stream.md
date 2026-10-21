## runtime · 2026-10-21 — the room saw the working stream

### Why
One deliberate message was posted into a Telegram group to prove the outbound leg. Every turn
after it streamed Brokk's **private working state** — reasoning, tool arguments and tool
results — into that group as `He asks: …` / `Bash: done` blocks.

Cause: `~/.pi/agent/telegram.json` carried `"activity": "verbose"` as a **legacy top-level
key**, which the bridge does not read. The verbosity getter reads `assistant.activity`, and
with it absent falls back to `"verbose"`; the rendered activity goes to the turn's **frozen
delivery target**, which — because of that one message — was the group.

### Fix
`{"assistant": {"activity": "quiet"}}`, dead top-level key removed
(`telegram.json.bak-20261021-2300`). The bridge reloads config through
`createTelegramActivityVerbosityRefresher`, so it applies without a restart.

### The law that came out of it
A room carries **deliberate words**: never thinking, never tool arguments, never tool results,
never errors, never file contents. A relay inherits the same law — when Skírnir or Brokk
carries another voice into a room, it carries the answer, not the transcript that produced it.
A line with no named speaker is not posted.

### Owed
A wall-suite assertion: **an activity event must never reach an allowlisted group.**

### Files
- `~/.pi/agent/telegram.json` (machine config)
- `$YMIR_HOME/…/plans/101-the-assistant.md` §11
