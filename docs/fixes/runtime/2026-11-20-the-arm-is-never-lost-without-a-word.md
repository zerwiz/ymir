## runtime · 2026-11-20 — the arm is never lost without a word

### Why

At the Allfather's word, 2026-11-20: *"we need to fix so the arm cant randomly lose"*,
after he found the helm had changed hands without anyone being told: *"he was not dead,
he's on top of herdr"*.

Measured on heimdall that night, from the process table and the sidecars:

- the helm moved **four times in ninety minutes** — `pi 2243828` (since 11-19 02:35) →
  `claude 1074973` at 00:34 → `pi 2354925` at 01:05 → `claude 2425137` at 01:06;
- **every one of those owners was alive when it lost the arm** — `1074973` and
  `2354925` were both still running when the next session took the helm from them;
- `state/` held **no record of any of it**. `brokk.lock` names one pid and no history, so
  the hand that lost the helm had no way to know, and three sessions each believed they
  were the helm. That silence is the fault this note closes.

This change is the lock's half. `docs/fixes/agents/2026-11-20-the-watch-extension-stops-
writing-the-lock.md` is the extension's half, and
`docs/fixes/runtime/2026-11-20-a-free-arm-is-not-a-free-hand.md` the session start's.

### What changed in the lock (`src/ymir_runtime/state/lock.py`)

1. **The record.** `append_journal()` writes one append-only line per change of hands to
   `<state>/.lock-journal` and mirrors the last one into `<state>/.arm.handover`:

   ```
   2026-11-20T01:06:35+0100 event=acquire pid=2425137 starttime=13526571 \
     from_pid=2354925 to_pid=2425137 why=starttime-mismatch role=claude harness=yes
   ```

   `acquire`, `release` and **every reap** are recorded, including a reap that happens
   inside an acquire — a lock that quietly stood aside is exactly the silence this record
   exists to end. `why` is `vacant` · `dead` · `starttime-mismatch` · `released`.
   `harness=no` names a lock held by a hand that cannot speak (a shell, a cron, a
   supervisor), which is the road by which the arm dies on its own.

2. **ONE writer, and the pair written as one fact.** The lock and its `.starttime` are two
   files and the reaper reads both, so a reader that caught the new pid beside the OLD
   starttime declared a live owner dead. Every decide-and-write now runs under an advisory
   guard (`<lock>.guard`, a POSIX record lock via `fcntl.lockf`) and both files are written atomically
   (temp + `os.replace`). A torn or empty `brokk.lock` used to read as "no owner" and hand
   the helm to the next session; it cannot now.

3. **A reap is reported, not whispered.** `reap()` names the pid and the reason on stderr
   and in the journal, so the loss of an arm can be dated from the record alone.

### Files

- `src/ymir_runtime/state/lock.py`
- `src/ymir_runtime/state/__main__.py` — the door gains `lock journal`, `lock handover`
  and `lock announce`, so a shell and a test read the record without parsing a log.
- `bin/seat/tests/test_arm_never_lost.sh` — 49 assertions; **23 of them fail on the tree
  before this change** and all pass after.

### Proved

`bash bin/seat/tests/test_arm_never_lost.sh` → `49 passed, 0 failed` (its own temp state,
every process killed by PID, one PASS/FAIL per line). A lock taken by a detached helper
shell is reaped when that shell dies and the swap is on the record with `from_pid`; a live
owner is refused and the lock file is byte-identical afterwards; a stale starttime is
recorded as `starttime-mismatch` instead of vanishing; a release from the wrong hand
removes nothing and records nothing; the journal only ever grows.

## CHANGE LOG

- 2026-11-20 — filed with the errand `arm-never-lost`.
