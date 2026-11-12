# An update never leaves the machine broken, and Rödd's face follows its patches

**2026-11-12 · component: engine · `bin/engine/runtime-deploy.sh` · `apps/rodd/setup.sh` · plan 275 S1, S6**

## What was wrong

- **The pin door wiped hand edits.** `runtime-deploy.sh` ran `git reset --hard` on the pinned runtime, so a hand
  edit on the pin was destroyed without a word. Today four such edits had lived there for three days.
- **A failed update stayed failed.** When a unit did not settle on the new commit, the door printed FAIL and left
  every service on code that does not start.
- **A merged fix never reached Rödd's face.** Plan 271's `why.js` merged, yet the face kept printing
  `[object Event]`. The face is fetched once and dressed by `patch/patch-ui.py`; `setup.sh --check` compared only
  the engine's tag, so it answered `present` and nothing re-ran the patcher. The pin's `ui/main.js` was last dressed
  on 2026-11-09.

## What was done

- The door **refuses a dirty pin** (exit 3), names the files, leaves them in place, and files a dated fault report
  under `$YMIR_HOME/hodd/state/groa/faults/`.
- The door records the running commit first. If a unit does not settle on the new commit, it **moves the pin back**
  to it, restarts the units on the last good code, files a fault report, and exits 4. `YMIR_RUNTIME_NO_ROLLBACK=1`
  keeps a failed move in place on purpose.
- A good move writes `$YMIR_HOME/state/runtime/last-good` — the record a canary seat will hand the fleet (S2).
- Rödd's `setup.sh` stamps the face with a hash of `patch/*`; `--check` answers `stale:patch` when the patches
  changed, so every start and every update re-dresses the face.

## Proof

- `bin/engine/tests/test_runtime_deploy_stable.sh` — 10 of 10: a dirty pin is refused and kept, a good move records
  last-good, an unsettled move is rolled back; every restart goes to a stand-in `systemctl` in a temp HOME.
- `apps/rodd/smoke/test_face_follows_patches.sh` — 3 of 3: a face without the patch stamp, a current face, and a
  face whose patch changed.

## CHANGE LOG

- **2026-11-12** — plan 275 S1 and S6, and the face that follows its patches.
