# The batch of six, made green on CI

### Why

PR #771 (six PRs merged as one) went red on the whole-tree gate in GitHub CI, with six gates failing where `main` was
green. Each came from two of the batch's changes meeting, or from a test that only passed on a machine with a home and
a pin.

### What was done

- **realms-from-registry:** the "one runtime" errand dropped the shipped `personal` realm, while #763 (on main) made
  the shipped pair the fallback for a home with no registry and tests it. The pair is restored in
  `apps/hlidskjalf/src/data/realms.ts`; a home's own registry still replaces it.
- **gather-orders-by-base:** the gather now refuses a repository the operator's registry does not claim (plan 290).
  The test plants a home whose registry claims its planted origin, and a fleet that names the machine.
- **plan-ledger:** `plan-audit.sh` called `ymir_plan_dir` inside `$(…)`, which loses its result variable, and refused a
  home with no ledger. It now reads the variable directly, and a home with no ledger is a clean skip, said aloud.
- **review-seat-keeper:** the seat now passes the warden door first. The test plants a wardens file naming
  `review-seat`, a registry claiming its repository, and a stub `gh` that answers who it is.
- **saga-head:** Hlidskjalf's Runtime page called `saga-session-start.sh` with no mode, which takes the helm's session
  lock like a session start. It now asks for `--page`, a read-only view.
- **soak-judge:** the test read its registry from `~/ymir-runtime`, which CI does not have. It now reads the tree
  under test (`YMIR_RUNTIME_DIR=$ROOT`).

### Verified

Each of the six run locally and again with `HOME` emptied and `YMIR_HOME` unset, as CI runs them: all pass.
