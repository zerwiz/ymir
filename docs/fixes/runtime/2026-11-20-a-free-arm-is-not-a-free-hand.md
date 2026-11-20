## runtime · 2026-11-20 — a free arm is not a free hand, and the pane is proved

### Why

Two faults, both measured the same night, both about a session believing something the
record did not say.

**A session start took a vacant arm in silence.** `saga-session-start.sh` asked the lock,
found it vacant, and took the helm. "Vacant" and "the hand that held it is gone" are not
the same fact: the lock is a file, and a file can be dropped or overwritten while the
session it named is alive on top of herdr — which is exactly what the Allfather found
(*"he was not dead, he's on top of herdr"*). A new window then became the helm without a
word to anybody.

**`state/.arm.pane` named a ghost.** Every door that aims a line at the helm reads that
file. It was written by hand on 9 November and named `w39:p23` for four days after herdr
had dropped that pane, so helm notifications went nowhere while claiming to be delivered.

### What changed

- **`bin/seat/arm-handover.sh`** — the one door a person and a script both read. It prints
  the last change of hands, the journal, and who held the arm last; it speaks a hand-over
  into both panes (`--announce`, called by `lock.py` after every change of hands, detached
  and never fatal); and it writes `.arm.pane` from a **proved** pane (`--pane <pid>`):
  the holder's own `HERDR_PANE_ID` from `/proc/<pid>/environ`, or a pane of this herdr
  whose shell or foreground process stands in the holder's ancestry. Nothing provable means
  no file — never a ghost, never an invention.
- **`saga-session-start.sh`** — `lock_take()` now consults the record first. If the lock is
  vacant but the last recorded helm is ALIVE, the session **stands read-only** and names
  that hand in one line:

  ```
  READ-ONLY: the arm is free, but the last helm (pid 2354925) is ALIVE and still names
  itself the helm - this session stands read-only; the Allfather seats it with
  bin/voice/rodd-arm.sh hold
  ```

  The Allfather seats it with `bin/voice/rodd-arm.sh hold`; a deliberate takeover sets
  `BROKK_TAKE_HELM=1`. Either way the change of hands lands on the record like any other.
- **`--lock-only`** — the lock stage alone, for a test that must not raise the bridges, the
  cron or the pin. It takes nothing else and prints only the LOCK row.
- **`bin/pi/syn-watch-arm.sh`** and **`bin/voice/rodd-arm.sh`** refresh `.arm.pane` through
  the same door when they take the helm, and a release clears it: no helm, no pane.

### Files

- `bin/seat/arm-handover.sh` (new)
- `bin/time/saga-session-start.sh`
- `bin/pi/syn-watch-arm.sh`
- `bin/voice/rodd-arm.sh`
- `bin/seat/tests/test_arm_never_lost.sh`
- `docs/features/the-seats-and-the-arm.md`, and its catalogue entry
  `docs/features/_catalogue/entries/02-130-the-arm-is-never-lost-without-a-word.md`

### Proved

`bash bin/seat/tests/test_arm_never_lost.sh` → `49 passed, 0 failed`:

- a vacant lock whose last recorded helm is alive is **not** taken, and the row names that
  pid; `BROKK_TAKE_HELM=1` is the deliberate takeover and is recorded; a dead prior helm
  leaves the arm free;
- with a stub herdr: a proved pane is written, a pane herdr no longer holds is cleared, and
  an unprovable pane writes nothing at all;
- with a recording send door: the hand that lost the arm is told, the hand that took it is
  told, and `.arm.pane` is refreshed to the new holder.

`bin/voice/rodd-arm.sh --self-test` (43 checks) and
`.agents/tests/gleipnir-machine-lock.test.sh` (14 checks) still pass inside the same run.

## CHANGE LOG

- 2026-11-20 — filed with the errand `arm-never-lost`.
