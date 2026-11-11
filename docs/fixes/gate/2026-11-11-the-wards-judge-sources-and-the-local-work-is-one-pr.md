# The wards judge sources, and the local work rides as one PR

**Date:** 2026-11-11 · **Component:** gate (plan 243 parts A–F, plan 192 §11)

## What happened

At the Allfather's word — *"make one pr of all local changes thats not pushed yet. merge all together to one local
branch"* — the arm holder merged every unpushed branch into `hoenir/all-local-work`: the three stalled Eindri branches
(#639's mends, the Hnoss road, kit 1.4.0), the build-a-fleet guide, and the four plan-243/192 errands whose seats ended
mid-build (generated files out of git; the one-minute diff-scoped pre-push; CI as the required gate; the fleet-to-fleet
door, begun).

## What the merge itself mended

- **Two doors for a red main** (`main-red-issue.sh` from the pre-push errand, `main-red.sh` from the CI errand) — one
  kept (`main-red.sh`, with its test); the other retired, its caller's comment repointed.
- **The generated registers' checks still diffed a committed copy** that had left git. `capabilities.sh --check`,
  `weave-features.sh --check` and `features-guard.sh` now judge the SOURCE when the file is untracked: the register must
  render, the fragments must weave, and every feature page must be named by a catalogue fragment.
- **Uncatalogued pages on main** (`broken-register`, `pr-identity`, `queue-warden`) got their fragments.
- **A real tailnet suffix and a private address in two public tests** are now built at runtime, so the source carries no
  address and the leak detectors are still exercised.

## CHANGE LOG

- **2026-11-11** — written when the local work was merged into one PR.
